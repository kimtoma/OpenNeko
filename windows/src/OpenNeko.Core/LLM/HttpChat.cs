using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace OpenNeko.Core;

public sealed class HttpChatConfigurationException : Exception
{
    public HttpChatConfigurationException(string kind, string detail = "") : base($"{kind}: {detail}")
    {
        Kind = kind;
    }

    /// <summary>One of: unsupportedProvider, invalidBaseURL, missingAPIKey, emptyResponse, unsupportedResponse.</summary>
    public string Kind { get; }
}

public sealed record HttpChatRequest(Uri Url, string Method, IReadOnlyDictionary<string, string> Headers, byte[]? Body);

/// <summary>Builds provider HTTP requests. Mirrors HTTPChatRequestBuilder.swift (sorted JSON keys included).</summary>
public static class HttpChatRequestBuilder
{
    private const string DefaultOpenAIBaseUrl = "https://api.openai.com/v1";
    private const string DefaultOpenAIModel = "gpt-4o-mini";
    private const int MaxTokens = 1024;

    public static HttpChatRequest Build(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string? system, bool stream = false) =>
        config.Type switch
        {
            AIProviderType.OpenAICompatible => OpenAICompatible(config, apiKey, history, system, stream),
            AIProviderType.Gemini => Gemini(config, apiKey, history, system),
            AIProviderType.Anthropic => Anthropic(config, apiKey, history, system),
            _ => throw new HttpChatConfigurationException("unsupportedProvider", config.Type.RawValue()),
        };

    private static HttpChatRequest OpenAICompatible(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string? system, bool stream)
    {
        var url = Endpoint(string.IsNullOrEmpty(config.BaseUrl) ? DefaultOpenAIBaseUrl : config.BaseUrl, "chat/completions");
        var messages = new JsonArray();
        if (!string.IsNullOrEmpty(system)) messages.Add(Message("system", system));
        foreach (var m in Recent(history)) messages.Add(Message(m.Role == ChatRole.Assistant ? "assistant" : "user", m.Text));
        var payload = new JsonObject
        {
            ["messages"] = messages,
            ["model"] = string.IsNullOrEmpty(config.Model) ? DefaultOpenAIModel : config.Model,
        };
        if (stream) payload["stream"] = true;
        var headers = JsonHeaders(stream ? "text/event-stream" : "application/json");
        if (!string.IsNullOrEmpty(apiKey)) headers["Authorization"] = $"Bearer {apiKey}";
        return new HttpChatRequest(url, "POST", headers, Json(payload));
    }

    private static HttpChatRequest Gemini(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string? system)
    {
        if (string.IsNullOrEmpty(apiKey)) throw new HttpChatConfigurationException("missingAPIKey", "Gemini API key");
        var model = string.IsNullOrEmpty(config.Model) ? "gemini-3.5-flash" : config.Model;
        var url = new Uri($"https://generativelanguage.googleapis.com/v1beta/models/{Uri.EscapeDataString(model)}:generateContent?key={Uri.EscapeDataString(apiKey)}");
        var contents = new JsonArray();
        foreach (var m in Recent(history))
        {
            contents.Add(new JsonObject
            {
                ["parts"] = new JsonArray(new JsonObject { ["text"] = m.Text }),
                ["role"] = m.Role == ChatRole.Assistant ? "model" : "user",
            });
        }
        var payload = new JsonObject { ["contents"] = contents };
        if (!string.IsNullOrEmpty(system))
            payload["systemInstruction"] = new JsonObject { ["parts"] = new JsonArray(new JsonObject { ["text"] = system }) };
        return new HttpChatRequest(url, "POST", JsonHeaders(), Json(payload));
    }

