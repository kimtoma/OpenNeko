import XCTest
@testable import OpenNekoKit

final class ClaudeTaskEventTests: XCTestCase {
    func testParsesInitAssistantAndResultLines() {
        XCTAssertEqual(
            ClaudeTaskEventParser.events(fromLine: #"{"type":"system","subtype":"init","session_id":"s1","cwd":"/tmp"}"#),
            [.started(sessionID: "s1")]
        )
        XCTAssertEqual(
            ClaudeTaskEventParser.events(fromLine: #"{"type":"assistant","message":{"content":[{"type":"text","text":" Looking "},{"type":"tool_use","name":"Edit","input":{"file_path":"/p/a.swift","old_string":"x"}}]}}"#),
            [.text("Looking"), .toolUse(AgentToolUse(name: "Edit", detail: "/p/a.swift"))]
        )

        let result = ClaudeTaskEventParser.events(fromLine: #"{"type":"result","subtype":"success","is_error":false,"result":"Done.","session_id":"s1","permission_denials":[{"tool_name":"Bash","tool_use_id":"t","tool_input":{"command":"npm test"}}]}"#)
        XCTAssertEqual(result, [.finished(ClaudeTaskResult(
            text: "Done.",
            isError: false,
            sessionID: "s1",
            denials: [AgentPermissionRequest(toolName: "Bash", detail: "npm test")]
        ))])
    }

    func testErrorResultWithoutIsErrorFlagUsesSubtype() {
        let events = ClaudeTaskEventParser.events(fromLine: #"{"type":"result","subtype":"error_max_turns","session_id":"s"}"#)
        guard case let .finished(result) = events.first else { return XCTFail() }
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.denials, [])
    }

    func testIgnoresOtherLines() {
        XCTAssertEqual(ClaudeTaskEventParser.events(fromLine: ""), [])
        XCTAssertEqual(ClaudeTaskEventParser.events(fromLine: "not json"), [])
        XCTAssertEqual(ClaudeTaskEventParser.events(fromLine: #"{"type":"user","message":{}}"#), [])
        XCTAssertEqual(ClaudeTaskEventParser.events(fromLine: #"{"type":"system","subtype":"other"}"#), [])
    }

    func testAllowRulesAndRisk() {
        let test = AgentPermissionRequest(toolName: "Bash", detail: "npm test")
        XCTAssertEqual(test.allowRule, "Bash(npm test)")
        XCTAssertEqual(test.risk, .normal)

        XCTAssertEqual(AgentPermissionRequest(toolName: "Bash", detail: "rm -rf build").risk, .irreversible)
        XCTAssertEqual(AgentPermissionRequest(toolName: "Bash", detail: "git push origin main").risk, .irreversible)
        XCTAssertEqual(AgentPermissionRequest(toolName: "Bash", detail: "curl https://x").risk, .irreversible)
        XCTAssertEqual(AgentPermissionRequest(toolName: "Bash", detail: "npm run format").risk, .normal)
        XCTAssertEqual(AgentPermissionRequest(toolName: "WebFetch", detail: "https://x").allowRule, "WebFetch")
    }
}
