namespace OpenNeko.Core;

public enum AIProviderType { CodexCli, ClaudeCli, GeminiCli, OpenAICompatible, Gemini, Anthropic }

public enum AIProviderField { BaseUrl, ApiKey, Model }

public static class AIProviderTypeExtensions
{
    public static string RawValue(this AIProviderType type) => type switch
    {
        AIProviderType.CodexCli => "codex-cli",
        AIProviderType.ClaudeCli => "claude-cli",
        AIProviderType.GeminiCli => "gemini-cli",
        AIProviderType.OpenAICompatible => "openai-compat",
        AIProviderType.Gemini => "gemini",
        AIProviderType.Anthropic => "anthropic",
        _ => "codex-cli",
    };

    public static AIProviderType? FromRawValue(string? raw) => raw switch
    {
        "codex-cli" => AIProviderType.CodexCli,
        "claude-cli" => AIProviderType.ClaudeCli,
        "gemini-cli" => AIProviderType.GeminiCli,
        "openai-compat" => AIProviderType.OpenAICompatible,
        "gemini" => AIProviderType.Gemini,
        "anthropic" => AIProviderType.Anthropic,
        _ => null,
    };

    /// <summary>Executable of the login CLI backing this provider, or null for HTTP providers.</summary>
    public static string? CliExecutableName(this AIProviderType type) => type switch
    {
        AIProviderType.CodexCli => "codex",
        AIProviderType.ClaudeCli => "claude",
        AIProviderType.GeminiCli => "gemini",
        _ => null,
    };

    public static bool IsHttp(this AIProviderType type) => type.CliExecutableName() is null;
}

public sealed record AIProviderConfig(string PresetId = "", AIProviderType Type = AIProviderType.CodexCli, string BaseUrl = "", string Model = "");

