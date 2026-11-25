using System.Text;
using System.Text.Json.Nodes;
using OpenNeko.Core;

namespace OpenNeko.Core.Tests;

public class AIProviderPresetTests
{
    [Fact]
    public void CatalogMatchesMacPresets()
    {
        Assert.Equal(new[] { "chatgpt-oauth", "claude-oauth", "gemini-oauth", "ollama", "local-openai", "gemini", "claude", "custom" },
            AIProviderPreset.All.Select(p => p.Id));
        foreach (var preset in AIProviderPreset.All)
            foreach (var lang in new[] { "ko", "en", "ja", "zh" })
            {
                Assert.False(string.IsNullOrEmpty(preset.Title(lang)));
                Assert.False(string.IsNullOrEmpty(preset.Note(lang)));
            }
    }

    [Fact]
    public void UnknownPresetFallsBackToDefault() => Assert.Equal("chatgpt-oauth", AIProviderPreset.Config("nope").PresetId);

    [Fact]
    public void ApiKeyPrefersSavedThenEnvironment()
    {
        var env = new Dictionary<string, string?> { ["GOOGLE_API_KEY"] = "g2" };
        Assert.Equal("saved", AIProviderPreset.ResolveApiKey("gemini", "saved", env));
        Assert.Equal("g2", AIProviderPreset.ResolveApiKey("gemini", null, env));
        Assert.Null(AIProviderPreset.ResolveApiKey("claude", null, env));
    }

    [Fact]
    public void ProviderTypeRawValuesRoundTrip()
    {
        foreach (var type in Enum.GetValues<AIProviderType>())
            Assert.Equal(type, AIProviderTypeExtensions.FromRawValue(type.RawValue()));
        Assert.Equal("claude", AIProviderType.ClaudeCli.CliExecutableName());
        Assert.True(AIProviderType.Anthropic.IsHttp());
    }
}

public class HttpChatTests
{
    private static readonly ChatMessage[] Hello = { new(ChatRole.User, "안녕") };

    private static JsonObject Body(HttpChatRequest r) => (JsonObject)JsonNode.Parse(r.Body!)!;

    [Fact]
    public void OpenAICompatibleUsesChatCompletions()
    {
        var request = HttpChatRequestBuilder.Build(AIProviderPreset.Config("custom", new AIProviderConfig(BaseUrl: "http://localhost:1234/v1/", Model: "local-model")), "secret", Hello, "짧게");
        Assert.Equal("http://localhost:1234/v1/chat/completions", request.Url.ToString());
        Assert.Equal("Bearer secret", request.Headers["Authorization"]);
        var body = Body(request);
        Assert.Equal("local-model", (string)body["model"]!);
        Assert.Equal("system", (string)body["messages"]![0]!["role"]!);
        Assert.Equal("안녕", (string)body["messages"]![1]!["content"]!);
    }

    [Fact]
    public void StreamingRequestsSse()
    {
        var request = HttpChatRequestBuilder.Build(AIProviderPreset.Config("custom"), null, Hello, null, stream: true);
        Assert.Equal("text/event-stream", request.Headers["Accept"]);
        Assert.True((bool)Body(request)["stream"]!);
        Assert.False(request.Headers.ContainsKey("Authorization"));
        Assert.Equal("https://api.openai.com/v1/chat/completions", request.Url.ToString());
    }

    [Fact]
    public void GeminiUsesGenerateContentWithKeyQuery()
    {
        var request = HttpChatRequestBuilder.Build(AIProviderPreset.Config("gemini"), "gemini-key", Hello, "간단히");
        Assert.Equal("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=gemini-key", request.Url.ToString());
        var body = Body(request);
        Assert.Equal("간단히", (string)body["systemInstruction"]!["parts"]![0]!["text"]!);
        Assert.Equal("user", (string)body["contents"]![0]!["role"]!);
    }

    [Fact]
    public void AnthropicUsesMessagesApi()
    {
        var request = HttpChatRequestBuilder.Build(AIProviderPreset.Config("claude"), "ak", Hello, "sys");
        Assert.Equal("https://api.anthropic.com/v1/messages", request.Url.ToString());
        Assert.Equal("ak", request.Headers["x-api-key"]);
        Assert.Equal("2023-06-01", request.Headers["anthropic-version"]);
        var body = Body(request);
        Assert.Equal(1024, (int)body["max_tokens"]!);
        Assert.Equal("claude-opus-4-8", (string)body["model"]!);
        Assert.Equal("sys", (string)body["system"]!);
    }

