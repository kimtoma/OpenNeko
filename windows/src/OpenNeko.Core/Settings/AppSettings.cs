using System.Text.Json;
using System.Text.Json.Nodes;

namespace OpenNeko.Core;

/// <summary>
/// Persisted settings. Mirrors AppSettings.swift: same JSON keys, same legacy
/// (Electron prototype) migration, so a settings.json can move between apps.
/// API keys are never stored here (Windows Credential Manager only).
/// Neighbor settings are macOS-only and preserved untouched on save.
/// </summary>
public sealed record AppSettings
{
    public static AppSettings Defaults => new();

    public string SelectedSkinId { get; init; } = SkinManager.DefaultId;
    public bool LaunchAtLoginEnabled { get; init; }
    public bool HasCompletedFirstLaunch { get; init; }
    public AIProviderConfig AIProvider { get; init; } = AIProviderPreset.DefaultConfig;
    public IReadOnlySet<string> DisabledSkillIds { get; init; } = new HashSet<string>();
    public bool AgentProcessDetectionEnabled { get; init; } = true;

    private readonly string? _languageCode;
    public string? LanguageCode { get => _languageCode; init => _languageCode = AppLanguage.Normalized(value); }

    public bool SoundEffectsEnabled { get; init; } = true;
    public bool WebSearchEnabled { get; init; } = true;

    private readonly string _catName = "";
    public string CatName { get => _catName; init => _catName = UserProfile.Sanitized(value, 64); }

    public UserProfile UserProfile { get; init; } = UserProfile.Empty;

    /// <summary>Opaque passthrough of fields this app does not use (neighborSettings, peerID).</summary>
    public JsonObject Passthrough { get; init; } = new();

    public bool Equals(AppSettings? other) =>
        other is not null &&
        SelectedSkinId == other.SelectedSkinId &&
        LaunchAtLoginEnabled == other.LaunchAtLoginEnabled &&
        HasCompletedFirstLaunch == other.HasCompletedFirstLaunch &&
        AIProvider == other.AIProvider &&
        DisabledSkillIds.SetEquals(other.DisabledSkillIds) &&
        AgentProcessDetectionEnabled == other.AgentProcessDetectionEnabled &&
        LanguageCode == other.LanguageCode &&
        SoundEffectsEnabled == other.SoundEffectsEnabled &&
        WebSearchEnabled == other.WebSearchEnabled &&
        CatName == other.CatName &&
        UserProfile == other.UserProfile;

    public override int GetHashCode() => HashCode.Combine(SelectedSkinId, AIProvider, LanguageCode, CatName);

    private static readonly string[] PassthroughKeys = { "neighborSettings", "peerID" };

    public static AppSettings Decode(string json)
    {
        JsonObject root;
        try
        {
            root = JsonNode.Parse(json) as JsonObject ?? throw new JsonException("not an object");
        }
        catch (JsonException)
        {
            return Defaults;
        }

        var d = Defaults;
        var legacyNeighbor = root["neighbor"] as JsonObject;
        var passthrough = new JsonObject();
        foreach (var key in PassthroughKeys)
        {
            if (root[key] is JsonNode node) passthrough[key] = node.DeepClone();
        }

        var legacyDisplayName = Str(legacyNeighbor?["displayName"]);
        return new AppSettings
        {
            SelectedSkinId = Str(root["selectedSkinID"]) ?? NormalizedLegacySkinId(Str(root["skin"])) ?? d.SelectedSkinId,
            LaunchAtLoginEnabled = Bool(root["launchAtLoginEnabled"]) ?? Bool(root["launchAtLogin"]) ?? d.LaunchAtLoginEnabled,
            HasCompletedFirstLaunch = Bool(root["hasCompletedFirstLaunch"]) ?? Bool(root["onboarded"]) ?? d.HasCompletedFirstLaunch,
            AIProvider = DecodeProvider(root["aiProvider"] as JsonObject) ?? MigratedLegacyProvider(root["provider"] as JsonObject) ?? d.AIProvider,
            DisabledSkillIds = new HashSet<string>(StrArray(root["disabledSkillIDs"]) ?? StrArray(root["disabledSkills"]) ?? Array.Empty<string>()),
            AgentProcessDetectionEnabled = Bool(root["agentProcessDetectionEnabled"]) ?? d.AgentProcessDetectionEnabled,
            LanguageCode = Str(root["languageCode"]) ?? Str(root["lang"]),
            SoundEffectsEnabled = Bool(root["soundEffectsEnabled"]) ?? Bool((root["sound"] as JsonObject)?["enabled"]) ?? d.SoundEffectsEnabled,
            WebSearchEnabled = Bool(root["webSearchEnabled"]) ?? Bool(root["webSearch"]) ?? d.WebSearchEnabled,
            CatName = Str(root["catName"]) ?? legacyDisplayName ?? d.CatName,
            UserProfile = DecodeProfile(root["userProfile"] as JsonObject) ?? DecodeProfile(root["profile"] as JsonObject) ?? d.UserProfile,
            Passthrough = passthrough,
        };
    }