/// <summary>Provider preset catalog. Mirrors AIProviderPreset.swift.</summary>
public sealed record AIProviderPreset(
    string Id,
    AIProviderType Type,
    IReadOnlyList<AIProviderField> Fields,
    string DefaultBaseUrl = "",
    string DefaultModel = "",
    bool IsRecommended = false,
    bool IsLocal = false,
    bool RequiresApiKey = false,
    string? EnvironmentKey = null,
    string? AlternateEnvironmentKey = null)
{
    public const string DefaultId = "chatgpt-oauth";

    public static readonly IReadOnlyList<AIProviderPreset> All = new[]
    {
        new AIProviderPreset("chatgpt-oauth", AIProviderType.CodexCli, new[] { AIProviderField.Model }, IsRecommended: true),
        new AIProviderPreset("claude-oauth", AIProviderType.ClaudeCli, new[] { AIProviderField.Model }),
        new AIProviderPreset("gemini-oauth", AIProviderType.GeminiCli, new[] { AIProviderField.Model }),
        new AIProviderPreset("ollama", AIProviderType.OpenAICompatible, new[] { AIProviderField.BaseUrl, AIProviderField.Model }, DefaultBaseUrl: "http://localhost:11434/v1", IsLocal: true),
        new AIProviderPreset("local-openai", AIProviderType.OpenAICompatible, new[] { AIProviderField.BaseUrl, AIProviderField.Model }, DefaultBaseUrl: "http://localhost:1234/v1", IsLocal: true),
        new AIProviderPreset("gemini", AIProviderType.Gemini, new[] { AIProviderField.ApiKey, AIProviderField.Model }, DefaultModel: "gemini-3.5-flash", RequiresApiKey: true, EnvironmentKey: "GEMINI_API_KEY", AlternateEnvironmentKey: "GOOGLE_API_KEY"),
        new AIProviderPreset("claude", AIProviderType.Anthropic, new[] { AIProviderField.ApiKey, AIProviderField.Model }, DefaultBaseUrl: "https://api.anthropic.com/v1", DefaultModel: "claude-opus-4-8", RequiresApiKey: true, EnvironmentKey: "ANTHROPIC_API_KEY"),
        new AIProviderPreset("custom", AIProviderType.OpenAICompatible, new[] { AIProviderField.BaseUrl, AIProviderField.ApiKey, AIProviderField.Model }),
    };

    public static AIProviderConfig DefaultConfig => Config(DefaultId);

    public static AIProviderPreset? Preset(string id) => All.FirstOrDefault(p => p.Id == id);

    public static AIProviderConfig Config(string id, AIProviderConfig? overrides = null)
    {
        var preset = Preset(id);
        if (preset is null) return Config(DefaultId);
        overrides ??= new AIProviderConfig();
        return new AIProviderConfig(
            preset.Id,
            preset.Type,
            string.IsNullOrEmpty(overrides.BaseUrl) ? preset.DefaultBaseUrl : overrides.BaseUrl,
            string.IsNullOrEmpty(overrides.Model) ? preset.DefaultModel : overrides.Model);
    }

    public static string? ResolveApiKey(string presetId, string? savedKey, IReadOnlyDictionary<string, string?> environment)
    {
        if (!string.IsNullOrEmpty(savedKey)) return savedKey;
        var preset = Preset(presetId);
        if (preset is null) return savedKey;
        if (preset.EnvironmentKey is string k1 && environment.TryGetValue(k1, out var v1) && !string.IsNullOrEmpty(v1)) return v1;
        if (preset.AlternateEnvironmentKey is string k2 && environment.TryGetValue(k2, out var v2) && !string.IsNullOrEmpty(v2)) return v2;
        return savedKey;
    }

    public string Title(string? lang) => Id switch
    {
        "chatgpt-oauth" => AppLanguage.Pick(lang, "OpenAI 로그인 (Codex)", "OpenAI Login (Codex)", "OpenAIログイン (Codex)", "OpenAI 登录 (Codex)"),
        "claude-oauth" => AppLanguage.Pick(lang, "Claude 로그인", "Claude Login", "Claudeログイン", "Claude 登录"),
        "gemini-oauth" => AppLanguage.Pick(lang, "Gemini 로그인", "Gemini Login", "Geminiログイン", "Gemini 登录"),
        "ollama" => "Ollama",
        "local-openai" => AppLanguage.Pick(lang, "로컬 OpenAI 호환", "Local OpenAI Compatible", "ローカルOpenAI互換", "本地 OpenAI 兼容"),
        "gemini" => AppLanguage.Pick(lang, "Gemini API 키", "Gemini API Key", "Gemini APIキー", "Gemini API Key"),
        "claude" => AppLanguage.Pick(lang, "Claude API 키", "Claude API Key", "Claude APIキー", "Claude API Key"),
        "custom" => AppLanguage.Pick(lang, "사용자 지정", "Custom", "カスタム", "自定义"),
        _ => Id,
    };

    public string Note(string? lang) => Id switch
    {
        "chatgpt-oauth" => AppLanguage.Pick(lang, "Codex CLI 로그인 세션을 사용합니다. 먼저 `codex login`이 필요합니다.", "Uses your Codex CLI login session. Run `codex login` first.", "Codex CLIのログインセッションを使います。先に`codex login`が必要です。", "使用 Codex CLI 登录会话。请先运行 `codex login`。"),
        "claude-oauth" => AppLanguage.Pick(lang, "Claude CLI 로그인 세션을 사용합니다.", "Uses your Claude CLI login session.", "Claude CLIのログインセッションを使います。", "使用 Claude CLI 登录会话。"),
        "gemini-oauth" => AppLanguage.Pick(lang, "Gemini CLI Google 로그인 세션을 사용합니다.", "Uses your Gemini CLI Google login session.", "Gemini CLIのGoogleログインセッションを使います。", "使用 Gemini CLI Google 登录会话。"),
        "ollama" => AppLanguage.Pick(lang, "로컬 Ollama 서버와 연결합니다.", "Connects to a local Ollama server.", "ローカルOllamaサーバーに接続します。", "连接本地 Ollama 服务器。"),
        "local-openai" => AppLanguage.Pick(lang, "LM Studio, llama.cpp, vLLM 같은 로컬 서버와 연결합니다.", "Connects to local servers such as LM Studio, llama.cpp, or vLLM.", "LM Studio、llama.cpp、vLLMなどのローカルサーバーに接続します。", "连接 LM Studio、llama.cpp、vLLM 等本地服务器。"),
        "gemini" => AppLanguage.Pick(lang, "Google AI Studio API 키를 사용합니다.", "Uses a Google AI Studio API key.", "Google AI StudioのAPIキーを使います。", "使用 Google AI Studio API Key。"),
        "claude" => AppLanguage.Pick(lang, "Anthropic API 키를 사용합니다.", "Uses an Anthropic API key.", "Anthropic APIキーを使います。", "使用 Anthropic API Key。"),
        "custom" => AppLanguage.Pick(lang, "OpenAI 호환 엔드포인트를 직접 입력합니다.", "Enter an OpenAI-compatible endpoint manually.", "OpenAI互換エンドポイントを手動で入力します。", "手动输入 OpenAI 兼容端点。"),
        _ => "",
    };
}
