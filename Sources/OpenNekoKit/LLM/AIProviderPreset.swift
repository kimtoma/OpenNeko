public enum AIProviderType: String, Codable, Equatable, Sendable {
    case codexCLI = "codex-cli"
    case claudeCLI = "claude-cli"
    case geminiCLI = "gemini-cli"
    case openAICompatible = "openai-compat"
    case gemini
    case anthropic
}

public enum AIProviderField: String, Codable, Equatable, Sendable {
    case baseURL
    case apiKey
    case model
}

public struct AIProviderConfig: Codable, Equatable, Sendable {
    public var presetID: String
    public var type: AIProviderType
    public var baseURL: String
    public var model: String

    public init(
        presetID: String = "",
        type: AIProviderType = .codexCLI,
        baseURL: String? = nil,
        model: String? = nil
    ) {
        self.presetID = presetID
        self.type = type
        self.baseURL = baseURL ?? ""
        self.model = model ?? ""
    }
}

public struct AIProviderPreset: Equatable, Identifiable, Sendable {
    public static let defaultID = "chatgpt-oauth"

    public static let all: [AIProviderPreset] = [
        AIProviderPreset(
            id: "chatgpt-oauth",
            title: "OpenAI 로그인 (Codex)",
            type: .codexCLI,
            defaultModel: "",
            fields: [.model],
            note: "Codex CLI 로그인 세션을 사용합니다. 먼저 `codex login`이 필요합니다.",
            isRecommended: true
        ),
        AIProviderPreset(
            id: "claude-oauth",
            title: "Claude 로그인",
            type: .claudeCLI,
            defaultModel: "",
            fields: [.model],
            note: "Claude CLI 로그인 세션을 사용합니다."
        ),
        AIProviderPreset(
            id: "gemini-oauth",
            title: "Gemini 로그인",
            type: .geminiCLI,
            defaultModel: "",
            fields: [.model],
            note: "Gemini CLI Google 로그인 세션을 사용합니다."
        ),
        AIProviderPreset(
            id: "ollama",
            title: "Ollama",
            type: .openAICompatible,
            defaultBaseURL: "http://localhost:11434/v1",
            fields: [.baseURL, .model],
            note: "로컬 Ollama 서버와 연결합니다.",
            isLocal: true
        ),
        AIProviderPreset(
            id: "local-openai",
            title: "로컬 OpenAI 호환",
            type: .openAICompatible,
            defaultBaseURL: "http://localhost:1234/v1",
            fields: [.baseURL, .model],
            note: "LM Studio, llama.cpp, vLLM 같은 로컬 서버와 연결합니다.",
            isLocal: true
        ),
        AIProviderPreset(
            id: "gemini",
            title: "Gemini API 키",
            type: .gemini,
            defaultModel: "gemini-3.5-flash",
            fields: [.apiKey, .model],
            note: "Google AI Studio API 키를 사용합니다.",
            requiresAPIKey: true,
            environmentKey: "GEMINI_API_KEY",
            alternateEnvironmentKey: "GOOGLE_API_KEY"
        ),
        AIProviderPreset(
            id: "claude",
            title: "Claude API 키",
            type: .anthropic,
            defaultBaseURL: "https://api.anthropic.com/v1",
            defaultModel: "claude-opus-4-8",
            fields: [.apiKey, .model],
            note: "Anthropic API 키를 사용합니다.",
            requiresAPIKey: true,
            environmentKey: "ANTHROPIC_API_KEY"
        ),
        AIProviderPreset(
            id: "custom",
            title: "사용자 지정",
            type: .openAICompatible,
            fields: [.baseURL, .apiKey, .model],
            note: "OpenAI 호환 엔드포인트를 직접 입력합니다."
        ),
    ]

    public static var defaultConfig: AIProviderConfig {
        config(for: defaultID)
    }

    public let id: String
    public let title: String
    public let type: AIProviderType
    public let defaultBaseURL: String
    public let defaultModel: String
    public let fields: [AIProviderField]
    public let note: String
    public let isRecommended: Bool
    public let isLocal: Bool
    public let requiresAPIKey: Bool
    public let environmentKey: String?
    public let alternateEnvironmentKey: String?

    public init(
        id: String,
        title: String,
        type: AIProviderType,
        defaultBaseURL: String = "",
        defaultModel: String = "",
        fields: [AIProviderField],
        note: String,
        isRecommended: Bool = false,
        isLocal: Bool = false,
        requiresAPIKey: Bool = false,
        environmentKey: String? = nil,
        alternateEnvironmentKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.defaultBaseURL = defaultBaseURL
        self.defaultModel = defaultModel
        self.fields = fields
        self.note = note
        self.isRecommended = isRecommended
        self.isLocal = isLocal
        self.requiresAPIKey = requiresAPIKey
        self.environmentKey = environmentKey
        self.alternateEnvironmentKey = alternateEnvironmentKey
    }

