import UIKit
import Social
import UniformTypeIdentifiers
import os

/// Share Extension for receiving content from other apps and routing it to GemScan.
///
/// Validates the incoming payload type (text, URL, or image), persists it
/// to the App Group shared container, and deep-links to the main app
/// via the `gemscan://analyse` URL scheme.
final class ShareViewController: UIViewController {

    /// Logger for extension lifecycle events.
    private let logger = GemScanLogger.extensions

    /// Shared UserDefaults for the App Group container.
    private let sharedDefaults = UserDefaults(suiteName: SharedContainerSchema.appGroupId)

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("ShareExtension: viewDidLoad")
        processSharedItems()
    }

    // MARK: - Processing

    /// Processes incoming shared items from the extension context.
    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            logger.warning("ShareExtension: no input items")
            completeRequest()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    handleURLAttachment(provider)
                    return
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    handleTextAttachment(provider)
                    return
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    handleImageAttachment(provider)
                    return
                }
            }
        }

        logger.warning("ShareExtension: no supported attachment types found")
        completeRequest()
    }

    // MARK: - Attachment Handlers

    /// Handles a shared URL attachment.
    private func handleURLAttachment(_ provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("ShareExtension: URL load failed: \(error.localizedDescription)")
                self.completeRequest()
                return
            }

            var urlString: String?
            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                urlString = str
            }

            guard let finalURL = urlString else {
                self.logger.warning("ShareExtension: could not extract URL")
                self.completeRequest()
                return
            }

            self.storeAndDeepLink(type: "url", content: finalURL)
        }
    }

    /// Handles a shared plain text attachment.
    private func handleTextAttachment(_ provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("ShareExtension: text load failed: \(error.localizedDescription)")
                self.completeRequest()
                return
            }

            guard let text = item as? String else {
                self.logger.warning("ShareExtension: could not extract text")
                self.completeRequest()
                return
            }

            self.storeAndDeepLink(type: "text", content: text)
        }
    }

    /// Handles a shared image attachment.
    private func handleImageAttachment(_ provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] item, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("ShareExtension: image load failed: \(error.localizedDescription)")
                self.completeRequest()
                return
            }

            // Store the image to the shared container
            var imagePath: String?

            if let url = item as? URL {
                imagePath = self.copyImageToSharedContainer(from: url)
            } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                imagePath = self.writeImageDataToSharedContainer(data, extension: "jpg")
            }

            guard let path = imagePath else {
                self.logger.warning("ShareExtension: could not save shared image")
                self.completeRequest()
                return
            }

            self.storeAndDeepLink(type: "image", content: path)
        }
    }

    // MARK: - Storage and Deep Link

    /// Stores the shared content in the App Group container and opens the main app.
    ///
    /// - Parameters:
    ///   - type: The content type ("text", "url", or "image").
    ///   - content: The content string (text, URL string, or file path).
    private func storeAndDeepLink(type: String, content: String) {
        let taskId = UUID().uuidString
        let payload: [String: Any] = [
            "id": taskId,
            "type": type,
            "content": content,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
        ]

        // Store pending analysis task in App Group
        if let defaults = sharedDefaults {
            var pending = defaults.array(forKey: SharedContainerSchema.pendingAnalysisTasks) as? [[String: Any]] ?? []
            pending.append(payload)
            defaults.set(pending, forKey: SharedContainerSchema.pendingAnalysisTasks)
            defaults.synchronize()
        }

        logger.info("ShareExtension: stored task \(taskId) type=\(type)")

        // Deep link to main app
        let deepLink = "gemscan://analyse?task=\(taskId)"
        if let url = URL(string: deepLink) {
            openURL(url)
        }

        completeRequest()
    }

    // MARK: - Image Helpers

    /// Copies an image file from a temporary URL to the shared container.
    private func copyImageToSharedContainer(from sourceURL: URL) -> String? {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerSchema.appGroupId
        ) else { return nil }

        let imagesDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)

        do {
            try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            logger.error("ShareExtension: failed to create images directory: \(error.localizedDescription)")
            return nil
        }

        let destURL = imagesDir.appendingPathComponent(UUID().uuidString + "." + sourceURL.pathExtension)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            logger.error("ShareExtension: failed to copy image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes raw image data to the shared container.
    private func writeImageDataToSharedContainer(_ data: Data, extension ext: String) -> String? {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerSchema.appGroupId
        ) else { return nil }

        let imagesDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)

        do {
            try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let destURL = imagesDir.appendingPathComponent(UUID().uuidString + "." + ext)

        do {
            try data.write(to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }

    // MARK: - Lifecycle

    /// Opens a URL via the system responder chain.
    private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }

    /// Completes the extension request.
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
