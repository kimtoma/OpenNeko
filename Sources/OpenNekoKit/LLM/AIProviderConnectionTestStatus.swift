public enum AIProviderConnectionTestSeverity: Equatable, Sendable {
    case idle
    case running
    case success
    case failure
}

public struct AIProviderConnectionTestStatus: Equatable, Sendable {
    public let severity: AIProviderConnectionTestSeverity
    public let title: String
    public let detail: String
    public let systemImage: String

    public var isRunning: Bool {
        severity == .running
    }

    public init(
        severity: AIProviderConnectionTestSeverity,
        title: String,
        detail: String,
        systemImage: String
    ) {
        self.severity = severity
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }

    public static let idle = idle(languageCode: nil)

    public static func idle(languageCode: String?) -> AIProviderConnectionTestStatus {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        return AIProviderConnectionTestStatus(
            severity: .idle,
            title: localized(language, ko: "연결 테스트", en: "Connection Test", ja: "接続テスト", zh: "连接测试"),
            detail: localized(
                language,
                ko: "현재 설정으로 짧은 테스트 메시지를 보내 확인할 수 있습니다.",
                en: "Send a short test message with the current settings.",
                ja: "現在の設定で短いテストメッセージを送って確認できます。",
                zh: "可用当前设置发送一条短测试消息。"
            ),
            systemImage: "network"
        )
    }

    public static func running(providerTitle: String, languageCode: String? = nil) -> AIProviderConnectionTestStatus {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        return AIProviderConnectionTestStatus(
            severity: .running,
            title: localized(language, ko: "확인 중", en: "Checking", ja: "確認中", zh: "正在检查"),
            detail: localized(
                language,
                ko: "\(providerTitle)로 테스트 메시지를 보내고 있습니다.",
                en: "Sending a test message through \(providerTitle).",
                ja: "\(providerTitle)でテストメッセージを送信中です。",
                zh: "正在通过 \(providerTitle) 发送测试消息。"
            ),
            systemImage: "antenna.radiowaves.left.and.right"
        )
    }

    public static func success(reply: String, languageCode: String? = nil) -> AIProviderConnectionTestStatus {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        let summary = normalizedSummary(reply)
        return AIProviderConnectionTestStatus(
            severity: .success,
            title: localized(language, ko: "연결됨", en: "Connected", ja: "接続済み", zh: "已连接"),
            detail: successDetail(summary: summary, language: language),
            systemImage: "checkmark.seal.fill"
        )
    }

    public static func failure(message: String, languageCode: String? = nil) -> AIProviderConnectionTestStatus {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        let summary = normalizedSummary(message)
        return AIProviderConnectionTestStatus(
            severity: .failure,
            title: localized(language, ko: "확인 실패", en: "Check Failed", ja: "確認失敗", zh: "检查失败"),
            detail: summary.isEmpty ? fallbackFailureDetail(language: language) : summary,
            systemImage: "xmark.octagon.fill"
        )
    }

    private static func normalizedSummary(_ text: String) -> String {
        let collapsed = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return String(collapsed.prefix(96))
    }

    private static func successDetail(summary: String, language: String) -> String {
        guard !summary.isEmpty else {
            return localized(
                language,
                ko: "테스트 응답을 받았습니다.",
                en: "Received a test response.",
                ja: "テスト応答を受け取りました。",
                zh: "已收到测试回复。"
            )
        }
        switch language {
        case "en": return "Reply: \(summary)"
        case "ja": return "応答: \(summary)"
        case "zh": return "回复：\(summary)"
        default: return "응답: \(summary)"
        }
    }

    private static func fallbackFailureDetail(language: String) -> String {
        localized(
            language,
            ko: "연결 설정을 확인해 주세요.",
            en: "Check your connection settings.",
            ja: "接続設定を確認してください。",
            zh: "请检查连接设置。"
        )
    }

    private static func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": return en
        case "ja": return ja
        case "zh": return zh
        default: return ko
        }
    }
}