    [Fact]
    public void BodyKeysAreSorted()
    {
        var request = HttpChatRequestBuilder.Build(AIProviderPreset.Config("claude"), "ak", Hello, "sys");
        Assert.StartsWith("{\"max_tokens\":1024,\"messages\":[{\"content\":", Encoding.UTF8.GetString(request.Body!));
    }

    [Fact]
    public void KeepsOnlyRecentTurns()
    {
        var history = Enumerable.Range(0, 10).Select(i => new ChatMessage(i % 2 == 0 ? ChatRole.User : ChatRole.Assistant, $"m{i}")).ToList();
        var body = Body(HttpChatRequestBuilder.Build(AIProviderPreset.Config("claude"), "ak", history, null));
        Assert.Equal(6, ((JsonArray)body["messages"]!).Count);
        Assert.Equal("m4", (string)body["messages"]![0]!["content"]!);
    }

    [Theory]
    [InlineData("gemini", "missingAPIKey")]
    [InlineData("claude", "missingAPIKey")]
    [InlineData("chatgpt-oauth", "unsupportedProvider")]
    public void ConfigurationErrors(string preset, string kind) =>
        Assert.Equal(kind, Assert.Throws<HttpChatConfigurationException>(() => HttpChatRequestBuilder.Build(AIProviderPreset.Config(preset), null, Hello, null)).Kind);

    [Fact]
    public void InvalidBaseUrl() =>
        Assert.Equal("invalidBaseURL", Assert.Throws<HttpChatConfigurationException>(() =>
            HttpChatRequestBuilder.Build(new AIProviderConfig("custom", AIProviderType.OpenAICompatible, "not a url"), null, Hello, null)).Kind);

    [Fact]
    public void ParsesResponses()
    {
        Assert.Equal("hi", HttpChatResponseParser.Parse("{\"choices\":[{\"message\":{\"content\":\" hi \"}}]}"u8.ToArray(), AIProviderType.OpenAICompatible));
        Assert.Equal("ab", HttpChatResponseParser.Parse("{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"a\"},{\"text\":\"b\"}]}}]}"u8.ToArray(), AIProviderType.Gemini));
        Assert.Equal("yo", HttpChatResponseParser.Parse("{\"content\":[{\"type\":\"text\",\"text\":\"yo\"}]}"u8.ToArray(), AIProviderType.Anthropic));
        Assert.Throws<HttpChatConfigurationException>(() => HttpChatResponseParser.Parse("{}"u8.ToArray(), AIProviderType.OpenAICompatible));
    }

    [Fact]
    public void ParsesSseLines()
    {
        Assert.Equal(new HttpChatStreamEvent("Hel", false), HttpChatStreamParser.ParseOpenAIEventLine("data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}"));
        Assert.Equal(new HttpChatStreamEvent("", true), HttpChatStreamParser.ParseOpenAIEventLine("data: [DONE]"));
        Assert.Null(HttpChatStreamParser.ParseOpenAIEventLine(": keepalive"));
        Assert.Null(HttpChatStreamParser.ParseOpenAIEventLine("data: {\"choices\":[{\"delta\":{}}]}"));
    }

    [Fact]
    public void ClassifiesAndRedactsErrors()
    {
        Assert.Equal(HttpChatErrorKind.Auth, HttpChatErrors.Classify(401, "").Kind);
        Assert.Equal(HttpChatErrorKind.NotFound, HttpChatErrors.Classify(404, "").Kind);
        var (kind, snippet) = HttpChatErrors.Classify(500, "Authorization: Bearer sk-abcdefgh123 key=AIzaSyXXXXXXXX");
        Assert.Equal(HttpChatErrorKind.Http, kind);
        Assert.DoesNotContain("sk-abcdefgh123", snippet);
        Assert.DoesNotContain("AIzaSyXXXXXXXX", snippet);
    }
}

public class ChatPromptBuilderTests
{
    [Fact]
    public void SingleTurnIsJustTheText() =>
        Assert.Equal("hi", ChatPromptBuilder.FormatPrompt(new[] { new ChatMessage(ChatRole.User, "hi") }));

    [Fact]
    public void MultiTurnUsesLocalizedLabels()
    {
        var history = new[] { new ChatMessage(ChatRole.User, "a"), new ChatMessage(ChatRole.Assistant, "b"), new ChatMessage(ChatRole.User, "c") };
        Assert.Equal("이전 대화:\n나: a\n너: b\n\n지금 질문: c", ChatPromptBuilder.FormatPrompt(history, "ko"));
        Assert.Equal("Previous conversation:\nUser: a\nopenNeko: b\n\nCurrent question: c", ChatPromptBuilder.FormatPrompt(history, "en"));
    }

