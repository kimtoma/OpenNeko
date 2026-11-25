namespace OpenNeko.Core;

/// <summary>
/// Where the Windows app keeps its files. Mirrors the macOS locations:
/// ~/Library/Application Support/openNeko -> %APPDATA%\openNeko, and
/// ~/.openneko/skills -> %USERPROFILE%\.openneko\skills.
/// </summary>
public sealed class WindowsAppPaths
{
    public WindowsAppPaths(string appDataRoot, string userProfileRoot, IReadOnlyDictionary<string, string?> environment)
    {
        DataDirectory = Path.Combine(appDataRoot, "openNeko");
        SettingsFile = Override(environment, "OPENNEKO_SETTINGS_PATH", userProfileRoot) ?? Path.Combine(DataDirectory, "settings.json");
        ChatHistoryFile = Override(environment, "OPENNEKO_CHAT_HISTORY_PATH", userProfileRoot) ?? Path.Combine(DataDirectory, ChatTranscriptStore.FileName);
        SkinsDirectory = Path.Combine(DataDirectory, "skins");
        UserSkillsDirectory = Path.Combine(userProfileRoot, ".openneko", "skills");
    }

    public string DataDirectory { get; }
    public string SettingsFile { get; }
    public string ChatHistoryFile { get; }
    public string SkinsDirectory { get; }
    public string UserSkillsDirectory { get; }

    private static string? Override(IReadOnlyDictionary<string, string?> env, string key, string home)
    {
        if (!env.TryGetValue(key, out var raw) || string.IsNullOrWhiteSpace(raw)) return null;
        var value = raw.Trim();
        if (value == "~") return home;
        if (value.StartsWith("~/", StringComparison.Ordinal) || value.StartsWith("~\\", StringComparison.Ordinal))
            return Path.Combine(home, value[2..]);
        return value;
    }
}
