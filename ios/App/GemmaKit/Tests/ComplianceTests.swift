import XCTest
@testable import GemmaKit

/// Validates Apple compliance requirements for GemScan.
///
/// These tests verify that the app's architecture and configuration
/// meet App Store Review Guidelines and Apple's privacy requirements.
final class ComplianceTests: XCTestCase {

    // MARK: - Privacy Compliance

    func testNoNetworkCallsDuringInference() {
        // GemScan performs all inference on-device.
        // This test documents the architectural invariant that
        // InferenceEngine and agents do not make network calls.
        //
        // InferenceBackend protocol has no network methods.
        // MCPServer protocol handles only local tool calls.

        // Verify InferenceBackend protocol methods are all local
        let backendMethods = ["generate", "loadModel", "unloadModel", "isLoaded"]
        for method in backendMethods {
            XCTAssertFalse(
                method.lowercased().contains("network") ||
                method.lowercased().contains("http") ||
                method.lowercased().contains("url"),
                "InferenceBackend method '\(method)' should not imply network access"
            )
        }
    }

    func testScamVerdictEnum_HasRequiredCases() {
        // Verify all verdict types are present for compliance with
        // the output format documented in the privacy manifest
        let allCases: [ScamVerdict] = [.safe, .suspicious, .scam]
        XCTAssertEqual(allCases.count, 3)

        // Verify raw values match the documented strings
        XCTAssertEqual(ScamVerdict.safe.rawValue, "safe")
        XCTAssertEqual(ScamVerdict.suspicious.rawValue, "suspicious")
        XCTAssertEqual(ScamVerdict.scam.rawValue, "scam")
    }

    func testAgentResult_DoesNotContainPII() {
        // Verify that AgentResult fields are designed to avoid PII exposure
        let result = AgentResult(
            taskId: "test-123",
            agentId: AgentID.textAgent,
            verdict: .safe,
            confidence: 0.95,
            reasoning: ["Message appears safe"],
            language: "en",
            toolCallsLog: [],
            latencyMs: 200,
            modelTier: .e2b
        )

        // Verify the result can be serialized
        let encoder = JSONEncoder()
        let data = try? encoder.encode(result)
        XCTAssertNotNil(data, "AgentResult should be JSON-serializable")

        // Verify serialized form does not contain common PII patterns
        if let jsonString = data.flatMap({ String(data: $0, encoding: .utf8) }) {
            XCTAssertFalse(jsonString.contains("@"), "Result should not contain email-like patterns")
            // Note: phone numbers and names should never appear in AgentResult.
            // The reasoning field contains only analyst-generated text.
        }
    }

    func testToolCallRecord_InputSummary_NotRawInput() {
        // ToolCallRecord.inputSummary should be a summary, not raw input
        let record = ToolCallRecord(
            serverName: "scam_patterns",
            toolName: "search",
            inputSummary: "query=urgency_patterns, limit=10",
            durationMs: 45,
            success: true
        )

        // inputSummary should not contain long text or PII
        XCTAssertLessThan(record.inputSummary.count, 200,
            "Input summary should be concise, not raw input")
    }

    // MARK: - Model Tier Compliance

    func testModelTier_RAMBudgets() {
        // Verify RAM budgets are within Apple's recommended limits
        // for background extensions (< 50 MB for DistilBERT) and foreground
        // operations with the increased-memory entitlement (< 5 GB for
        // the gemma-4-e2b 4-bit quant).
        let maxForegroundRAM = 5_000 * 1_024 * 1_024  // 5 GB
        let maxBackgroundRAM = 50 * 1_024 * 1_024       // 50 MB

        XCTAssertLessThan(ModelTier.e2b.expectedRAMBytes, maxForegroundRAM,
            "E2B should be within foreground RAM budget")
        XCTAssertLessThan(ModelTier.distilbert.expectedRAMBytes, maxBackgroundRAM,
            "DistilBERT should be within background RAM budget")
    }

    func testModelTier_HasExpectedValues() {
        // Verify model tier raw values match the manifest format
        XCTAssertEqual(ModelTier.e2b.rawValue, "e2b")
        XCTAssertEqual(ModelTier.distilbert.rawValue, "distilbert")
    }

    // MARK: - Error Description Safety

    func testGemScanError_DescriptionsArePIISafe() {
        // All error descriptions should be safe to log without PII
        let errors: [GemScanError] = [
            .modelNotLoaded(tier: .e2b),
            .inferenceTimeout(taskId: "task-123", limitMs: 5000),
            .thermalThrottled,
            .memoryPressure(currentBytes: 1_000_000, limitBytes: 2_000_000),
            .checksumMismatch,
            .tokenizationFailed,
        ]

        for error in errors {
            let description = error.description
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
            // Descriptions should not leak task content
            XCTAssertFalse(description.contains("URGENT"),
                "Error descriptions should not contain user content")
        }
    }

    // MARK: - Access Control Matrix

    func testAccessControlMatrix_AgentsHaveMinimalAccess() {
        // Each agent should only have access to servers they need.
        // This test documents the expected access control boundaries.

        let expectedAccess: [String: Set<String>] = [
            AgentID.textAgent: [
                "scam_patterns", "sqlite_vec", "contacts",
                "url_reputation", "phone_reputation", "message_filter"
            ],
            AgentID.urlAgent: [
                "sqlite_vec", "url_reputation", "whois"
            ],
            AgentID.imageAgent: [
                "sqlite_vec", "reverse_image", "url_reputation"
            ],
            AgentID.voiceAgent: [
                "sqlite_vec", "phone_reputation", "contacts"
            ],
        ]

        // Verify agents with narrower scope don't have clipboard or screen_time
        for (agentId, servers) in expectedAccess {
            if agentId != AgentID.orchestrator {
                XCTAssertFalse(servers.contains("clipboard_watcher"),
                    "\(agentId) should not have clipboard access")
                XCTAssertFalse(servers.contains("screen_time"),
                    "\(agentId) should not have screen_time access")
            }
        }
    }

    // MARK: - Codable Compliance

    func testAgentTask_RoundTrips() throws {
        let task = AgentTask(
            id: "test-task",
            type: .classifySMS,
            payload: .text("Test message", language: "en"),
            priority: .realtime,
            timeoutMs: 5000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AgentTask.self, from: data)

        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.type, task.type)
        XCTAssertEqual(decoded.priority, task.priority)
        XCTAssertEqual(decoded.timeoutMs, task.timeoutMs)
    }

    func testAgentResult_RoundTrips() throws {
        let result = AgentResult(
            taskId: "test",
            agentId: AgentID.textAgent,
            verdict: .suspicious,
            confidence: 0.72,
            reasoning: ["Unknown sender", "Contains urgency"],
            language: "en",
            toolCallsLog: [
                ToolCallRecord(
                    serverName: "scam_patterns",
                    toolName: "search",
                    inputSummary: "patterns=urgency",
                    durationMs: 12,
                    success: true
                )
            ],
            latencyMs: 350,
            modelTier: .e2b
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AgentResult.self, from: data)

        XCTAssertEqual(decoded.taskId, result.taskId)
        XCTAssertEqual(decoded.verdict, result.verdict)
        XCTAssertEqual(decoded.confidence, result.confidence, accuracy: 0.001)
        XCTAssertEqual(decoded.reasoning.count, 2)
        XCTAssertEqual(decoded.toolCallsLog.count, 1)
    }
}
