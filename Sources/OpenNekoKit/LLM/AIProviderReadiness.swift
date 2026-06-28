import Foundation

public enum AIProviderReadinessSeverity: String, Equatable, Sendable {
    case ready
    case warning
    case needsAction
}

public struct AIProviderReadiness: Equatable, Sendable {
    public let severity: AIProviderReadinessSeverity
    public let title: String
    public let detail: String
    public let systemImage: String

    public init(
        severity: AIProviderReadinessSeverity,
        title: String,
        detail: String,
        systemImage: String
    ) {
        self.severity = severity
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }

    public static func evaluate(
        config: AIProviderConfig,
        preset: AIProviderPreset,
        hasResolvedAPIKey: Bool,
        cliExecutableAvailable: Bool?,
        languageCode: String? = nil
    ) -> AIProviderReadiness {
        switch config.type {
        case .codexCLI, .claudeCLI, .geminiCLI:
            return cliReadiness(
                preset: preset,
                executable: executableName(for: config.type),
                isAvailable: cliExecutableAvailable == true,
                languageCode: languageCode
            )
        case .gemini, .anthropic:
            return apiKeyReadiness(preset: preset, hasResolvedAPIKey: hasResolvedAPIKey, languageCode: languageCode)
        case .openAICompatible:
            return openAICompatibleReadiness(
                config: config,
                preset: preset,
                hasResolvedAPIKey: hasResolvedAPIKey,
                languageCode: languageCode
            )
        }
    }

