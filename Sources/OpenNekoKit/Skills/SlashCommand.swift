import Foundation

public enum SlashCommandKind: String, Codable, Equatable, Sendable {
    case builtin
    case app
    case skill
}

public struct SlashCommand: Equatable, Sendable {
    public let command: String
    public let arguments: String

    public init(command: String, arguments: String) {
        self.command = command
        self.arguments = arguments
    }
}

public struct SlashCommandDescriptor: Equatable, Sendable {
    public let name: String
    public let kind: SlashCommandKind
    public let description: String

    public init(name: String, kind: SlashCommandKind, description: String) {
        self.name = name
        self.kind = kind
        self.description = description
    }
}

public enum SlashCommandParser {
    public static func parse(_ line: String) -> SlashCommand? {
        guard line.first == "/" else { return nil }
        let rest = line.dropFirst()
        guard !rest.isEmpty else { return nil }

        let splitIndex = rest.firstIndex(where: { $0.isWhitespace })
        let rawCommand: Substring
        let rawArguments: Substring
        if let splitIndex {
            rawCommand = rest[..<splitIndex]
            rawArguments = rest[rest.index(after: splitIndex)...]
        } else {
            rawCommand = rest[...]
            rawArguments = ""
        }

        let command = String(rawCommand).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !command.isEmpty else { return nil }
        return SlashCommand(
            command: command,
            arguments: String(rawArguments).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public static func matchingCommands(
        prefix: String,
        catalog: [SlashCommandDescriptor]
    ) -> [SlashCommandDescriptor] {
        let normalized = prefix.lowercased()
        return catalog
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
