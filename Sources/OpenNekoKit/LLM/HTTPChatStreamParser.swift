import Foundation

public struct HTTPChatStreamEvent: Equatable, Sendable {
    public let text: String
    public let isDone: Bool

    public init(text: String, isDone: Bool) {
        self.text = text
        self.isDone = isDone
    }
}

public enum HTTPChatStreamParser {
    public static func parseOpenAIEventLine(_ line: String) throws -> HTTPChatStreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed
            .dropFirst("data:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }
        if payload == "[DONE]" {
            return HTTPChatStreamEvent(text: "", isDone: true)
        }

        let object = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
        let choices = object?["choices"] as? [[String: Any]]
        let delta = choices?.first?["delta"] as? [String: Any]
        guard let content = delta?["content"] as? String, !content.isEmpty else {
            return nil
        }
        return HTTPChatStreamEvent(text: content, isDone: false)
    }

    public static func nonEmpty(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HTTPChatConfigurationError.emptyResponse
        }
        return trimmed
    }
}
