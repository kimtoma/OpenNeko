import XCTest
@testable import OpenNekoKit

final class HTTPChatRequestBuilderTests: XCTestCase {
    func testOpenAICompatibleRequestUsesChatCompletionsEndpoint() throws {
        let request = try HTTPChatRequestBuilder.request(
            config: AIProviderPreset.config(
                for: "custom",
                overrides: AIProviderConfig(baseURL: "http://localhost:1234/v1/", model: "local-model")
            ),
            apiKey: "secret",
            history: [ChatMessage(role: .user, text: "안녕")],
            system: "짧게"
        )

        XCTAssertEqual(request.url.absoluteString, "http://localhost:1234/v1/chat/completions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer secret")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")

        let body = try request.jsonObject()
        XCTAssertEqual(body["model"] as? String, "local-model")
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages[0], ["role": "system", "content": "짧게"])
        XCTAssertEqual(messages[1], ["role": "user", "content": "안녕"])
    }

    func testOpenAICompatibleStreamingRequestEnablesServerSentEvents() throws {
        let request = try HTTPChatRequestBuilder.request(
            config: AIProviderPreset.config(for: "custom"),
            apiKey: nil,
            history: [ChatMessage(role: .user, text: "hello")],
            system: nil,
            stream: true
        )

        XCTAssertEqual(request.headers["Accept"], "text/event-stream")
        let body = try request.jsonObject()
        XCTAssertEqual(body["stream"] as? Bool, true)
    }

    func testGeminiRequestUsesGenerateContentEndpointAndKeyQuery() throws {
        let request = try HTTPChatRequestBuilder.request(
            config: AIProviderPreset.config(for: "gemini"),
            apiKey: "gemini-key",
            history: [ChatMessage(role: .user, text: "요약해줘")],
            system: "간단히"
        )

        XCTAssertEqual(
            request.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=gemini-key"
        )
        XCTAssertNil(request.headers["Authorization"])

        let body = try request.jsonObject()
        XCTAssertNotNil(body["systemInstruction"])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents[0]["role"] as? String, "user")
    }

    func testAnthropicRequestUsesMessagesEndpointAndAnthropicHeaders() throws {
        let request = try HTTPChatRequestBuilder.request(
            config: AIProviderPreset.config(for: "claude"),
            apiKey: "anthropic-key",
            history: [
                ChatMessage(role: .user, text: "질문"),
                ChatMessage(role: .assistant, text: "답"),
                ChatMessage(role: .user, text: "다시")
            ],
            system: "친절하게"
        )

        XCTAssertEqual(request.url.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.headers["x-api-key"], "anthropic-key")
        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")

        let body = try request.jsonObject()
        XCTAssertEqual(body["model"] as? String, "claude-opus-4-8")
        XCTAssertEqual(body["system"] as? String, "친절하게")
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"] }, ["user", "assistant", "user"])
    }

    func testCLIProviderTypesAreNotHTTPRequests() {
        XCTAssertThrowsError(
            try HTTPChatRequestBuilder.request(
                config: AIProviderPreset.defaultConfig,
                apiKey: nil,
                history: [],
                system: nil
            )
        )
    }
}

private extension HTTPChatRequest {
    func jsonObject() throws -> [String: Any] {
        let data = try XCTUnwrap(body)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