    [Fact]
    public void SystemPromptIncludesProfileAndSkill()
    {
        var skill = new NekoSkill("explain", "Explain", "Simply", NekoSkillInput.Prompt, "BODY", NekoSkillSource.Bundled);
        var text = ChatPromptBuilder.SystemPrompt(skill, "en", new UserProfile("Kim", "1990-01-01", "07:30", "lunar"), new DateTime(2026, 11, 25));
        Assert.Contains("Today: 2026-11-25 (Wednesday)", text);
        Assert.Contains("User birth date: 1990-01-01 (lunar), birth time: 07:30", text);
        Assert.Contains("User name: Kim", text);
        Assert.Contains("<skill_instructions>\nBODY\n</skill_instructions>", text);
        Assert.Contains("오늘 날짜: 2026-11-25 (수요일)", ChatPromptBuilder.SystemPrompt(null, "ko", UserProfile.Empty, new DateTime(2026, 11, 25)));
    }

    [Fact]
    public void CliArgumentListsMatchMac()
    {
        Assert.Equal(new[] { "--model", "m", "--prompt", "p", "--output-format", "text", "--approval-mode", "plan", "--skip-trust" },
            ChatPromptBuilder.GeminiPromptArguments("m", "p"));
        var claude = ChatPromptBuilder.ClaudePrintArguments("", "p", "s");
        Assert.Equal("--safe-mode", claude[0]);
        Assert.Equal(new[] { "--system-prompt", "s", "-p", "p" }, claude.TakeLast(4));
        Assert.Contains("--output-last-message", ChatPromptBuilder.CodexExecArguments("", "C:\\w", "C:\\o.txt", "-"));
        Assert.Null(ChatPromptBuilder.CatNameContext("  "));
        Assert.Equal("Cat name: Mochi", ChatPromptBuilder.CatNameContext(" Mochi ", "en"));
    }
}

public class CliChatTests
{
    private static readonly ChatMessage[] History = { new(ChatRole.User, "line1\nline2") };

    [Fact]
    public void PromptAlwaysGoesThroughStdin()
    {
        foreach (var kind in Enum.GetValues<CliKind>())
        {
            var plan = CliChatPlanner.Plan(kind, "", History, "SYS", "en", allowsMultilineArguments: false, @"C:\Users\me", @"C:\tmp\out.txt");
            Assert.Contains("line1\nline2", plan.StandardInput);
            Assert.All(plan.Arguments, a => Assert.DoesNotContain("\n", a));
            Assert.All(plan.Arguments, a => WindowsCommandLine.QuoteForCmd(a)); // all cmd-safe
        }
    }

    [Fact]
    public void ClaudeKeepsSystemArgumentForNativeExe()
    {
        var plan = CliChatPlanner.Plan(CliKind.Claude, "sonnet", History, "SYS", "en", true, "w", "o");
        Assert.Equal(new[] { "--model", "sonnet" }, plan.Arguments.Take(2));
        Assert.Equal("-p", plan.Arguments[^1]);
        Assert.Contains("--system-prompt", plan.Arguments);
        Assert.DoesNotContain("<system>", plan.StandardInput);

        var shim = CliChatPlanner.Plan(CliKind.Claude, "", History, "SYS", "en", false, "w", "o");
        Assert.DoesNotContain("--system-prompt", shim.Arguments);
        Assert.StartsWith("<system>\nSYS", shim.StandardInput);
    }

    [Fact]
    public void CodexReadsPromptFromDashAndWritesOutputFile()
    {
        var plan = CliChatPlanner.Plan(CliKind.Codex, "", History, null, "ko", false, "w", "out.txt");
        Assert.Equal("-", plan.Arguments[^1]);
        Assert.Equal("out.txt", plan.OutputFile);
        Assert.Contains("<system>", plan.StandardInput);
    }

    [Fact]
    public void GeminiDropsPromptFlag()
    {
        var plan = CliChatPlanner.Plan(CliKind.Gemini, "", History, null, "en", true, "w", "o");
        Assert.DoesNotContain("--prompt", plan.Arguments);
        Assert.Contains("--approval-mode", plan.Arguments);
    }

    [Theory]
    [InlineData("'claude' is not recognized as an internal or external command", CliFailureKind.Missing)]
    [InlineData("Error: Not logged in. Please run /login", CliFailureKind.Auth)]
    [InlineData("panic at the disco", CliFailureKind.Cli)]
    public void ClassifiesFailures(string output, CliFailureKind expected) => Assert.Equal(expected, CliChatFailure.Classify(output));

