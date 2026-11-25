namespace OpenNeko.Core;

public enum NekoSkillInput { Prompt, Clipboard, None }
public enum NekoSkillSource { Bundled, User }

public sealed record NekoSkill(string Id, string Name, string Description, NekoSkillInput Input, string Body, NekoSkillSource Source);

public static class NekoSkillInputExtensions
{
    public static NekoSkillInput? FromRawValue(string? raw) => raw switch
    {
        "prompt" => NekoSkillInput.Prompt,
        "clipboard" => NekoSkillInput.Clipboard,
        "none" => NekoSkillInput.None,
        _ => null,
    };

    public static string Title(this NekoSkillInput input, string? lang) => input switch
    {
        NekoSkillInput.Prompt => AppLanguage.Pick(lang, "입력", "Input", "入力", "输入"),
        NekoSkillInput.Clipboard => AppLanguage.Pick(lang, "클립보드", "Clipboard", "クリップボード", "剪贴板"),
        _ => AppLanguage.Pick(lang, "바로 실행", "Run", "実行", "运行"),
    };
}

public sealed class NekoSkillManifestException : Exception
{
    public NekoSkillManifestException(string reason) : base(reason) { }
}

/// <summary>SKILL.md front matter parser. Mirrors NekoSkillManifestParser.swift. Skill bodies are prompt text only.</summary>
public static class NekoSkillManifestParser
{
    public static NekoSkill Parse(string id, NekoSkillSource source, string text)
    {
        var normalized = text.Replace("\r\n", "\n");
        var parts = normalized.Split("\n---");
        if (!normalized.StartsWith("---\n", StringComparison.Ordinal) || parts.Length < 2)
            throw new NekoSkillManifestException("missingFrontMatter");
        var frontMatter = parts[0][4..];
        var body = string.Join("\n---", parts.Skip(1)).Trim();
        if (body.Length == 0) throw new NekoSkillManifestException("missingBody");
        var fields = new Dictionary<string, string>();
        foreach (var line in frontMatter.Split('\n'))
        {
            var colon = line.IndexOf(':');
            if (colon < 0) continue;
            var key = line[..colon].Trim();
            if (key.Length > 0) fields[key] = line[(colon + 1)..].Trim();
        }
        if (!fields.TryGetValue("name", out var name) || name.Length == 0) throw new NekoSkillManifestException("missingName");
        return new NekoSkill(id, name, fields.GetValueOrDefault("description", ""),
            NekoSkillInputExtensions.FromRawValue(fields.GetValueOrDefault("input")) ?? NekoSkillInput.Prompt, body, source);
    }
}

/// <summary>Bundled + user skills merged by id (user wins). Mirrors NekoSkillCatalog.swift.</summary>
public sealed class NekoSkillCatalog
{
    public NekoSkillCatalog(IEnumerable<NekoSkill> skills)
    {
        Skills = skills
            .OrderBy(s => s.Source == NekoSkillSource.Bundled ? 0 : 1)
            .ThenBy(s => s.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public IReadOnlyList<NekoSkill> Skills { get; }

    public static NekoSkillCatalog Discover(string? bundledRoot, string? userRoot)
    {
        var byId = new Dictionary<string, NekoSkill>();
        foreach (var skill in Discover(bundledRoot, NekoSkillSource.Bundled)) byId[skill.Id] = skill;
        foreach (var skill in Discover(userRoot, NekoSkillSource.User)) byId[skill.Id] = skill;
        return new NekoSkillCatalog(byId.Values);
    }

    public IReadOnlyList<NekoSkill> Enabled(IReadOnlySet<string> disabledIds) => Skills.Where(s => !disabledIds.Contains(s.Id)).ToList();

    public NekoSkill? Skill(string id) => Skills.FirstOrDefault(s => s.Id == id);

    private static IEnumerable<NekoSkill> Discover(string? root, NekoSkillSource source)
    {
        if (root is null || !Directory.Exists(root)) yield break;
        foreach (var dir in Directory.GetDirectories(root))
        {
            var id = Path.GetFileName(dir);
            if (id.StartsWith('.')) continue;
            var manifest = Path.Combine(dir, "SKILL.md");
            if (!File.Exists(manifest)) continue;
            NekoSkill? skill = null;
            try { skill = NekoSkillManifestParser.Parse(id, source, File.ReadAllText(manifest)); }
            catch (Exception e) when (e is NekoSkillManifestException or IOException) { }
            if (skill is not null) yield return skill;
        }
    }
}

/// <summary>Mirrors NekoActiveSkillSelection.swift.</summary>
public sealed class NekoActiveSkillSelection
{
    public string? Id { get; private set; }

    /// <returns>true when the chat history should be reset (switching between skills).</returns>
    public bool Activate(NekoSkill skill)
    {
        var reset = Id is not null && Id != skill.Id;
        Id = skill.Id;
        return reset;
    }

    public void Clear() => Id = null;

    public void Reconcile(NekoSkillCatalog catalog, IReadOnlySet<string> disabledIds)
    {
        if (Id is null) return;
        if (disabledIds.Contains(Id) || catalog.Skill(Id) is null) Id = null;
    }

    public NekoSkill? Resolve(NekoSkillCatalog catalog, IReadOnlySet<string> disabledIds)
    {
        Reconcile(catalog, disabledIds);
        return Id is null ? null : catalog.Skill(Id);
    }
}
