import Foundation

/// Agents that can notify the cat through their own hook settings.
public enum AgentHookTarget: String, CaseIterable, Sendable {
    case claudeCode = "claude-code"
    case codex

    /// The config file the user pastes the snippet into.
    public var configPath: String {
        switch self {
        case .claudeCode: "~/.claude/settings.json"
        case .codex: "~/.codex/config.toml"
        }
    }

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }
}

/// Builds copy-paste hook snippets that make an agent call the local state
/// bridge when it needs the user or finishes a turn. OpenNeko only shows
/// these; it never edits another tool's config on its own.
public enum AgentHookSnippet {
    /// A shell command that posts one bridge state and never fails the agent:
    /// short timeout, silenced output, always exits 0.
    public static func notifyCommand(state: String, source: String, port: UInt16) -> String {
        let body = #"{"state":"\#(state)","source":"\#(source)"}"#
        return "curl -s -m 2 -X POST \(StateBridgeExample.stateURL(port: port)) "
            + "-H 'Content-Type: application/json' -d '\(body)' >/dev/null 2>&1 || true"
    }

    public static func snippet(for target: AgentHookTarget, port: UInt16) -> String {
        switch target {
        case .claudeCode: claudeCodeSettings(port: port)
        case .codex: codexConfig(port: port)
        }
    }

    /// `hooks` block for Claude Code's settings.json: `Notification` fires
    /// when it waits for permission or input, `Stop` when a turn finishes.
    public static func claudeCodeSettings(port: UInt16) -> String {
        let source = AgentHookTarget.claudeCode.rawValue
        func entry(_ state: String) -> [[String: Any]] {
            [["hooks": [["type": "command", "command": notifyCommand(state: state, source: source, port: port)]]]]
        }
        let root: [String: Any] = [
            "hooks": [
                "Notification": entry("waiting"),
                "Stop": entry("done"),
            ],
        ]
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }

    /// Top-level `notify` line for Codex's config.toml. Codex runs it after
    /// each agent turn; the JSON argument it appends is ignored.
    public static func codexConfig(port: UInt16) -> String {
        let command = notifyCommand(state: "done", source: AgentHookTarget.codex.rawValue, port: port)
        return "notify = [\"sh\", \"-c\", \(tomlBasicString(command))]"
    }

    static func tomlBasicString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