    public static func preset(for id: String) -> AIProviderPreset? {
        all.first { $0.id == id }
    }

    public func title(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            englishTitle
        case "ja":
            japaneseTitle
        case "zh":
            chineseTitle
        default:
            title
        }
    }

    public func note(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            englishNote
        case "ja":
            japaneseNote
        case "zh":
            chineseNote
        default:
            note
        }
    }

    public static func config(
        for id: String,
        overrides: AIProviderConfig = AIProviderConfig()
    ) -> AIProviderConfig {
        guard let preset = preset(for: id) else {
            return config(for: defaultID)
        }

        return AIProviderConfig(
            presetID: preset.id,
            type: preset.type,
            baseURL: overrides.baseURL.isEmpty ? preset.defaultBaseURL : overrides.baseURL,
            model: overrides.model.isEmpty ? preset.defaultModel : overrides.model
        )
    }

    public static func resolveAPIKey(
        presetID: String,
        savedKey: String?,
        environment: [String: String]
    ) -> String? {
        if let savedKey, !savedKey.isEmpty {
            return savedKey
        }

        guard let preset = preset(for: presetID) else {
            return savedKey
        }

        if let key = preset.environmentKey, let value = environment[key], !value.isEmpty {
            return value
        }

        if let key = preset.alternateEnvironmentKey, let value = environment[key], !value.isEmpty {
            return value
        }

        return savedKey
    }

    private var englishTitle: String {
        switch id {
        case "chatgpt-oauth": return "OpenAI Login (Codex)"
        case "claude-oauth": return "Claude Login"
        case "gemini-oauth": return "Gemini Login"
        case "local-openai": return "Local OpenAI Compatible"
        case "gemini": return "Gemini API Key"
        case "claude": return "Claude API Key"
        case "custom": return "Custom"
        default: return title
        }
    }

    private var japaneseTitle: String {
        switch id {
        case "chatgpt-oauth": return "OpenAIログイン (Codex)"
        case "claude-oauth": return "Claudeログイン"
        case "gemini-oauth": return "Geminiログイン"
        case "local-openai": return "ローカルOpenAI互換"
        case "gemini": return "Gemini APIキー"
        case "claude": return "Claude APIキー"
        case "custom": return "カスタム"
        default: return title
        }
    }

    private var chineseTitle: String {
        switch id {
        case "chatgpt-oauth": return "OpenAI 登录 (Codex)"
        case "claude-oauth": return "Claude 登录"
        case "gemini-oauth": return "Gemini 登录"
        case "local-openai": return "本地 OpenAI 兼容"
        case "gemini": return "Gemini API Key"
        case "claude": return "Claude API Key"
        case "custom": return "自定义"
        default: return title
        }
    }

    private var englishNote: String {
        switch id {
        case "chatgpt-oauth": return "Uses your Codex CLI login session. Run `codex login` first."
        case "claude-oauth": return "Uses your Claude CLI login session."
        case "gemini-oauth": return "Uses your Gemini CLI Google login session."
        case "ollama": return "Connects to a local Ollama server."
        case "local-openai": return "Connects to local servers such as LM Studio, llama.cpp, or vLLM."
        case "gemini": return "Uses a Google AI Studio API key."
        case "claude": return "Uses an Anthropic API key."
        case "custom": return "Enter an OpenAI-compatible endpoint manually."
        default: return note
        }
    }

    private var japaneseNote: String {
        switch id {
        case "chatgpt-oauth": return "Codex CLIのログインセッションを使います。先に`codex login`が必要です。"
        case "claude-oauth": return "Claude CLIのログインセッションを使います。"
        case "gemini-oauth": return "Gemini CLIのGoogleログインセッションを使います。"
        case "ollama": return "ローカルOllamaサーバーに接続します。"
        case "local-openai": return "LM Studio、llama.cpp、vLLMなどのローカルサーバーに接続します。"
        case "gemini": return "Google AI StudioのAPIキーを使います。"
        case "claude": return "Anthropic APIキーを使います。"
        case "custom": return "OpenAI互換エンドポイントを手動で入力します。"
        default: return note
        }
    }

    private var chineseNote: String {
        switch id {
        case "chatgpt-oauth": return "使用 Codex CLI 登录会话。请先运行 `codex login`。"
        case "claude-oauth": return "使用 Claude CLI 登录会话。"
        case "gemini-oauth": return "使用 Gemini CLI Google 登录会话。"
        case "ollama": return "连接本地 Ollama 服务器。"
        case "local-openai": return "连接 LM Studio、llama.cpp、vLLM 等本地服务器。"
        case "gemini": return "使用 Google AI Studio API Key。"
        case "claude": return "使用 Anthropic API Key。"
        case "custom": return "手动输入 OpenAI 兼容端点。"
        default: return note
        }
    }
}
