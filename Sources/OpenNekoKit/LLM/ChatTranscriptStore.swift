import Foundation

public final class ChatTranscriptStore {
    public static let fileName = "chat-history.md"

    private static let formatMarker = "<!-- openNeko:chat-history:v1 -->"
    private static let userMarker = "<!-- openNeko:message role=user -->"
    private static let assistantMarker = "<!-- openNeko:message role=assistant -->"

    public let fileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    public init(
        fileURL: URL = ChatTranscriptStore.defaultFileURL(),
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.now = now
    }

    public static func defaultFileURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["OPENNEKO_CHAT_HISTORY_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return baseURL
            .appendingPathComponent("openNeko", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() -> [ChatMessage] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8)
        else {
            return []
        }
        return Self.parseMarkdown(text)
    }

    public func save(_ messages: [ChatMessage]) throws {
        guard !messages.isEmpty else {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(Self.markdown(for: messages, updatedAt: now()).utf8)
        try data.write(to: fileURL, options: .atomic)
    }

    public static func markdown(for messages: [ChatMessage], updatedAt: Date = Date()) -> String {
        var lines: [String] = [
            "# openNeko Chat History",
            "",
            formatMarker,
            "",
            "_Saved locally by openNeko so the chat history can be restored after restart._",
            "",
            "Last updated: \(ISO8601DateFormatter().string(from: updatedAt))",
            "",
        ]

        for message in messages {
            lines.append(marker(for: message.role))
            lines.append("### \(title(for: message.role))")
            lines.append("")
            lines.append(message.text)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    public static func parseMarkdown(_ markdown: String) -> [ChatMessage] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var messages: [ChatMessage] = []
        var currentRole: ChatRole?
        var bodyLines: [String] = []
        var skippingTitle = false

        func commitCurrentMessage() {
            guard let role = currentRole else { return }
            let text = trimBlankLines(bodyLines).joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            messages.append(ChatMessage(role: role, text: text))
        }

        for line in lines {
            if let role = roleMarker(line) {
                commitCurrentMessage()
                currentRole = role
                bodyLines = []
                skippingTitle = true
                continue
            }

            guard currentRole != nil else { continue }
            if skippingTitle {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                if line.hasPrefix("### ") {
                    skippingTitle = false
                    continue
                }
                skippingTitle = false
            }
            bodyLines.append(line)
        }

        commitCurrentMessage()
        return messages
    }

    private static func marker(for role: ChatRole) -> String {
        switch role {
        case .user: userMarker
        case .assistant: assistantMarker
        }
    }

    private static func roleMarker(_ line: String) -> ChatRole? {
        switch line.trimmingCharacters(in: .whitespacesAndNewlines) {
        case userMarker: .user
        case assistantMarker: .assistant
        default: nil
        }
    }

    private static func title(for role: ChatRole) -> String {
        switch role {
        case .user: "Me"
        case .assistant: "openNeko"
        }
    }

    private static func trimBlankLines(_ lines: [String]) -> [String] {
        var result = lines
        while result.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeFirst()
        }
        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeLast()
        }
        return result
    }
}