    private static HttpChatRequest Anthropic(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string? system)
    {
        if (string.IsNullOrEmpty(apiKey)) throw new HttpChatConfigurationException("missingAPIKey", "Anthropic API key");
        var url = Endpoint(string.IsNullOrEmpty(config.BaseUrl) ? "https://api.anthropic.com/v1" : config.BaseUrl, "messages");
        var messages = new JsonArray();
        foreach (var m in Recent(history))
            messages.Add(new JsonObject { ["content"] = m.Text, ["role"] = m.Role == ChatRole.Assistant ? "assistant" : "user" });
        var payload = new JsonObject
        {
            ["max_tokens"] = MaxTokens,
            ["messages"] = messages,
            ["model"] = string.IsNullOrEmpty(config.Model) ? "claude-opus-4-8" : config.Model,
        };
        if (!string.IsNullOrEmpty(system)) payload["system"] = system;
        var headers = JsonHeaders();
        headers["x-api-key"] = apiKey;
        headers["anthropic-version"] = "2023-06-01";
        return new HttpChatRequest(url, "POST", headers, Json(payload));
    }

    private static IEnumerable<ChatMessage> Recent(IReadOnlyList<ChatMessage> history) =>
        history.Skip(Math.Max(0, history.Count - ChatPromptBuilder.MaxTurns));

    private static JsonObject Message(string role, string content) => new() { ["content"] = content, ["role"] = role };

    private static Uri Endpoint(string baseUrl, string path)
    {
        var trimmed = baseUrl.Trim('/');
        if (!Uri.TryCreate($"{trimmed}/{path}", UriKind.Absolute, out var url) || (url.Scheme != "http" && url.Scheme != "https"))
            throw new HttpChatConfigurationException("invalidBaseURL", baseUrl);
        return url;
    }

    private static Dictionary<string, string> JsonHeaders(string accept = "application/json") =>
        new() { ["Content-Type"] = "application/json", ["Accept"] = accept };

    private static byte[] Json(JsonObject payload) => Encoding.UTF8.GetBytes(SortKeys(payload)!.ToJsonString());

    private static JsonNode? SortKeys(JsonNode? node)
    {
        switch (node)
        {
            case JsonObject obj:
                var sorted = new JsonObject();
                foreach (var key in obj.Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList())
                    sorted[key] = SortKeys(obj[key]?.DeepClone());
                return sorted;
            case JsonArray arr:
                return new JsonArray(arr.Select(i => SortKeys(i?.DeepClone())).ToArray());
            default:
                return node?.DeepClone();
        }
    }
}

/// <summary>Parses non-streaming provider responses. Mirrors HTTPChatResponseParser.</summary>
public static class HttpChatResponseParser
{
    public static string Parse(byte[] data, AIProviderType type)
    {
        JsonNode? root;
        try { root = JsonNode.Parse(data); }
        catch (JsonException) { throw new HttpChatConfigurationException("emptyResponse"); }
        var text = type switch
        {
            AIProviderType.OpenAICompatible => Str(root?["choices"]?[0]?["message"]?["content"]),
            AIProviderType.Gemini => JoinTexts(root?["candidates"]?[0]?["content"]?["parts"]),
            AIProviderType.Anthropic => JoinTexts(root?["content"]),
            _ => throw new HttpChatConfigurationException("unsupportedResponse", type.RawValue()),
        };
        return HttpChatStreamParser.NonEmpty(text ?? "");
    }

    private static string? JoinTexts(JsonNode? parts) =>
        parts is JsonArray array ? string.Concat(array.Select(p => Str(p?["text"]) ?? "")) : null;

    internal static string? Str(JsonNode? node)
    {
        try { return node is JsonValue v && v.TryGetValue<string>(out var s) ? s : null; }
        catch (InvalidOperationException) { return null; }
    }
}

public sealed record HttpChatStreamEvent(string Text, bool IsDone);

/// <summary>OpenAI-compatible SSE parsing. Mirrors HTTPChatStreamParser.swift.</summary>
public static class HttpChatStreamParser
{
    public static HttpChatStreamEvent? ParseOpenAIEventLine(string line)
    {
        var trimmed = line.Trim();
        if (!trimmed.StartsWith("data:", StringComparison.Ordinal)) return null;
        var payload = trimmed["data:".Length..].Trim();
        if (payload.Length == 0) return null;
        if (payload == "[DONE]") return new HttpChatStreamEvent("", true);
        var root = JsonNode.Parse(payload);
        var content = HttpChatResponseParser.Str(root?["choices"]?[0]?["delta"]?["content"]);
        return string.IsNullOrEmpty(content) ? null : new HttpChatStreamEvent(content, false);
    }

