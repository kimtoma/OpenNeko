using System.Text.Json;

namespace OpenNeko.Core;

/// <summary>
/// Localized names/descriptions/bodies for bundled skills. The table is generated
/// from the macOS NekoSkillLocalization.swift by windows/scripts/gen-skill-translations.py.
/// </summary>
public static class NekoSkillLocalization
{
    private sealed record Entry(string Name, string Description, string Body);

    private static readonly Lazy<Dictionary<string, Dictionary<string, Entry>>> Table = new(Load);

    public static NekoSkill Localize(NekoSkill skill, string? lang)
    {
        if (skill.Source != NekoSkillSource.Bundled) return skill;
        var language = AppLanguage.Normalized(lang) ?? "en";
        var table = Table.Value;
        Entry? entry = null;
        if (table.TryGetValue(language, out var pack)) pack.TryGetValue(skill.Id, out entry);
        if (entry is null && table.TryGetValue("en", out var en)) en.TryGetValue(skill.Id, out entry);
        return entry is null ? skill : skill with { Name = entry.Name, Description = entry.Description, Body = entry.Body };
    }

    public static IReadOnlyList<NekoSkill> Localize(IEnumerable<NekoSkill> skills, string? lang) => skills.Select(s => Localize(s, lang)).ToList();

    private static Dictionary<string, Dictionary<string, Entry>> Load()
    {
        using var stream = typeof(NekoSkillLocalization).Assembly.GetManifestResourceStream("OpenNeko.Core.skill-translations.json");
        if (stream is null) return new();
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        return JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, Entry>>>(stream, options) ?? new();
    }
}
