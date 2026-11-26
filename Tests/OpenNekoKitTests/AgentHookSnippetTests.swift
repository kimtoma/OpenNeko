import XCTest
@testable import OpenNekoKit

final class AgentHookSnippetTests: XCTestCase {
    func testNotifyCommandPostsStateAndNeverFailsTheAgent() {
        let command = AgentHookSnippet.notifyCommand(state: "waiting", source: "claude-code", port: 48801)

        XCTAssertTrue(command.hasPrefix("curl -s -m 2 -X POST http://127.0.0.1:48801/state "))
        XCTAssertTrue(command.contains(#"-d '{"state":"waiting","source":"claude-code"}'"#))
        XCTAssertTrue(command.hasSuffix(">/dev/null 2>&1 || true"))
    }

    func testClaudeCodeSettingsMapsNotificationToWaitingAndStopToDone() throws {
        let text = AgentHookSnippet.claudeCodeSettings(port: 48800)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])

        XCTAssertEqual(Set(hooks.keys), ["Notification", "Stop"])
        XCTAssertEqual(try command(in: hooks, event: "Notification"),
                       AgentHookSnippet.notifyCommand(state: "waiting", source: "claude-code", port: 48800))
        XCTAssertEqual(try command(in: hooks, event: "Stop"),
                       AgentHookSnippet.notifyCommand(state: "done", source: "claude-code", port: 48800))
        XCTAssertFalse(text.contains("\\/"), "URLs should stay readable in the copied JSON")
    }

    func testCodexConfigIsATopLevelNotifyArrayWithEscapedQuotes() {
        let line = AgentHookSnippet.codexConfig(port: 48800)

        XCTAssertTrue(line.hasPrefix(#"notify = ["sh", "-c", "curl -s -m 2"#))
        XCTAssertTrue(line.contains(#"-d '{\"state\":\"done\",\"source\":\"codex\"}'"#))
        XCTAssertTrue(line.hasSuffix(#"|| true"]"#))
    }

    func testTomlBasicStringEscapesBackslashBeforeQuotes() {
        XCTAssertEqual(AgentHookSnippet.tomlBasicString(#"a\"b"#), #""a\\\"b""#)
    }

    func testBridgeStatesUsedBySnippetsAreAccepted() throws {
        for state in ["waiting", "done"] {
            let json = #"{"state":"\#(state)","source":"claude-code"}"#
            XCTAssertNoThrow(try StateBridgeRequest.parse(Data(json.utf8)))
        }
    }

    func testTargetsNameTheirConfigFiles() {
        XCTAssertEqual(AgentHookTarget.claudeCode.configPath, "~/.claude/settings.json")
        XCTAssertEqual(AgentHookTarget.codex.configPath, "~/.codex/config.toml")
        XCTAssertEqual(AgentHookSnippet.snippet(for: .codex, port: 48800), AgentHookSnippet.codexConfig(port: 48800))
    }

    private func command(in hooks: [String: Any], event: String) throws -> String? {
        let groups = try XCTUnwrap(hooks[event] as? [[String: Any]])
        let inner = try XCTUnwrap(groups.first?["hooks"] as? [[String: Any]])
        XCTAssertEqual(inner.first?["type"] as? String, "command")
        return inner.first?["command"] as? String
    }
}
