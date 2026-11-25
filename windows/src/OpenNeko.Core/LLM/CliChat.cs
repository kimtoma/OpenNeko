using System.Text;
using System.Text.RegularExpressions;

namespace OpenNeko.Core;

public enum CliKind { Codex, Claude, Gemini }

public static class CliKindExtensions
{
    public static string ExecutableName(this CliKind kind) => kind switch
    {
        CliKind.Codex => "codex",
        CliKind.Claude => "claude",
        _ => "gemini",
    };

    public static string DisplayName(this CliKind kind) => kind switch
    {
        CliKind.Codex => "Codex",
        CliKind.Claude => "Claude",
        _ => "Gemini",
    };

    public static CliKind? FromProvider(AIProviderType type) => type switch
    {
        AIProviderType.CodexCli => CliKind.Codex,
        AIProviderType.ClaudeCli => CliKind.Claude,
        AIProviderType.GeminiCli => CliKind.Gemini,
        _ => null,
    };
}

/// <summary>What to run for one chat turn: argv plus text written to stdin.</summary>
public sealed record CliChatPlan(IReadOnlyList<string> Arguments, string StandardInput, string? OutputFile);

/// <summary>
/// Builds CLI chat invocations for Windows. Unlike macOS, the prompt always goes
/// through stdin: npm installs these CLIs as .cmd shims, and cmd.exe cannot carry
/// multi-line arguments. Flags mirror ChatPromptBuilder's macOS argument lists.
/// </summary>
public static class CliChatPlanner
{
    public static CliChatPlan Plan(CliKind kind, string model, IReadOnlyList<ChatMessage> history, string? system, string languageCode,
        bool allowsMultilineArguments, string workingDirectory, string outputFile)
    {
        switch (kind)
        {
            case CliKind.Codex:
            {
                var prompt = ChatPromptBuilder.CodexPrompt(history, system, languageCode);
                var args = ChatPromptBuilder.CodexExecArguments(model, workingDirectory, outputFile, "-");
                return new CliChatPlan(args, prompt, outputFile);
            }
            case CliKind.Claude:
            {
                var prompt = ChatPromptBuilder.FormatPrompt(history, languageCode);
                var claudeSystem = ChatPromptBuilder.ClaudeSystemPrompt(system, languageCode);
                var args = ChatPromptBuilder.ClaudePrintArguments(model, "", claudeSystem);
                args.RemoveAt(args.Count - 1); // drop the empty argv prompt; "-p" reads stdin
                if (allowsMultilineArguments) return new CliChatPlan(args, prompt, null);
                var index = args.IndexOf("--system-prompt");
                args.RemoveRange(index, 2);
                return new CliChatPlan(args, $"<system>\n{claudeSystem}\n</system>\n\n{prompt}", null);
            }
            default:
            {
                var prompt = ChatPromptBuilder.GeminiInlinePrompt(history, system, languageCode);
                var args = ChatPromptBuilder.GeminiPromptArguments(model, "");
                var index = args.IndexOf("--prompt");
                args.RemoveRange(index, 2); // piped stdin runs gemini non-interactively
                return new CliChatPlan(args, prompt, null);
            }
        }
    }
}

public enum CliFailureKind { Timeout, Missing, Auth, Empty, Cli }

/// <summary>Failure classification and user copy for CLI providers. Mirrors AgentCLIChatProvider/CodexChatProvider.</summary>
public static class CliChatFailure
{
    public static CliFailureKind Classify(string output)
    {
        var redacted = HttpChatErrors.Redact(output);
        if (Regex.IsMatch(redacted, @"No such file or directory|not found|env: .*: No such|is not recognized as an internal or external command|cannot find the path", RegexOptions.IgnoreCase))
            return CliFailureKind.Missing;
        if (Regex.IsMatch(redacted, @"not logged in|login|auth|unauthorized|forbidden|api key|oauth|credentials", RegexOptions.IgnoreCase))
            return CliFailureKind.Auth;
        return CliFailureKind.Cli;
    }

    public static string UserMessage(CliFailureKind failure, CliKind kind, string? lang)
    {
        var name = kind.DisplayName();
        return failure switch
        {
            CliFailureKind.Timeout => AppLanguage.Pick(lang, "응답 시간이 초과됐다냥", "The response timed out, nya.", "返事がタイムアウトしたにゃ", "响应超时了喵"),
            CliFailureKind.Missing => AppLanguage.Pick(lang, $"{name} CLI 설치가 필요하다냥", $"{name} CLI is needed, nya.", $"{name} CLI が必要にゃ", $"需要 {name} CLI 喵"),
            CliFailureKind.Auth => AppLanguage.Pick(lang, $"{name} 로그인이 필요하다냥", $"{name} login is needed, nya.", $"{name} ログインが必要にゃ", $"需要 {name} 登录喵"),
            CliFailureKind.Empty => AppLanguage.Pick(lang, "빈 응답이 왔다냥", "The response was empty, nya.", "空の返事だったにゃ", "返回了空响应喵"),
            _ => AppLanguage.Pick(lang, "답변을 만들지 못했다냥", "I could not make an answer, nya.", "返事を作れなかったにゃ", "没能生成回答喵"),
        };
    }
}

