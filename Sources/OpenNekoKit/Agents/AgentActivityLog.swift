import Foundation

/// One line of the local agent activity log
/// (`~/Library/Application Support/openNeko/agent-activity.jsonl`).
public struct AgentActivityEntry: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case started
        case tool
        case approvalRequested
        case approved
        case denied
        case finished
        case failed
    }

    public let timestamp: Date
    public let agent: String
    public let folder: String
    public let kind: Kind
    public let detail: String

    public init(timestamp: Date, agent: String, folder: String, kind: Kind, detail: String) {
        self.timestamp = timestamp
        self.agent = agent
        self.folder = folder
        self.kind = kind
        self.detail = String(detail.prefix(2_000))
    }

    public func jsonLine() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public static func decode(line: String) -> AgentActivityEntry? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AgentActivityEntry.self, from: Data(line.utf8))
    }
}

/// Splits a byte stream into complete lines, keeping a partial tail.
public struct LineBuffer: Equatable, Sendable {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let index = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<index]
            lines.append(String(decoding: lineData, as: UTF8.self))
            pending.removeSubrange(pending.startIndex...index)
        }
        return lines
    }

    public mutating func flush() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending = Data() }
        return String(decoding: pending, as: UTF8.self)
    }
}