    [Fact]
    public void FailureCopyNamesTheCli()
    {
        Assert.Equal("Claude CLI is needed, nya.", CliChatFailure.UserMessage(CliFailureKind.Missing, CliKind.Claude, "en"));
        Assert.Equal("Codex 로그인이 필요하다냥", CliChatFailure.UserMessage(CliFailureKind.Auth, CliKind.Codex, "ko"));
    }
}

public class WindowsCommandLineTests
{
    private static readonly Dictionary<string, string?> Env = new()
    {
        ["Path"] = @"C:\Windows\System32;C:\tools",
        ["PATHEXT"] = ".COM;.EXE;.BAT;.CMD;.VBS;.PS1",
        ["APPDATA"] = @"C:\Users\me\AppData\Roaming",
        ["USERPROFILE"] = @"C:\Users\me",
    };

    [Fact]
    public void SearchesPathThenNpmAndNativeInstallFolders()
    {
        var dirs = WindowsCommandLine.SearchDirectories(Env);
        Assert.Equal(@"C:\Windows\System32", dirs[0]);
        Assert.Contains(Path.Combine(@"C:\Users\me\AppData\Roaming", "npm"), dirs);
        Assert.Contains(Path.Combine(@"C:\Users\me", ".local", "bin"), dirs);
        Assert.DoesNotContain(".PS1", WindowsCommandLine.Extensions(Env));
    }

    [Fact]
    public void PrefersExeOverCmdInTheSameFolder()
    {
        var npm = Path.Combine(@"C:\Users\me\AppData\Roaming", "npm");
        var files = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { Path.Combine(npm, "codex.cmd"), Path.Combine(npm, "codex.exe") };
        Assert.Equal(Path.Combine(npm, "codex.exe"), WindowsCommandLine.Resolve("codex", Env, files.Contains));
        files.Remove(Path.Combine(npm, "codex.exe"));
        Assert.Equal(Path.Combine(npm, "codex.cmd"), WindowsCommandLine.Resolve("codex", Env, files.Contains));
        Assert.Null(WindowsCommandLine.Resolve("gemini", Env, files.Contains));
    }

    [Fact]
    public void WrapsCmdShimsInCmdExe()
    {
        var direct = WindowsCommandLine.Launch(@"C:\bin\claude.exe", new[] { "-p" }, "cmd.exe");
        Assert.False(direct.UsesCmdShim);
        Assert.Equal(new[] { "-p" }, direct.ArgumentList);

        var shim = WindowsCommandLine.Launch(@"C:\Program Files\npm\claude.cmd", new[] { "--tools", "", "-p" }, @"C:\Windows\System32\cmd.exe");
        Assert.True(shim.UsesCmdShim);
        Assert.Equal(@"/d /s /c """"C:\Program Files\npm\claude.cmd"" ""--tools"" """" ""-p""""", shim.RawArguments);
    }

    [Theory]
    [InlineData("a\"b")]
    [InlineData("50%")]
    [InlineData("x\ny")]
    public void RejectsArgumentsCmdCannotCarry(string arg) => Assert.Throws<ArgumentException>(() => WindowsCommandLine.QuoteForCmd(arg));

    [Fact]
    public void QuotesTrailingBackslashes() => Assert.Equal("\"C:\\dir\\\\\"", WindowsCommandLine.QuoteForCmd("C:\\dir\\"));
}

public class ChatTranscriptStoreTests
{
    [Fact]
    public void RoundTripsMarkdown()
    {
        var messages = new[] { new ChatMessage(ChatRole.User, "hello\n\nworld"), new ChatMessage(ChatRole.Assistant, "### not a title\nnya") };
        var md = ChatTranscriptStore.Markdown(messages, new DateTimeOffset(2026, 11, 25, 1, 2, 3, TimeSpan.Zero));
        Assert.Contains("Last updated: 2026-11-25T01:02:03Z", md);
        Assert.Equal(messages, ChatTranscriptStore.ParseMarkdown(md.Replace("\n", "\r\n")));
    }

    [Fact]
    public void SaveEmptyDeletesFile()
    {
        var path = Path.Combine(Path.GetTempPath(), $"neko-{Guid.NewGuid()}", "chat-history.md");
        var store = new ChatTranscriptStore(path);
        store.Save(new[] { new ChatMessage(ChatRole.User, "hi") });
        Assert.Single(store.Load());
        store.Save(Array.Empty<ChatMessage>());
        Assert.False(File.Exists(path));
        Directory.Delete(Path.GetDirectoryName(path)!);
    }
}