    public string Encode()
    {
        var root = new JsonObject
        {
            ["agentProcessDetectionEnabled"] = AgentProcessDetectionEnabled,
            ["aiProvider"] = new JsonObject
            {
                ["baseURL"] = AIProvider.BaseUrl,
                ["model"] = AIProvider.Model,
                ["presetID"] = AIProvider.PresetId,
                ["type"] = AIProvider.Type.RawValue(),
            },
            ["catName"] = CatName,
            ["disabledSkillIDs"] = new JsonArray(DisabledSkillIds.OrderBy(s => s, StringComparer.Ordinal).Select(s => (JsonNode)JsonValue.Create(s)!).ToArray()),
            ["hasCompletedFirstLaunch"] = HasCompletedFirstLaunch,
            ["launchAtLoginEnabled"] = LaunchAtLoginEnabled,
            ["selectedSkinID"] = SelectedSkinId,
            ["soundEffectsEnabled"] = SoundEffectsEnabled,
            ["userProfile"] = new JsonObject
            {
                ["birthDate"] = UserProfile.BirthDate,
                ["birthTime"] = UserProfile.BirthTime,
                ["calendar"] = UserProfile.Calendar,
                ["name"] = UserProfile.Name,
            },
            ["webSearchEnabled"] = WebSearchEnabled,
        };
        if (LanguageCode is not null) root["languageCode"] = LanguageCode;
        foreach (var (key, value) in Passthrough)
        {
            if (value is not null) root[key] = value.DeepClone();
        }
        var sorted = new JsonObject();
        foreach (var key in root.Select(p => p.Key).OrderBy(k => k, StringComparer.Ordinal).ToList())
        {
            var node = root[key];
            root.Remove(key);
            sorted[key] = node;
        }
        return sorted.ToJsonString(new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
    }

    private static AIProviderConfig? DecodeProvider(JsonObject? obj)
    {
        if (obj is null) return null;
        var type = AIProviderTypeExtensions.FromRawValue(Str(obj["type"]));
        if (type is null) return null; // matches Swift: an invalid type fails the whole decode
        return new AIProviderConfig(Str(obj["presetID"]) ?? "", type.Value, Str(obj["baseURL"]) ?? "", Str(obj["model"]) ?? "");
    }

    private static AIProviderConfig? MigratedLegacyProvider(JsonObject? legacy)
    {
        var presetId = Str(legacy?["preset"]);
        if (presetId is null || AIProviderPreset.Preset(presetId) is not AIProviderPreset preset) return null;
        return AIProviderPreset.Config(presetId, new AIProviderConfig(
            presetId,
            AIProviderTypeExtensions.FromRawValue(Str(legacy!["type"])) ?? preset.Type,
            Str(legacy["baseURL"]) ?? "",
            Str(legacy["model"]) ?? ""));
    }

    private static UserProfile? DecodeProfile(JsonObject? obj)
    {
        if (obj is null) return null;
        return new UserProfile(Str(obj["name"]) ?? "", Str(obj["birthDate"]) ?? "", Str(obj["birthTime"]) ?? "", Str(obj["calendar"]) ?? "solar");
    }

    private static string? NormalizedLegacySkinId(string? id) =>
        string.IsNullOrEmpty(id) ? null : id == "white" ? SkinManager.DefaultId : id;

    private static string? Str(JsonNode? node) =>
        node is JsonValue v && v.TryGetValue<string>(out var s) ? s : null;

    private static bool? Bool(JsonNode? node) =>
        node is JsonValue v && v.TryGetValue<bool>(out var b) ? b : null;

    private static string[]? StrArray(JsonNode? node)
    {
        if (node is not JsonArray array) return null;
        var result = new List<string>();
        foreach (var item in array)
        {
            if (Str(item) is not string s) return null;
            result.Add(s);
        }
        return result.ToArray();
    }
}

/// <summary>Loads/saves settings.json atomically. Mirrors AppSettingsStore.</summary>
public sealed class AppSettingsStore
{
    public AppSettingsStore(string filePath) { FilePath = filePath; }

    public string FilePath { get; }

    public AppSettings Load()
    {
        try
        {
            return File.Exists(FilePath) ? AppSettings.Decode(File.ReadAllText(FilePath)) : AppSettings.Defaults;
        }
        catch (IOException)
        {
            return AppSettings.Defaults;
        }
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        var temp = FilePath + ".tmp";
        File.WriteAllText(temp, settings.Encode());
        File.Move(temp, FilePath, overwrite: true);
    }
}
