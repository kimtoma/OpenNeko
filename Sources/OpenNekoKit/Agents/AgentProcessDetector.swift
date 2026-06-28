import Foundation

public struct AgentProcessDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let patterns: [String]

    public init(id: String, label: String, patterns: [String]) {
        self.id = id
        self.label = label
        self.patterns = patterns
    }
}

public struct AgentProcessActivity: Equatable, Sendable {
    public let source: String
    public let label: String
    public let cpu: Double

    public init(source: String, label: String, cpu: Double) {
        self.source = source
        self.label = label
        self.cpu = cpu
    }
}

public enum AgentProcessDetector {
    public static let busyCPUThreshold = 2.0
    public static let passiveActivitySources: Set<String> = ["codex-app"]

    public static let defaultDefinitions: [AgentProcessDefinition] = [
        AgentProcessDefinition(
            id: "cursor",
            label: "Cursor",
            patterns: [#"(^|/)(Cursor|cursor)(\.app|\s|$)"#, #"Cursor Helper"#, #"cursor-agent"#]
        ),
        AgentProcessDefinition(
            id: "claude",
            label: "Claude Code",
            patterns: [#"(^|/)claude(\s|$|-)"#, #"@anthropic-ai/claude-code"#, #"claude-code"#]
        ),
        AgentProcessDefinition(
            id: "codex-cli",
            label: "Codex CLI",
            patterns: [#"(^|/)codex(\s|$|-)"#, #"@openai/codex"#, #"codex-cli"#]
        ),
        AgentProcessDefinition(
            id: "codex-app-agent",
            label: "Codex App",
            patterns: [#"(^|/)Codex\.app/Contents/Resources/codex app-server(\s|$)"#]
        ),
        AgentProcessDefinition(
            id: "codex-app",
            label: "Codex App",
            patterns: [#"(^|/)Codex\.app/Contents/MacOS/Codex(\s|$)"#, #"Codex Helper"#]
        ),
        AgentProcessDefinition(
            id: "antigravity",
            label: "Antigravity",
            patterns: [#"(^|/)Antigravity(\.app|\s|$)"#, #"antigravity"#]
        ),
        AgentProcessDefinition(
            id: "gemini",
            label: "Gemini",
            patterns: [#"(^|/)gemini(\s|$|-)"#, #"@google/gemini-cli"#, #"gemini-cli"#]
        ),
        AgentProcessDefinition(
            id: "kiro",
            label: "Kiro",
            patterns: [#"(^|/)kiro(\s|$)"#, #"Kiro\.app"#, #"Kiro Helper"#]
        ),
    ]

    public static func detect(
        psOutput: String,
        definitions: [AgentProcessDefinition] = defaultDefinitions
    ) -> [AgentProcessActivity] {
        var maxCPUByID: [String: Double] = [:]
        var labelByID: [String: String] = [:]

        for line in psOutput.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let parsed = parsePSLine(String(line)) else { continue }
            guard !isKnownPassiveProcess(parsed.command) else { continue }
            for definition in definitions where matches(command: parsed.command, definition: definition) {
                maxCPUByID[definition.id] = max(maxCPUByID[definition.id] ?? 0, parsed.cpu)
                labelByID[definition.id] = definition.label
            }
        }

        return maxCPUByID.map { id, cpu in
            AgentProcessActivity(source: id, label: labelByID[id] ?? id, cpu: cpu)
        }
        .sorted { lhs, rhs in
            if lhs.cpu != rhs.cpu {
                return lhs.cpu > rhs.cpu
            }
            return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
        }
    }

    public static func topBusyActivity(
        in activities: [AgentProcessActivity],
        threshold: Double = busyCPUThreshold
    ) -> AgentProcessActivity? {
        activities.first { activity in
            !passiveActivitySources.contains(activity.source) && activity.cpu >= threshold
        }
    }

    private static func parsePSLine(_ line: String) -> (cpu: Double, command: String)? {
        guard
            let match = line.range(
                of: #"^\s*([0-9]+(?:\.[0-9]+)?)\s+(.+)$"#,
                options: .regularExpression
            )
        else {
            return nil
        }

        let matched = String(line[match])
        let parts = matched.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\t" }
        )
        guard parts.count == 2, let cpu = Double(parts[0]) else {
            return nil
        }
        return (cpu, String(parts[1]))
    }

    private static func matches(command: String, definition: AgentProcessDefinition) -> Bool {
        definition.patterns.contains { pattern in
            command.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func isKnownPassiveProcess(_ command: String) -> Bool {
        if command.contains("/Codex.app/Contents/Frameworks/")
            && (
                command.contains("--type=gpu-process")
                || command.contains("--type=renderer")
                || command.contains("browser_crashpad_handler")
                || command.contains("Codex (Service).app")
            ) {
            return true
        }
        if command.contains("CodexBarClaudeWatchdog") {
            return true
        }
        if matchesClaudeCommand(command) {
            let hasOneShotPrompt = command.contains(" -p ") || command.contains(" --print ")
            if command.contains(" --resume ")
                || command.contains(" --session-id ")
                || command.contains(" --settings ")
                || (command.contains(" --allowed-tools") && !hasOneShotPrompt) {
                return true
            }
        }
        return false
    }

    private static func matchesClaudeCommand(_ command: String) -> Bool {
        command.range(of: #"(^|/)claude(\s|$|-)"#, options: .regularExpression) != nil
    }
}
