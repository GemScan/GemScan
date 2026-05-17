import XCTest
@testable import GemmaKit

/// Tests MCPClient access control enforcement and server routing.
final class MCPServerTests: XCTestCase {

    private var mockClient: MockMCPClient!

    override func setUp() async throws {
        try await super.setUp()
        mockClient = MockMCPClient()
    }

    override func tearDown() async throws {
        mockClient = nil
        try await super.tearDown()
    }

    // MARK: - Access Control

    func testTextAgent_CanAccessAllowedServers() async throws {
        await mockClient.setAccessControl([
            AgentID.textAgent: [
                "scam_patterns", "sqlite_vec", "contacts",
                "url_reputation", "message_filter"
            ]
        ])

        await mockClient.setResult(
            server: "scam_patterns",
            tool: "search",
            result: ["matches": 3]
        )

        let result = try await mockClient.call(
            agentId: AgentID.textAgent,
            server: "scam_patterns",
            tool: "search",
            input: ["query": "urgency patterns"]
        )

        XCTAssertEqual(result["matches"] as? Int, 3)
    }

    func testTextAgent_DeniedAccessToWhois() async throws {
        await mockClient.setAccessControl([
            AgentID.textAgent: [
                "scam_patterns", "sqlite_vec", "contacts",
                "url_reputation", "message_filter"
            ]
        ])

        do {
            _ = try await mockClient.call(
                agentId: AgentID.textAgent,
                server: "whois",
                tool: "lookup",
                input: ["domain": "example.com"]
            )
            XCTFail("Expected access denied error")
        } catch let error as GemScanError {
            if case .mcpToolFailed(let server, _, _) = error {
                XCTAssertEqual(server, "whois")
            } else {
                XCTFail("Expected mcpToolFailed error, got: \(error)")
            }
        }
    }

    func testURLAgent_CanAccessWhois() async throws {
        await mockClient.setAccessControl([
            AgentID.urlAgent: ["sqlite_vec", "url_reputation", "whois"]
        ])

        await mockClient.setResult(
            server: "whois",
            tool: "lookup",
            result: ["registrar": "GoDaddy", "ageInDays": 30]
        )

        let result = try await mockClient.call(
            agentId: AgentID.urlAgent,
            server: "whois",
            tool: "lookup",
            input: ["domain": "suspicious-site.xyz"]
        )

        XCTAssertEqual(result["registrar"] as? String, "GoDaddy")
        XCTAssertEqual(result["ageInDays"] as? Int, 30)
    }

    func testImageAgent_DeniedAccessToWhois() async throws {
        await mockClient.setAccessControl([
            AgentID.imageAgent: ["sqlite_vec", "reverse_image", "url_reputation"]
        ])

        do {
            _ = try await mockClient.call(
                agentId: AgentID.imageAgent,
                server: "whois",
                tool: "lookup",
                input: ["domain": "example.com"]
            )
            XCTFail("Expected access denied error")
        } catch {
            // Expected
        }
    }

    // MARK: - Call Tracking

    func testCallHistory_TracksAllCalls() async throws {
        _ = try await mockClient.call(
            agentId: AgentID.textAgent,
            server: "scam_patterns",
            tool: "search",
            input: ["query": "test1"]
        )

        _ = try await mockClient.call(
            agentId: AgentID.urlAgent,
            server: "url_reputation",
            tool: "check",
            input: ["url": "https://example.com"]
        )

        let totalCalls = await mockClient.calls.count
        XCTAssertEqual(totalCalls, 2)

        let textAgentCalls = await mockClient.calls(byAgent: AgentID.textAgent)
        XCTAssertEqual(textAgentCalls.count, 1)

        let callCount = await mockClient.callCount(server: "scam_patterns", tool: "search")
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Error Handling

    func testToolCallFailure_PropagatesError() async throws {
        let underlyingError = NSError(domain: "test", code: 500, userInfo: nil)
        await mockClient.setNextError(
            GemScanError.mcpToolFailed(server: "test", tool: "fail", underlying: underlyingError)
        )

        do {
            _ = try await mockClient.call(
                agentId: AgentID.orchestrator,
                server: "test",
                tool: "fail",
                input: [:]
            )
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }

    // MARK: - Default Results

    func testUnconfiguredTool_ReturnsDefaultResult() async throws {
        let result = try await mockClient.call(
            agentId: AgentID.orchestrator,
            server: "any_server",
            tool: "any_tool",
            input: [:]
        )

        XCTAssertEqual(result["status"] as? String, "ok")
        XCTAssertEqual(result["mock"] as? Bool, true)
    }
}

// MARK: - MockMCPClient convenience extensions

extension MockMCPClient {
    func setAccessControl(_ acl: [String: Set<String>]) {
        self.accessControl = acl
    }

    func setNextError(_ error: Error) {
        self.nextError = error
    }
}
