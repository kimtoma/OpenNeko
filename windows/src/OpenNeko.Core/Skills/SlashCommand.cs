namespace OpenNeko.Core;

public enum SlashCommandKind { Builtin, App, Skill }

public sealed record SlashCommand(string Command, string Arguments);

public sealed record SlashCommandDescriptor(string Name, SlashCommandKind Kind, string Description);

/// <summary>Mirrors SlashCommand.swift plus the app-level command catalog from OpenNekoApp.swift.</summary>
public static class SlashCommandParser
{
    public static SlashCommand? Parse(string line)
    {
        if (line.Length == 0 || line[0] != '/') return null;
        var rest = line[1..];
        if (rest.Length == 0) return null;
        var split = -1;
        for (var i = 0; i < rest.Length; i++)
        {
            if (char.IsWhiteSpace(rest[i])) { split = i; break; }
        }
        var rawCommand = split < 0 ? rest : rest[..split];
        var rawArguments = split < 0 ? "" : rest[(split + 1)..];
        var command = rawCommand.Trim().ToLowerInvariant();
        return command.Length == 0 ? null : new SlashCommand(command, rawArguments.Trim());
    }

    public static IReadOnlyList<SlashCommandDescriptor> MatchingCommands(string prefix, IEnumerable<SlashCommandDescriptor> catalog)
    {
        var normalized = prefix.ToLowerInvariant();
        return catalog
            .Where(c => normalized.Length == 0 || c.Name.ToLowerInvariant().StartsWith(normalized, StringComparison.Ordinal))
            .OrderBy(c => c.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public static IReadOnlyList<SlashCommandDescriptor> Catalog(IEnumerable<NekoSkill> enabledSkills, string? lang)
    {
        var list = new List<SlashCommandDescriptor>
        {
            new("help", SlashCommandKind.Builtin, AppLanguage.Pick(lang, "명령 보기", "Show commands", "コマンドを表示", "显示命令")),
            new("reset", SlashCommandKind.Builtin, AppLanguage.Pick(lang, "대화 초기화", "Reset chat", "会話をリセット", "重置对话")),
            new("skin", SlashCommandKind.App, AppLanguage.Pick(lang, "스킨 변경", "Change skin", "スキンを変更", "切换皮肤")),
            new("lang", SlashCommandKind.App, AppLanguage.Pick(lang, "언어 변경", "Change language", "言語を変更", "切换语言")),
            new("sound", SlashCommandKind.App, AppLanguage.Pick(lang, "효과음 전환", "Toggle sound", "効果音を切替", "切换音效")),
        };
        list.AddRange(enabledSkills.Select(s => new SlashCommandDescriptor(s.Id, SlashCommandKind.Skill, s.Description.Length == 0 ? s.Name : s.Description)));
        return list;
    }

    /// <summary>Parses /sound arguments: true/false to set, null to toggle; throws on unknown input.</summary>
    public static bool? SoundArgument(string argument) => argument.ToLowerInvariant() switch
    {
        "on" or "true" or "1" or "켜기" => true,
        "off" or "false" or "0" or "끄기" => false,
        "" => null,
        _ => throw new ArgumentException("usage"),
    };

    public static bool IsSystemLanguageArgument(string argument) =>
        argument.ToLowerInvariant() is "system" or "auto" or "default";
}