    public static string NonEmpty(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0) throw new HttpChatConfigurationException("emptyResponse");
        return trimmed;
    }
}

public enum HttpChatErrorKind { Configuration, Auth, NotFound, Connection, Http, Empty }

/// <summary>Classifies HTTP failures and redacts secrets. Mirrors HTTPChatProvider.classifyHTTP.</summary>
public static class HttpChatErrors
{
    public static (HttpChatErrorKind Kind, string Snippet) Classify(int statusCode, string body)
    {
        if (statusCode is 401 or 403) return (HttpChatErrorKind.Auth, "");
        if (statusCode == 404) return (HttpChatErrorKind.NotFound, "");
        return (HttpChatErrorKind.Http, TextUtil.Prefix(Redact(body), 240));
    }

    public static string Redact(string text)
    {
        text = Regex.Replace(text, @"Bearer\s+\S+", "Bearer ...", RegexOptions.IgnoreCase);
        text = Regex.Replace(text, @"sk-[A-Za-z0-9_-]{6,}", "sk-...");
        text = Regex.Replace(text, @"AIza[A-Za-z0-9_-]{6,}", "AIza...");
        return text;
    }

    public static string UserMessage(HttpChatErrorKind kind, string? lang) => kind switch
    {
        HttpChatErrorKind.Auth => AppLanguage.Pick(lang, "API 키나 로그인을 확인해달라냥", "Check the API key or login, nya.", "APIキーかログインを確認してにゃ", "请检查 API Key 或登录喵"),
        HttpChatErrorKind.NotFound => AppLanguage.Pick(lang, "모델이나 엔드포인트를 못 찾았다냥", "I could not find that model or endpoint, nya.", "モデルかエンドポイントが見つからないにゃ", "找不到模型或端点喵"),
        HttpChatErrorKind.Connection => AppLanguage.Pick(lang, "AI 서버에 연결하지 못했다냥", "I could not connect to the AI server, nya.", "AIサーバーに接続できないにゃ", "没能连接到 AI 服务器喵"),
        HttpChatErrorKind.Http => AppLanguage.Pick(lang, "AI 서버 응답을 처리하지 못했다냥", "I could not handle the AI server response, nya.", "AIサーバーの応答を処理できないにゃ", "没能处理 AI 服务器响应喵"),
        HttpChatErrorKind.Empty => AppLanguage.Pick(lang, "빈 응답이 왔다냥", "The response was empty, nya.", "空の返事だったにゃ", "返回了空响应喵"),
        _ => AppLanguage.Pick(lang, "AI 연결 설정을 확인해달라냥", "Check the AI connection settings, nya.", "AI接続設定を確認してにゃ", "请检查 AI 连接设置喵"),
    };

    public static string ConfigurationMessage(string configurationKind, string? lang) => configurationKind switch
    {
        "missingAPIKey" => AppLanguage.Pick(lang, "API 키를 먼저 저장해달라냥", "Save an API key first, nya.", "先にAPIキーを保存してにゃ", "请先保存 API Key 喵"),
        "invalidBaseURL" => AppLanguage.Pick(lang, "Base URL을 확인해달라냥", "Check the Base URL, nya.", "Base URLを確認してにゃ", "请检查 Base URL 喵"),
        "unsupportedProvider" => AppLanguage.Pick(lang, "이 provider는 아직 HTTP 채팅을 못 한다냥", "This provider cannot use HTTP chat yet, nya.", "このproviderはまだHTTPチャットできないにゃ", "这个 provider 还不能使用 HTTP 聊天喵"),
        _ => AppLanguage.Pick(lang, "AI 연결 설정을 확인해달라냥", "Check the AI connection settings, nya.", "AI接続設定を確認してにゃ", "请检查 AI 连接设置喵"),
    };
}