/// <summary>A resolved process launch: either direct argv or a raw cmd.exe command line.</summary>
public sealed record ProcessLaunch(string FileName, IReadOnlyList<string>? ArgumentList, string? RawArguments)
{
    public bool UsesCmdShim => RawArguments is not null;
}

/// <summary>
/// Finds CLIs on Windows (PATH + PATHEXT + the usual npm / native install folders,
/// like ProcessPathEnvironment does for terminal defaults on macOS) and wraps
/// .cmd/.bat shims in cmd.exe safely.
/// </summary>
public static class WindowsCommandLine
{
    public static IReadOnlyList<string> SearchDirectories(IReadOnlyDictionary<string, string?> env)
    {
        var dirs = new List<string>();
        void Add(string? dir)
        {
            if (string.IsNullOrWhiteSpace(dir)) return;
            var trimmed = dir.Trim().Trim('"');
            if (!dirs.Contains(trimmed, StringComparer.OrdinalIgnoreCase)) dirs.Add(trimmed);
        }
        foreach (var dir in (Get(env, "PATH") ?? "").Split(';')) Add(dir);
        var appData = Get(env, "APPDATA");
        var localAppData = Get(env, "LOCALAPPDATA");
        var home = Get(env, "USERPROFILE");
        if (appData is not null) Add(Path.Combine(appData, "npm"));
        if (home is not null)
        {
            Add(Path.Combine(home, ".local", "bin"));
            Add(Path.Combine(home, "scoop", "shims"));
            Add(Path.Combine(home, ".bun", "bin"));
        }
        if (localAppData is not null)
        {
            Add(Path.Combine(localAppData, "Programs", "nodejs"));
            Add(Path.Combine(localAppData, "pnpm"));
        }
        if (Get(env, "ProgramFiles") is string programFiles) Add(Path.Combine(programFiles, "nodejs"));
        return dirs;
    }

    public static IReadOnlyList<string> Extensions(IReadOnlyDictionary<string, string?> env)
    {
        var raw = Get(env, "PATHEXT");
        var exts = string.IsNullOrWhiteSpace(raw) ? new[] { ".COM", ".EXE", ".BAT", ".CMD" } : raw.Split(';', StringSplitOptions.RemoveEmptyEntries);
        // Only launchable types we know how to start; PowerShell scripts etc. are skipped.
        return exts.Where(e => e.Equals(".COM", StringComparison.OrdinalIgnoreCase) || e.Equals(".EXE", StringComparison.OrdinalIgnoreCase) ||
                               e.Equals(".BAT", StringComparison.OrdinalIgnoreCase) || e.Equals(".CMD", StringComparison.OrdinalIgnoreCase)).ToList();
    }

    public static string? Resolve(string executable, IReadOnlyDictionary<string, string?> env, Func<string, bool> fileExists)
    {
        foreach (var dir in SearchDirectories(env))
        {
            foreach (var ext in Extensions(env))
            {
                var candidate = Path.Combine(dir, executable + ext.ToLowerInvariant());
                if (fileExists(candidate)) return candidate;
            }
        }
        return null;
    }

    public static bool IsCmdShim(string path) =>
        path.EndsWith(".cmd", StringComparison.OrdinalIgnoreCase) || path.EndsWith(".bat", StringComparison.OrdinalIgnoreCase);

    public static ProcessLaunch Launch(string resolvedPath, IReadOnlyList<string> arguments, string comSpec)
    {
        if (!IsCmdShim(resolvedPath)) return new ProcessLaunch(resolvedPath, arguments, null);
        var line = new StringBuilder();
        line.Append(QuoteForCmd(resolvedPath));
        foreach (var arg in arguments) line.Append(' ').Append(QuoteForCmd(arg));
        // /s strips exactly the outer quotes, keeping the inner quoting intact.
        return new ProcessLaunch(comSpec, null, $"/d /s /c \"{line}\"");
    }

    /// <summary>Quotes one argument for a cmd.exe command line. Rejects characters cmd cannot carry safely.</summary>
    public static string QuoteForCmd(string arg)
    {
        if (arg.IndexOfAny(new[] { '"', '\r', '\n', '%', '!' }) >= 0)
            throw new ArgumentException("Argument cannot be passed through cmd.exe safely.", nameof(arg));
        var trailing = arg.Length - arg.TrimEnd('\\').Length;
        return "\"" + arg + new string('\\', trailing) + "\"";
    }

    private static string? Get(IReadOnlyDictionary<string, string?> env, string key)
    {
        foreach (var (k, v) in env)
        {
            if (string.Equals(k, key, StringComparison.OrdinalIgnoreCase)) return v;
        }
        return null;
    }
}
