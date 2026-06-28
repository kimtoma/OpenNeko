import Foundation

public enum HTTPChatConfigurationError: Error, Equatable {
    case unsupportedProvider(AIProviderType)
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case emptyResponse
    case unsupportedResponse(AIProviderType)
}

public struct HTTPChatRequest: Equatable, Sendable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data?

    public init(url: URL, method: String = "POST", headers: [String: String], body: Data?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public enum HTTPChatRequestBuilder {
    private static let defaultOpenAIBaseURL = "https://api.openai.com/v1"
    private static let defaultOpenAIModel = "gpt-4o-mini"
    private static let maxTokens = 1024

    public static func request(
        config: AIProviderConfig,
        apiKey: String?,
        history: [ChatMessage],
        system: String?,
        stream: Bool = false
    ) throws -> HTTPChatRequest {
        switch config.type {
        case .openAICompatible:
            return try openAICompatibleRequest(
                config: config,
                apiKey: apiKey,
                history: history,
                system: system,
                stream: stream
            )
        case .gemini:
            return try geminiRequest(config: config, apiKey: apiKey, history: history, system: system)
        case .anthropic:
            return try anthropicRequest(config: config, apiKey: apiKey, history: history, system: system)
        case .codexCLI, .claudeCLI, .geminiCLI:
            throw HTTPChatConfigurationError.unsupportedProvider(config.type)
        }
    }

    private static func openAICompatibleRequest(
        config: AIProviderConfig,
        apiKey: String?,
        history: [ChatMessage],
        system: String?,
        stream: Bool
    ) throws -> HTTPChatRequest {
        let baseURL = config.baseURL.isEmpty ? defaultOpenAIBaseURL : config.baseURL
        let url = try endpoint(baseURL: baseURL, path: "chat/completions")
        let model = config.model.isEmpty ? defaultOpenAIModel : config.model
        let messages = openAIMessages(history: history, system: system)
        var payload: [String: Any] = [
            "model": model,
            "messages": messages,
        ]
        if stream {
            payload["stream"] = true
        }
        let body = try jsonData(payload)
        var headers = jsonHeaders(accept: stream ? "text/event-stream" : "application/json")
        if let apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        return HTTPChatRequest(url: url, headers: headers, body: body)
    }

    private static func geminiRequest(
        config: AIProviderConfig,
        apiKey: String?,
        history: [ChatMessage],
        system: String?
    ) throws -> HTTPChatRequest {
        guard let apiKey, !apiKey.isEmpty else {
            throw HTTPChatConfigurationError.missingAPIKey("Gemini API key")
        }
        let model = config.model.isEmpty ? "gemini-3.5-flash" : config.model
        var components = URLComponents()
        components.scheme = "https"
        components.host = "generativelanguage.googleapis.com"
        components.path = "/v1beta/models/\(model):generateContent"
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw HTTPChatConfigurationError.invalidBaseURL("generativelanguage.googleapis.com")
        }

        var payload: [String: Any] = [
            "contents": geminiContents(history: history),
        ]
        if let system, !system.isEmpty {
            payload["systemInstruction"] = [
                "parts": [["text": system]],
            ]
        }

        return HTTPChatRequest(url: url, headers: jsonHeaders(), body: try jsonData(payload))
    }

    private static func anthropicRequest(
        config: AIProviderConfig,
        apiKey: String?,
        history: [ChatMessage],
        system: String?
    ) throws -> HTTPChatRequest {
        guard let apiKey, !apiKey.isEmpty else {
            throw HTTPChatConfigurationError.missingAPIKey("Anthropic API key")
        }
        let baseURL = config.baseURL.isEmpty ? "https://api.anthropic.com/v1" : config.baseURL
        let url = try endpoint(baseURL: baseURL, path: "messages")
        let model = config.model.isEmpty ? "claude-opus-4-8" : config.model
        var payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": history.suffix(ChatPromptBuilder.maxTurns).map { message in
                [
                    "role": message.role == .assistant ? "assistant" : "user",
                    "content": message.text,
                ]
            },
        ]
        if let system, !system.isEmpty {
            payload["system"] = system
        }

        var headers = jsonHeaders()
        headers["x-api-key"] = apiKey
        headers["anthropic-version"] = "2023-06-01"
        return HTTPChatRequest(url: url, headers: headers, body: try jsonData(payload))
    }

    private static func openAIMessages(history: [ChatMessage], system: String?) -> [[String: String]] {
        var messages: [[String: String]] = []
        if let system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(contentsOf: history.suffix(ChatPromptBuilder.maxTurns).map { message in
            [
                "role": message.role == .assistant ? "assistant" : "user",
                "content": message.text,
            ]
        })
        return messages
    }

    private static func geminiContents(history: [ChatMessage]) -> [[String: Any]] {
        history.suffix(ChatPromptBuilder.maxTurns).map { message in
            [
                "role": message.role == .assistant ? "model" : "user",
                "parts": [["text": message.text]],
            ]
        }
    }

    private static func endpoint(baseURL: String, path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/\(path)") else {
            throw HTTPChatConfigurationError.invalidBaseURL(baseURL)
        }
        return url
    }

    private static func jsonHeaders(accept: String = "application/json") -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": accept,
        ]
    }

    private static func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

public enum HTTPChatResponseParser {
    public static func parse(_ data: Data, type: AIProviderType) throws -> String {
        switch type {
        case .openAICompatible:
            return try parseOpenAI(data)
        case .gemini:
            return try parseGemini(data)
        case .anthropic:
            return try parseAnthropic(data)
        case .codexCLI, .claudeCLI, .geminiCLI:
            throw HTTPChatConfigurationError.unsupportedResponse(type)
        }
    }

    private static func parseOpenAI(_ data: Data) throws -> String {
        let root = try jsonObject(data)
        let choices = root["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return try nonEmptyText(message?["content"] as? String)
    }

    private static func parseGemini(_ data: Data) throws -> String {
        let root = try jsonObject(data)
        let candidates = root["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.compactMap { $0["text"] as? String }.joined()
        return try nonEmptyText(text)
    }

    private static func parseAnthropic(_ data: Data) throws -> String {
        let root = try jsonObject(data)
        let content = root["content"] as? [[String: Any]]
        let text = content?.compactMap { $0["text"] as? String }.joined()
        return try nonEmptyText(text)
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private static func nonEmptyText(_ text: String?) throws -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HTTPChatConfigurationError.emptyResponse
        }
        return trimmed
    }
}
