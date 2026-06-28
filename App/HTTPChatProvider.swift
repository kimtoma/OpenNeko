import Foundation
import OpenNekoKit

enum HTTPChatError: Error {
    case configuration(String)
    case auth
    case notFound
    case connection
    case http(Int, String)
    case empty

    var userMessage: String {
        userMessage(languageCode: "ko")
    }

    func userMessage(languageCode: String?) -> String {
        switch self {
        case .configuration(let message):
            message
        case .auth:
            Self.localized(languageCode, ko: "API 키나 로그인을 확인해달라냥", en: "Check the API key or login, nya.", ja: "APIキーかログインを確認してにゃ", zh: "请检查 API Key 或登录喵")
        case .notFound:
            Self.localized(languageCode, ko: "모델이나 엔드포인트를 못 찾았다냥", en: "I could not find that model or endpoint, nya.", ja: "モデルかエンドポイントが見つからないにゃ", zh: "找不到模型或端点喵")
        case .connection:
            Self.localized(languageCode, ko: "AI 서버에 연결하지 못했다냥", en: "I could not connect to the AI server, nya.", ja: "AIサーバーに接続できないにゃ", zh: "没能连接到 AI 服务器喵")
        case .http:
            Self.localized(languageCode, ko: "AI 서버 응답을 처리하지 못했다냥", en: "I could not handle the AI server response, nya.", ja: "AIサーバーの応答を処理できないにゃ", zh: "没能处理 AI 服务器响应喵")
        case .empty:
            Self.localized(languageCode, ko: "빈 응답이 왔다냥", en: "The response was empty, nya.", ja: "空の返事だったにゃ", zh: "返回了空响应喵")
        }
    }

    static func missingAPIKeyMessage(languageCode: String?) -> String {
        localized(languageCode, ko: "API 키를 먼저 저장해달라냥", en: "Save an API key first, nya.", ja: "先にAPIキーを保存してにゃ", zh: "请先保存 API Key 喵")
    }

    static func invalidBaseURLMessage(languageCode: String?) -> String {
        localized(languageCode, ko: "Base URL을 확인해달라냥", en: "Check the Base URL, nya.", ja: "Base URLを確認してにゃ", zh: "请检查 Base URL 喵")
    }

    static func unsupportedProviderMessage(languageCode: String?) -> String {
        localized(languageCode, ko: "이 provider는 아직 HTTP 채팅을 못 한다냥", en: "This provider cannot use HTTP chat yet, nya.", ja: "このproviderはまだHTTPチャットできないにゃ", zh: "这个 provider 还不能使用 HTTP 聊天喵")
    }

    static func invalidSettingsMessage(languageCode: String?) -> String {
        localized(languageCode, ko: "AI 연결 설정을 확인해달라냥", en: "Check the AI connection settings, nya.", ja: "AI接続設定を確認してにゃ", zh: "请检查 AI 连接设置喵")
    }

    private static func localized(
        _ languageCode: String?,
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}

final class HTTPChatProvider {
    private let config: AIProviderConfig
    private let apiKey: String?
    private let languageCode: String
    private let session: URLSession

    init(
        config: AIProviderConfig,
        apiKey: String?,
        languageCode: String = "ko",
        session: URLSession = .shared
    ) {
        self.config = config
        self.apiKey = apiKey
        self.languageCode = languageCode
        self.session = session
    }

    func chat(
        history: [ChatMessage],
        system: String? = nil,
        onPartial: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let descriptor: HTTPChatRequest
        let stream = onPartial != nil && config.type == .openAICompatible
        do {
            descriptor = try HTTPChatRequestBuilder.request(
                config: config,
                apiKey: apiKey,
                history: history,
                system: system ?? ChatPromptBuilder.defaultSystemPrompt(languageCode: languageCode),
                stream: stream
            )
        } catch HTTPChatConfigurationError.missingAPIKey {
            throw HTTPChatError.configuration(HTTPChatError.missingAPIKeyMessage(languageCode: languageCode))
        } catch HTTPChatConfigurationError.invalidBaseURL {
            throw HTTPChatError.configuration(HTTPChatError.invalidBaseURLMessage(languageCode: languageCode))
        } catch HTTPChatConfigurationError.unsupportedProvider {
            throw HTTPChatError.configuration(HTTPChatError.unsupportedProviderMessage(languageCode: languageCode))
        } catch {
            throw HTTPChatError.configuration(HTTPChatError.invalidSettingsMessage(languageCode: languageCode))
        }

        var request = URLRequest(url: descriptor.url)
        request.httpMethod = descriptor.method
        request.httpBody = descriptor.body
        request.timeoutInterval = 120
        for (key, value) in descriptor.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            if stream, let onPartial {
                return try await streamOpenAICompatibleResponse(for: request, onPartial: onPartial)
            }

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPChatError.connection
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw classifyHTTP(statusCode: httpResponse.statusCode, data: data)
            }
            return try HTTPChatResponseParser.parse(data, type: config.type)
        } catch let error as HTTPChatError {
            throw error
        } catch HTTPChatConfigurationError.emptyResponse {
            throw HTTPChatError.empty
        } catch {
            throw HTTPChatError.connection
        }
    }

    private func streamOpenAICompatibleResponse(
        for request: URLRequest,
        onPartial: @Sendable (String) -> Void
    ) async throws -> String {
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPChatError.connection
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let data = try await limitedData(from: bytes, limit: 4096)
            throw classifyHTTP(statusCode: httpResponse.statusCode, data: data)
        }

        var fullText = ""
        for try await line in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }
            guard let event = try HTTPChatStreamParser.parseOpenAIEventLine(line) else {
                continue
            }
            if event.isDone {
                break
            }
            fullText += event.text
            onPartial(fullText)
        }
        return try HTTPChatStreamParser.nonEmpty(fullText)
    }

    private func limitedData(from bytes: URLSession.AsyncBytes, limit: Int) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count >= limit {
                break
            }
        }
        return data
    }

    private func classifyHTTP(statusCode: Int, data: Data) -> HTTPChatError {
        if statusCode == 401 || statusCode == 403 {
            return .auth
        }
        if statusCode == 404 {
            return .notFound
        }
        let snippet = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(
                of: #"Bearer\s+\S+"#,
                with: "Bearer ...",
                options: [.regularExpression, .caseInsensitive]
            )
            .prefix(240)
        return .http(statusCode, String(snippet))
    }
}