    private static func cliReadiness(
        preset: AIProviderPreset,
        executable: String,
        isAvailable: Bool,
        languageCode: String?
    ) -> AIProviderReadiness {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        if isAvailable {
            return AIProviderReadiness(
                severity: .ready,
                title: localized(language, ko: "CLI 준비됨", en: "CLI Ready", ja: "CLI準備完了", zh: "CLI 已就绪"),
                detail: localized(
                    language,
                    ko: "`\(executable)` 명령을 찾았습니다. 로그인이 필요하면 첫 채팅 때 안내합니다.",
                    en: "Found `\(executable)`. If login is needed, the first chat will guide you.",
                    ja: "`\(executable)`が見つかりました。ログインが必要な場合は最初のチャットで案内します。",
                    zh: "已找到 `\(executable)`。如需登录，首次聊天时会提示。"
                ),
                systemImage: "checkmark.circle.fill"
            )
        }

        return AIProviderReadiness(
            severity: .needsAction,
            title: localized(
                language,
                ko: "\(preset.title(languageCode: language)) CLI 필요",
                en: "\(preset.title(languageCode: language)) CLI Needed",
                ja: "\(preset.title(languageCode: language)) CLIが必要",
                zh: "需要 \(preset.title(languageCode: language)) CLI"
            ),
            detail: localized(
                language,
                ko: "`\(executable)` 명령을 설치하고 로그인하세요.",
                en: "Install `\(executable)` and sign in.",
                ja: "`\(executable)`をインストールしてログインしてください。",
                zh: "请安装 `\(executable)` 并登录。"
            ),
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private static func apiKeyReadiness(
        preset: AIProviderPreset,
        hasResolvedAPIKey: Bool,
        languageCode: String?
    ) -> AIProviderReadiness {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        if hasResolvedAPIKey {
            return AIProviderReadiness(
                severity: .ready,
                title: localized(language, ko: "API 키 준비됨", en: "API Key Ready", ja: "APIキー準備完了", zh: "API Key 已就绪"),
                detail: localized(
                    language,
                    ko: "Keychain 또는 환경 변수에서 사용할 키를 찾았습니다.",
                    en: "Found a usable key in Keychain or the environment.",
                    ja: "Keychainまたは環境変数で使えるキーを見つけました。",
                    zh: "已在 Keychain 或环境变量中找到可用密钥。"
                ),
                systemImage: "checkmark.circle.fill"
            )
        }

        return AIProviderReadiness(
            severity: .needsAction,
            title: localized(language, ko: "API 키 필요", en: "API Key Needed", ja: "APIキーが必要", zh: "需要 API Key"),
            detail: localized(
                language,
                ko: "Keychain에 저장하거나 \(environmentLabel(for: preset, language: language)) 환경 변수를 설정하세요.",
                en: "Save a key to Keychain or set \(environmentLabel(for: preset, language: language)).",
                ja: "Keychainに保存するか、\(environmentLabel(for: preset, language: language))を設定してください。",
                zh: "请保存到 Keychain，或设置 \(environmentLabel(for: preset, language: language))。"
            ),
            systemImage: "key.slash"
        )
    }

    private static func openAICompatibleReadiness(
        config: AIProviderConfig,
        preset: AIProviderPreset,
        hasResolvedAPIKey: Bool,
        languageCode: String?
    ) -> AIProviderReadiness {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        if preset.isLocal && config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AIProviderReadiness(
                severity: .warning,
                title: localized(language, ko: "모델 이름 필요", en: "Model Name Needed", ja: "モデル名が必要", zh: "需要模型名称"),
                detail: localized(
                    language,
                    ko: "로컬 서버에서 사용할 모델 이름을 입력하세요.",
                    en: "Enter the model name to use on the local server.",
                    ja: "ローカルサーバーで使うモデル名を入力してください。",
                    zh: "请输入本地服务器使用的模型名称。"
                ),
                systemImage: "cpu"
            )
        }

        if preset.fields.contains(.apiKey) && !hasResolvedAPIKey {
            return AIProviderReadiness(
                severity: .warning,
                title: localized(language, ko: "API 키 없음", en: "No API Key", ja: "APIキーなし", zh: "没有 API Key"),
                detail: localized(
                    language,
                    ko: "서버가 키를 요구한다면 Keychain에 저장하세요.",
                    en: "If your server requires a key, save it to Keychain.",
                    ja: "サーバーがキーを要求する場合はKeychainに保存してください。",
                    zh: "如果服务器需要密钥，请保存到 Keychain。"
                ),
                systemImage: "key"
            )
        }

        if preset.isLocal {
            return AIProviderReadiness(
                severity: .ready,
                title: localized(language, ko: "로컬 연결 준비됨", en: "Local Connection Ready", ja: "ローカル接続準備完了", zh: "本地连接已就绪"),
                detail: localized(
                    language,
                    ko: "서버가 실행 중이면 현재 Base URL로 연결합니다.",
                    en: "If the server is running, openNeko will connect to the current Base URL.",
                    ja: "サーバーが実行中なら現在のBase URLに接続します。",
                    zh: "如果服务器正在运行，将连接到当前 Base URL。"
                ),
                systemImage: "checkmark.circle.fill"
            )
        }

        return AIProviderReadiness(
            severity: .ready,
            title: localized(language, ko: "연결 설정 준비됨", en: "Connection Ready", ja: "接続設定準備完了", zh: "连接设置已就绪"),
            detail: localized(
                language,
                ko: "현재 Base URL과 모델 설정으로 요청합니다.",
                en: "Requests will use the current Base URL and model settings.",
                ja: "現在のBase URLとモデル設定でリクエストします。",
                zh: "请求将使用当前 Base URL 和模型设置。"
            ),
            systemImage: "checkmark.circle.fill"
        )
    }

    private static func executableName(for type: AIProviderType) -> String {
        switch type {
        case .codexCLI: "codex"
        case .claudeCLI: "claude"
        case .geminiCLI: "gemini"
        case .openAICompatible, .gemini, .anthropic: ""
        }
    }

    private static func environmentLabel(for preset: AIProviderPreset, language: String) -> String {
        let separator: String
        switch language {
        case "en": separator = " or "
        case "ja": separator = " または "
        case "zh": separator = " 或 "
        default: separator = " 또는 "
        }
        return [preset.environmentKey, preset.alternateEnvironmentKey]
            .compactMap { $0 }
            .joined(separator: separator)
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
