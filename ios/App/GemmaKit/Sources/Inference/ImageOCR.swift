import Foundation
import Vision
import CoreImage
import os

// MARK: - ImageOCR

/// On-device OCR using Apple's Vision framework.
///
/// We tried using Gemma 4 E2B's vision tower for OCR but its character-level
/// fidelity at 4-bit quant is poor — the model has decent scene understanding
/// but hallucinates specific text. `VNRecognizeTextRequest` at `.accurate`
/// level is built for this exact task: it runs in <500 ms on iPhone, is
/// substantially more accurate, and keeps the entire OCR step off the LLM.
///
/// Output is fed to Gemma's text-classification pipeline for the scam verdict,
/// so the LLM is still doing the part it's good at (reasoning over text)
/// while Vision handles the part it's bad at (reading pixels).
public enum ImageOCR {

    /// Sentinel returned when the image contains no recognised text. The
    /// caller (typically ``ImageAgent``) uses this to short-circuit to a
    /// neutral verdict instead of attempting to classify an empty string.
    public static let noTextSentinel = "NO_TEXT"

    /// Logger for OCR operations. Lives on the inference subsystem because
    /// OCR is the first step of the image-analysis inference pipeline.
    private static let logger = GemScanLogger.inference

    /// Extracts text from a JPEG/PNG/HEIC image and returns it joined by
    /// newlines in natural reading order.
    ///
    /// - Parameter imageData: Raw image bytes — any format `CIImage(data:)`
    ///   accepts (JPEG, PNG, HEIC, TIFF, BMP).
    /// - Returns: Recognised lines joined by `\n`. Returns ``noTextSentinel``
    ///   if no text was recognised.
    /// - Throws: ``GemScanError/inferenceError(message:)`` if the bytes
    ///   cannot be decoded or Vision's request fails.
    public static func extractText(from imageData: Data) throws -> String {
        guard let ciImage = CIImage(data: imageData) else {
            throw GemScanError.inferenceError(message: "ImageOCR could not decode image bytes")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Let Vision pick the recognition language from the user's locale and
        // image content. For scam screenshots that may be in any language a
        // hard-coded "en-US" would be a regression.
        if #available(iOS 16.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw GemScanError.inferenceError(
                message: "Vision OCR failed: \(error.localizedDescription)"
            )
        }

        let observations = request.results ?? []
        let lines: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
        let joined = lines.joined(separator: "\n")
        logger.info("ImageOCR recognised \(observations.count) text region(s), \(joined.count) characters total")

        return joined.isEmpty ? noTextSentinel : joined
    }
}
