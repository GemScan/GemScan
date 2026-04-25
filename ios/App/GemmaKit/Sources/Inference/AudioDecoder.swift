import Foundation
import AVFoundation
import os

// MARK: - AudioDecoder

/// Decodes compressed audio files (AAC, M4A, etc.) into 16 kHz mono PCM Float32 samples.
///
/// This is the first stage of the audio processing pipeline, converting on-disk
/// audio into the raw format expected by ``WhisperModel`` and ``AudioSealModel``.
public actor AudioDecoder {

    /// Logger for inference operations.
    private let logger = GemScanLogger.inference

    /// Target sample rate for decoded audio.
    private let targetSampleRate: Double = 16_000.0

    // MARK: - Initialization

    /// Creates a new audio decoder.
    public init() {}

    // MARK: - Public API

    /// Decodes an audio file to 16 kHz mono PCM Float32 samples.
    ///
    /// - Parameter fileURL: The URL of the audio file to decode (AAC, M4A, WAV, etc.).
    /// - Returns: An array of Float32 PCM samples at 16 kHz mono.
    /// - Throws: ``GemScanError/audioDecodingFailed`` if the file cannot be read or converted.
    public func decode(fileURL: URL) async throws -> [Float] {
        logger.info("Decoding audio from \(fileURL.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GemScanError.audioDecodingFailed(reason: "File not found: \(fileURL.path)")
        }

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            throw GemScanError.audioDecodingFailed(reason: "Cannot open audio file: \(error.localizedDescription)")
        }

        let sourceFormat = audioFile.processingFormat
        let sourceFrameCount = AVAudioFrameCount(audioFile.length)

        guard sourceFrameCount > 0 else {
            throw GemScanError.audioDecodingFailed(reason: "Audio file has zero frames")
        }

        // Read source audio into a buffer
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: sourceFrameCount
        ) else {
            throw GemScanError.audioDecodingFailed(reason: "Failed to allocate source buffer")
        }

        do {
            try audioFile.read(into: sourceBuffer)
        } catch {
            throw GemScanError.audioDecodingFailed(reason: "Failed to read audio data: \(error.localizedDescription)")
        }

        // Create target format: 16 kHz, mono, Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw GemScanError.audioDecodingFailed(reason: "Failed to create target audio format")
        }

        // If source already matches target, extract directly
        if sourceFormat.sampleRate == targetSampleRate && sourceFormat.channelCount == 1 {
            return extractFloat32Samples(from: sourceBuffer)
        }

        // Convert via AVAudioConverter
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw GemScanError.audioDecodingFailed(reason: "Cannot create audio converter from \(sourceFormat) to \(targetFormat)")
        }

        let ratio = targetSampleRate / sourceFormat.sampleRate
        let estimatedFrameCount = AVAudioFrameCount(Double(sourceFrameCount) * ratio)

        guard let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: estimatedFrameCount + 1024
        ) else {
            throw GemScanError.audioDecodingFailed(reason: "Failed to allocate target buffer")
        }

        var conversionError: NSError?
        let status = converter.convert(to: targetBuffer, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let conversionError = conversionError {
            throw GemScanError.audioDecodingFailed(reason: "Audio conversion failed: \(conversionError.localizedDescription)")
        }

        guard status != .error else {
            throw GemScanError.audioDecodingFailed(reason: "Audio converter returned error status")
        }

        let samples = extractFloat32Samples(from: targetBuffer)
        logger.info("Decoded \(samples.count) samples at \(self.targetSampleRate) Hz from \(fileURL.lastPathComponent)")
        return samples
    }

    // MARK: - Private Helpers

    /// Extracts Float32 samples from a PCM buffer.
    private func extractFloat32Samples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }
        let frameCount = Int(buffer.frameLength)
        let pointer = channelData[0]
        return Array(UnsafeBufferPointer(start: pointer, count: frameCount))
    }
}
