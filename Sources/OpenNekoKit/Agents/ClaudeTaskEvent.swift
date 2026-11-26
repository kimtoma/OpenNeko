import Foundation

public enum AgentActionRisk: String, Codable, Equatable, Sendable {
    case normal
    /// Deleting, sending, publishing or reaching outside the machine.
    case irreversible
}

/// A tool call the CLI agent wanted but was not allowed to make.
public struct AgentPermissionRequest: Equatable, Sendable {
    public let toolName: String
    /// Human-readable target: the shell command, file path or URL.
    public let detail: String

    public init(toolName: String, detail: String) {
        self.toolName = toolName
        self.detail = detail
    }

    /// The `--allowedTools` rule that grants exactly this call.
    public var allowRule: String {
        if toolName == "Bash", !detail.isEmpty {
            return "Bash(\(detail))"
        }
        return toolName
    }

    public var risk: AgentActionRisk {
        if ["WebFetch", "WebSearch"].contains(toolName) {
            return .normal
        }
        guard toolName == "Bash" else {
            return .normal
        }
        let command = " " + detail.lowercased() + " "
        let markers = [
            " rm ", " rmdir ", " unlink ", " shred ", "git push", "git reset --hard", "git clean",
            " curl ", " wget ", " ssh ", " scp ", " rsync ", "npm publish", "pod trunk", "gh release",
            " mail ", "sendmail", "osascript", " sudo ", " mv ", "> /", "launchctl", "defaults write",
        ]
        return markers.contains { command.contains($0) } ? .irreversible : .normal
    }
}

public struct AgentToolUse: Equatable, Sendable {
    public let name: String
    public let detail: String

    public init(name: String, detail: String) {
        self.name = name
        self.detail = detail
    }
}

public struct ClaudeTaskResult: Equatable, Sendable {
    public let text: String
    public let isError: Bool
    public let sessionID: String?
    public let denials: [AgentPermissionRequest]

    public init(text: String, isError: Bool, sessionID: String?, denials: [AgentPermissionRequest]) {
        self.text = text
        self.isError = isError
        self.sessionID = sessionID
        self.denials = denials
    }
}

public enum ClaudeTaskEvent: Equatable, Sendable {
    case started(sessionID: String)
    case text(String)
    case toolUse(AgentToolUse)
    case finished(ClaudeTaskResult)
}

/// Parses one line of `claude -p --output-format stream-json --verbose`.
public enum ClaudeTaskEventParser {
    public static func events(fromLine line: String) -> [ClaudeTaskEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else {
            return []
        }

        switch type {
        case "system":
            guard (object["subtype"] as? String) == "init", let id = object["session_id"] as? String else {
                return []
            }
            return [.started(sessionID: id)]

        case "assistant":
            guard
                let message = object["message"] as? [String: Any],
                let content = message["content"] as? [[String: Any]]
            else {
                return []
            }
            return content.compactMap { (block: [String: Any]) -> ClaudeTaskEvent? in
                switch block["type"] as? String {
                case "text":
                    let text = (block["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : .text(text)
                case "tool_use":
                    let name = block["name"] as? String ?? "tool"
                    let input = block["input"] as? [String: Any] ?? [:]
                    return .toolUse(AgentToolUse(name: name, detail: detail(from: input)))
                default:
                    return nil
                }
            }

        case "result":
            let rawDenials = object["permission_denials"] as? [[String: Any]] ?? []
            let denials = rawDenials.map { denial in
                AgentPermissionRequest(
                    toolName: denial["tool_name"] as? String ?? "tool",
                    detail: detail(from: denial["tool_input"] as? [String: Any] ?? [:])
                )
            }
            let subtype = object["subtype"] as? String ?? ""
            let isError = (object["is_error"] as? Bool) ?? (subtype != "success")
            return [.finished(ClaudeTaskResult(
                text: (object["result"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                isError: isError,
                sessionID: object["session_id"] as? String,
                denials: denials
            ))]

        default:
            return []
        }
    }

    /// The most useful single field of a tool input, for logs and bubbles.
    static func detail(from input: [String: Any]) -> String {
        for key in ["command", "file_path", "path", "url", "pattern", "query", "notebook_path"] {
            if let value = input[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }
}
