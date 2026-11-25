using System.Globalization;
using System.Text.RegularExpressions;

namespace OpenNeko.Core;

public sealed record AgentProcessDefinition(string Id, string Label, IReadOnlyList<string> Patterns);

public sealed record AgentProcessActivity(string Source, string Label, double Cpu);

/// <summary>One sampled process on Windows. CPU is percent of one core, like `ps -o pcpu`.</summary>
public sealed record ProcessSample(string Name, string? CommandLine, double Cpu);

/// <summary>
/// Detects local AI agent activity. Mirrors AgentProcessDetector.swift: the same
/// pattern table and thresholds, fed either by `ps` output or by Windows process
/// samples normalized into the same "/"-separated, extension-less form.
/// </summary>
public static class AgentProcessDetector
{
    public const double BusyCpuThreshold = 2.0;
    public static readonly IReadOnlySet<string> PassiveActivitySources = new HashSet<string> { "codex-app" };

    public static readonly IReadOnlyList<AgentProcessDefinition> DefaultDefinitions = new[]
    {
        new AgentProcessDefinition("cursor", "Cursor", new[] { @"(^|/)(Cursor|cursor)(\.app|\s|$)", "Cursor Helper", "cursor-agent" }),
        new AgentProcessDefinition("claude", "Claude", new[] { @"(^|/)claude(\s|$|-)", "@anthropic-ai/claude-code", "claude-code" }),
        new AgentProcessDefinition("codex-cli", "Codex CLI", new[] { @"(^|/)codex(\s|$|-)", "@openai/codex", "codex-cli" }),
        new AgentProcessDefinition("codex-app-agent", "Codex App", new[] { @"(^|/)Codex\.app/Contents/Resources/codex app-server(\s|$)" }),
        new AgentProcessDefinition("codex-app", "Codex App", new[] { @"(^|/)Codex\.app/Contents/MacOS/Codex(\s|$)", "Codex Helper" }),
        new AgentProcessDefinition("antigravity", "Antigravity", new[] { @"(^|/)Antigravity(\.app|\s|$)", "antigravity" }),
        new AgentProcessDefinition("gemini", "Gemini", new[] { @"(^|/)gemini(\s|$|-)", "@google/gemini-cli", "gemini-cli" }),
        new AgentProcessDefinition("kiro", "Kiro", new[] { @"(^|/)kiro(\s|$)", @"Kiro\.app", "Kiro Helper" }),
    };

    public static IReadOnlyList<AgentProcessActivity> Detect(string psOutput, IReadOnlyList<AgentProcessDefinition>? definitions = null)
    {
        var samples = new List<(double Cpu, string Command)>();
        foreach (var line in psOutput.Split('\n'))
        {
            var match = Regex.Match(line, @"^\s*([0-9]+(?:\.[0-9]+)?)\s+(.+)$");
            if (!match.Success) continue;
            if (!double.TryParse(match.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out var cpu)) continue;
            samples.Add((cpu, match.Groups[2].Value));
        }
        return Detect(samples, definitions ?? DefaultDefinitions);
    }

    public static IReadOnlyList<AgentProcessActivity> Detect(IEnumerable<ProcessSample> samples, IReadOnlyList<AgentProcessDefinition>? definitions = null) =>
        Detect(samples.Select(s => (s.Cpu, NormalizeWindowsCommand(s.Name, s.CommandLine))), definitions ?? DefaultDefinitions);

    /// <summary>
    /// Turns a Windows process into a ps-like command: backslashes become "/", and the
    /// executable's ".exe" is dropped, so `C:\x\claude.exe -p` reads as `C:/x/claude -p`.
    /// </summary>
    public static string NormalizeWindowsCommand(string name, string? commandLine)
    {
        var line = string.IsNullOrWhiteSpace(commandLine) ? name : commandLine.Trim();
        string executable, rest;
        if (line.StartsWith('"'))
        {
            var close = line.IndexOf('"', 1);
            executable = close < 0 ? line[1..] : line[1..close];
            rest = close < 0 ? "" : line[(close + 1)..].TrimStart();
        }
        else
        {
            var space = line.IndexOf(' ');
            executable = space < 0 ? line : line[..space];
            rest = space < 0 ? "" : line[(space + 1)..].TrimStart();
        }
        if (executable.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) executable = executable[..^4];
        var normalized = rest.Length == 0 ? executable : executable + " " + rest;
        return normalized.Replace('\\', '/');
    }

    public static AgentProcessActivity? TopBusyActivity(IEnumerable<AgentProcessActivity> activities, double threshold = BusyCpuThreshold) =>
        activities.FirstOrDefault(a => !PassiveActivitySources.Contains(a.Source) && a.Cpu >= threshold);

    /// <summary>CPU percent of one core from two cumulative processor-time samples.</summary>
    public static double CpuPercent(TimeSpan previousProcessorTime, TimeSpan currentProcessorTime, TimeSpan elapsed)
    {
        if (elapsed <= TimeSpan.Zero || currentProcessorTime < previousProcessorTime) return 0;
        return (currentProcessorTime - previousProcessorTime).TotalMilliseconds / elapsed.TotalMilliseconds * 100.0;
    }

    private static IReadOnlyList<AgentProcessActivity> Detect(IEnumerable<(double Cpu, string Command)> samples, IReadOnlyList<AgentProcessDefinition> definitions)
    {
        var maxCpu = new Dictionary<string, double>();
        var labels = new Dictionary<string, string>();
        foreach (var (cpu, command) in samples)
        {
            if (IsKnownPassiveProcess(command)) continue;
            foreach (var def in definitions)
            {
                if (!def.Patterns.Any(p => Regex.IsMatch(command, p))) continue;
                maxCpu[def.Id] = Math.Max(maxCpu.GetValueOrDefault(def.Id), cpu);
                labels[def.Id] = def.Label;
            }
        }
        return maxCpu
            .Select(kv => new AgentProcessActivity(kv.Key, labels.GetValueOrDefault(kv.Key, kv.Key), kv.Value))
            .OrderByDescending(a => a.Cpu)
            .ThenBy(a => a.Label, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    private static bool IsKnownPassiveProcess(string command)
    {
        if (command.Contains("/Codex.app/Contents/Frameworks/") &&
            (command.Contains("--type=gpu-process") || command.Contains("--type=renderer") ||
             command.Contains("browser_crashpad_handler") || command.Contains("Codex (Service).app")))
            return true;
        if (command.Contains("CodexBarClaudeWatchdog")) return true;
        // Windows: the Claude desktop app ships as claude.exe under AnthropicClaude; it is a chat app, not an agent run.
        if (command.Contains("/AnthropicClaude/", StringComparison.OrdinalIgnoreCase)) return true;
        if (Regex.IsMatch(command, @"(^|/)claude(\s|$|-)"))
        {
            var oneShot = command.Contains(" -p ") || command.Contains(" --print ");
            if (command.Contains(" --resume ") || command.Contains(" --session-id ") || command.Contains(" --settings ") ||
                (command.Contains(" --allowed-tools") && !oneShot))
                return true;
        }
        return false;
    }
}
