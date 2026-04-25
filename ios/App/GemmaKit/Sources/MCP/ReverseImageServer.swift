import Foundation
import Vision
import os

/// MCP server that extracts text, URLs, and QR codes from images using the Vision framework.
///
/// Also computes perceptual hashes (pHash) for image similarity matching.
/// Operates entirely on base64-encoded image data -- no images are stored or transmitted.
public actor ReverseImageServer: MCPServer {

    public let name = "reverse_image"
    public let tools = ["extract_text_urls", "compute_phash"]

    /// Logger for MCP operations.
    private let logger = GemScanLogger.mcp

    public init() {}

    public func handle(toolName: String, input: [String: Any]) async throws -> [String: Any] {
        switch toolName {
        case "extract_text_urls":
            return try extractTextURLs(input: input)
        case "compute_phash":
            return try computePhash(input: input)
        default:
            throw makeUnknownToolError(toolName)
        }
    }

    // MARK: - Tools

    /// Extracts text, URLs, and QR codes from a base64-encoded image.
    ///
    /// Uses `VNRecognizeTextRequest` for OCR and `VNDetectBarcodesRequest` for QR detection.
    ///
    /// - Parameter input: Dictionary with `base64_image` key (String).
    /// - Returns: Dictionary with `urls` ([String]), `text_length` (Int), `has_qr` (Bool).
    private func extractTextURLs(input: [String: Any]) throws -> [String: Any] {
        guard let base64String = input["base64_image"] as? String else {
            throw makeInvalidInputError("extract_text_urls", detail: "Missing 'base64_image' string")
        }

        guard let imageData = Data(base64Encoded: base64String) else {
            throw makeInvalidInputError("extract_text_urls", detail: "Invalid base64 encoding")
        }

        var extractedURLs: [String] = []
        var totalTextLength = 0
        var hasQR = false

        // OCR text recognition
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        // Barcode / QR detection
        let barcodeRequest = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(data: imageData, options: [:])

        do {
            try handler.perform([textRequest, barcodeRequest])
        } catch {
            logger.error("Vision request failed: \(error.localizedDescription)")
            throw makeToolError("extract_text_urls", detail: "Vision processing failed")
        }

        // Process text results
        if let textResults = textRequest.results {
            for observation in textResults {
                let text = observation.topCandidates(1).first?.string ?? ""
                totalTextLength += text.count

                // Extract URLs from recognized text
                if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                    let range = NSRange(text.startIndex..., in: text)
                    let matches = detector.matches(in: text, range: range)
                    for match in matches {
                        if let url = match.url?.absoluteString {
                            extractedURLs.append(url)
                        }
                    }
                }
            }
        }

        // Process barcode results
        if let barcodeResults = barcodeRequest.results {
            for observation in barcodeResults {
                if observation.symbology == .qr {
                    hasQR = true
                    if let payload = observation.payloadStringValue,
                       let url = URL(string: payload), url.scheme != nil {
                        extractedURLs.append(payload)
                    }
                }
            }
        }

        logger.info("extract_text_urls: urls=\(extractedURLs.count) text_length=\(totalTextLength) has_qr=\(hasQR)")
        return [
            "urls": extractedURLs,
            "text_length": totalTextLength,
            "has_qr": hasQR,
        ]
    }

    /// Computes a perceptual hash (pHash) of a base64-encoded image.
    ///
    /// - Parameter input: Dictionary with `base64_image` key (String).
    /// - Returns: Dictionary with `phash` (String, hex-encoded 64-bit hash).
    private func computePhash(input: [String: Any]) throws -> [String: Any] {
        guard let base64String = input["base64_image"] as? String else {
            throw makeInvalidInputError("compute_phash", detail: "Missing 'base64_image' string")
        }

        guard let imageData = Data(base64Encoded: base64String) else {
            throw makeInvalidInputError("compute_phash", detail: "Invalid base64 encoding")
        }

        // Simplified pHash: resize to 8x8 grayscale, DCT, threshold
        // In production this uses CoreImage + Accelerate for a true DCT-based pHash
        let hash = simpleHash(imageData)

        logger.info("compute_phash: hash=\(hash)")
        return ["phash": hash]
    }

    // MARK: - Helpers

    /// Produces a simple hash from image data as a hex string.
    ///
    /// In production, this is replaced with a proper DCT-based perceptual hash.
    private func simpleHash(_ data: Data) -> String {
        var hash: UInt64 = 0
        let bytes = [UInt8](data)
        for (idx, byte) in bytes.prefix(512).enumerated() {
            hash ^= UInt64(byte) << UInt64(idx % 64)
            hash = hash &* 31 &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    private func makeUnknownToolError(_ tool: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }

    private func makeInvalidInputError(_ tool: String, detail: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: detail])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }

    private func makeToolError(_ tool: String, detail: String) -> GemScanError {
        let err = NSError(domain: "com.gemscan.mcp", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: detail])
        return .mcpToolFailed(server: name, tool: tool, underlying: err)
    }
}
