import Foundation

/// The type of analysis task to route through the agent pipeline.
///
/// Raw string values match the TypeScript `AgentTaskType` union exactly
/// for cross-bridge serialization via `JSONEncoder`/`JSONDecoder`.
public enum AgentTaskType: String, Codable, Sendable {
    case classifySMS       = "classifySMS"
    case classifyEmail     = "classifyEmail"
    case checkURL          = "checkURL"
    case analyseScreenshot = "analyseScreenshot"
    case scoreVoice        = "scoreVoice"
    case explainVerdict    = "explainVerdict"
}

/// Scheduling priority for an agent task.
public enum TaskPriority: String, Codable, Sendable {
    case realtime   = "realtime"
    case background = "background"
}

/// MIME type for image payloads.
public enum ImageMIMEType: String, Codable, Sendable {
    case jpeg = "image/jpeg"
    case png  = "image/png"
}

/// Discriminated union representing the data payload for an agent task.
///
/// The `type` discriminator field determines which associated values are present.
/// Custom `Codable` conformance encodes/decodes the camelCase JSON wire format
/// defined in Spec 00 §4.
public enum AgentPayload: Sendable {
    case text(String, language: String?)
    case url(String)
    case image(String, mimeType: ImageMIMEType)
    case audio(String, durationSeconds: Double)
    case multimodal(parts: [AgentPayload], priorResult: AgentResult?)

    /// The language hint, if this is a text payload.
    public var language: String? {
        if case .text(_, let lang) = self { return lang }
        return nil
    }

    /// Whether this payload contains multiple sub-parts.
    public var isMultiModal: Bool {
        if case .multimodal = self { return true }
        return false
    }
}

// MARK: - AgentPayload + Codable

extension AgentPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, content, url, base64, mimeType, durationSeconds, parts, priorResult, language
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(content, language):
            try container.encode("text", forKey: .type)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(language, forKey: .language)
        case let .url(url):
            try container.encode("url", forKey: .type)
            try container.encode(url, forKey: .url)
        case let .image(base64, mimeType):
            try container.encode("image", forKey: .type)
            try container.encode(base64, forKey: .base64)
            try container.encode(mimeType, forKey: .mimeType)
        case let .audio(base64, durationSeconds):
            try container.encode("audio", forKey: .type)
            try container.encode(base64, forKey: .base64)
            try container.encode(durationSeconds, forKey: .durationSeconds)
        case let .multimodal(parts, priorResult):
            try container.encode("multimodal", forKey: .type)
            try container.encode(parts, forKey: .parts)
            try container.encodeIfPresent(priorResult, forKey: .priorResult)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let content = try container.decode(String.self, forKey: .content)
            let language = try container.decodeIfPresent(String.self, forKey: .language)
            self = .text(content, language: language)
        case "url":
            let url = try container.decode(String.self, forKey: .url)
            self = .url(url)
        case "image":
            let base64 = try container.decode(String.self, forKey: .base64)
            let mimeType = try container.decode(ImageMIMEType.self, forKey: .mimeType)
            self = .image(base64, mimeType: mimeType)
        case "audio":
            let base64 = try container.decode(String.self, forKey: .base64)
            let duration = try container.decode(Double.self, forKey: .durationSeconds)
            self = .audio(base64, durationSeconds: duration)
        case "multimodal":
            let parts = try container.decode([AgentPayload].self, forKey: .parts)
            let prior = try container.decodeIfPresent(AgentResult.self, forKey: .priorResult)
            self = .multimodal(parts: parts, priorResult: prior)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown payload type: \(type)"
            )
        }
    }
}

/// A unit of work dispatched through the agent analysis pipeline.
///
/// All field names use camelCase and are JSON-key-matched to the TypeScript
/// contract via `CodingKeys`. Dates are Unix timestamps in milliseconds.
public struct AgentTask: Codable, Sendable {
    /// Unique identifier (UUID v4 string).
    public let id: String
    /// The type of analysis to perform.
    public let type: AgentTaskType
    /// The data payload for analysis.
    public let payload: AgentPayload
    /// Scheduling priority.
    public let priority: TaskPriority
    /// Creation timestamp in Unix milliseconds.
    public let createdAt: Int64
    /// Maximum allowed execution time in milliseconds.
    public let timeoutMs: Int

    public init(
        id: String = UUID().uuidString,
        type: AgentTaskType,
        payload: AgentPayload,
        priority: TaskPriority = .realtime,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        timeoutMs: Int = 5000
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.priority = priority
        self.createdAt = createdAt
        self.timeoutMs = timeoutMs
    }

    /// Returns a copy of this task. The model tier is passed separately
    /// to `InferenceEngine.generate()`, not stored on the task itself.
    public func withModelTier(_ tier: ModelTier) -> AgentTask {
        AgentTask(
            id: id, type: type, payload: payload,
            priority: priority, createdAt: createdAt, timeoutMs: timeoutMs
        )
    }
}
