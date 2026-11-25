using OpenNeko.Core;

namespace OpenNeko.Core.Tests;

public class AppSettingsTests
{
    [Fact]
    public void DefaultsMatchMac()
    {
        var d = AppSettings.Defaults;
        Assert.Equal("default", d.SelectedSkinId);
        Assert.Equal("chatgpt-oauth", d.AIProvider.PresetId);
        Assert.Equal(AIProviderType.CodexCli, d.AIProvider.Type);
        Assert.True(d.AgentProcessDetectionEnabled);
        Assert.True(d.SoundEffectsEnabled);
        Assert.Null(d.LanguageCode);
    }

    [Fact]
    public void RoundTripsThroughJson()
    {
        var settings = AppSettings.Defaults with
        {
            SelectedSkinId = "black",
            LanguageCode = "en-US",
            AIProvider = AIProviderPreset.Config("ollama", new AIProviderConfig(Model: "llama3")),
            DisabledSkillIds = new HashSet<string> { "saju", "explain" },
            CatName = "  Mochi  ",
            UserProfile = new UserProfile("경수", "1985-01-01", "", "lunar"),
        };
        var decoded = AppSettings.Decode(settings.Encode());
        Assert.Equal(settings, decoded);
        Assert.Equal("en", decoded.LanguageCode);
        Assert.Equal("Mochi", decoded.CatName);
        Assert.Equal("http://localhost:11434/v1", decoded.AIProvider.BaseUrl);
    }

    [Fact]
    public void EncodesMacCompatibleKeysSorted()
    {
        var json = AppSettings.Defaults.Encode();
        Assert.Contains("\"selectedSkinID\": \"default\"", json);
        Assert.Contains("\"presetID\": \"chatgpt-oauth\"", json);
        Assert.Contains("\"type\": \"codex-cli\"", json);
        Assert.DoesNotContain("languageCode", json);
        Assert.True(json.IndexOf("agentProcessDetectionEnabled", StringComparison.Ordinal) < json.IndexOf("webSearchEnabled", StringComparison.Ordinal));
    }

    [Fact]
    public void MigratesElectronLegacyKeys()
    {
        var legacy = """
        {"skin":"white","launchAtLogin":true,"onboarded":true,"provider":{"preset":"ollama","model":"qwen"},
         "disabledSkills":["saju"],"lang":"ja","sound":{"enabled":false},"webSearch":false,
         "profile":{"name":"Neko","birthDate":"2000-02-02"},"neighbor":{"enabled":true,"displayName":"Tama"},"peerId":"abc"}
        """;
        var s = AppSettings.Decode(legacy);
        Assert.Equal("default", s.SelectedSkinId);
        Assert.True(s.LaunchAtLoginEnabled);
        Assert.True(s.HasCompletedFirstLaunch);
        Assert.Equal("ollama", s.AIProvider.PresetId);
        Assert.Equal("qwen", s.AIProvider.Model);
        Assert.Equal("http://localhost:11434/v1", s.AIProvider.BaseUrl);
        Assert.Contains("saju", s.DisabledSkillIds);
        Assert.Equal("ja", s.LanguageCode);
        Assert.False(s.SoundEffectsEnabled);
        Assert.False(s.WebSearchEnabled);
        Assert.Equal("Neko", s.UserProfile.Name);
        Assert.Equal("Tama", s.CatName);
    }

    [Fact]
    public void PreservesMacOnlyFieldsOnSave()
    {
        var json = """{"selectedSkinID":"pink","neighborSettings":{"enabled":true,"displayName":"Tama"},"peerID":"xyz"}""";
        var reencoded = AppSettings.Decode(json).Encode();
        Assert.Contains("\"peerID\": \"xyz\"", reencoded);
        Assert.Contains("\"displayName\": \"Tama\"", reencoded);
    }

    [Fact]
    public void InvalidJsonFallsBackToDefaults() => Assert.Equal(AppSettings.Defaults, AppSettings.Decode("{oops"));

    [Fact]
    public void StoreSavesAtomicallyAndLoads()
    {
        var dir = Path.Combine(Path.GetTempPath(), "openneko-test-" + Guid.NewGuid());
        try
        {
            var store = new AppSettingsStore(Path.Combine(dir, "settings.json"));
            Assert.Equal(AppSettings.Defaults, store.Load());
            store.Save(AppSettings.Defaults with { SelectedSkinId = "calico" });
            Assert.Equal("calico", store.Load().SelectedSkinId);
            Assert.False(File.Exists(store.FilePath + ".tmp"));
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void UserProfileSanitizes()
    {
        var p = new UserProfile(new string('a', 100), " 1990-01-01 ", "", "moon");
        Assert.Equal(64, p.Name.Length);
        Assert.Equal("1990-01-01", p.BirthDate);
        Assert.Equal("solar", p.Calendar);
        Assert.True(new UserProfile().IsEmpty);
    }
}

public class WindowsAppPathsTests
{
    [Fact]
    public void MirrorsMacLocations()
    {
        var paths = new WindowsAppPaths(@"C:\Users\me\AppData\Roaming", @"C:\Users\me", new Dictionary<string, string?>());
        Assert.Equal(Path.Combine(@"C:\Users\me\AppData\Roaming", "openNeko", "settings.json"), paths.SettingsFile);
        Assert.Equal(Path.Combine(@"C:\Users\me\AppData\Roaming", "openNeko", "chat-history.md"), paths.ChatHistoryFile);
        Assert.Equal(Path.Combine(@"C:\Users\me", ".openneko", "skills"), paths.UserSkillsDirectory);
        Assert.Equal(Path.Combine(@"C:\Users\me\AppData\Roaming", "openNeko", "skins"), paths.SkinsDirectory);
    }

    [Fact]
    public void HonorsEnvironmentOverrides()
    {
        var env = new Dictionary<string, string?> { ["OPENNEKO_SETTINGS_PATH"] = "~/neko.json", ["OPENNEKO_CHAT_HISTORY_PATH"] = "  " };
        var paths = new WindowsAppPaths("appdata", "home", env);
        Assert.Equal(Path.Combine("home", "neko.json"), paths.SettingsFile);
        Assert.EndsWith("chat-history.md", paths.ChatHistoryFile);
    }
}

public class SkinManagerTests
{
    private static string BundledRoot => Path.Combine(AppContext.BaseDirectory, "Fixtures", "sprites");

    [Fact]
    public void LoadsRealBundledManifestWithAllStates()
    {
        var skin = new SkinManager(BundledRoot).LoadDefault();
        foreach (var state in CatStateExtensions.All)
            Assert.Equal(4, skin.FramePaths(state.RawValue()).Count);
        Assert.EndsWith("idle_0.png", skin.FramePaths("idle")[0]);
    }

    [Fact]
    public void SubfolderSkinsShareRootManifestAndExternalSkinsAreListed()
    {
        var temp = Path.Combine(Path.GetTempPath(), "openneko-skins-" + Guid.NewGuid());
        try
        {
            var bundled = Path.Combine(temp, "bundled");
            var external = Path.Combine(temp, "external");
            Directory.CreateDirectory(Path.Combine(bundled, "black"));
            Directory.CreateDirectory(Path.Combine(external, "mine"));
            File.WriteAllText(Path.Combine(bundled, "manifest.json"), "{\"idle\":[\"idle_0.png\"]}");
            File.WriteAllText(Path.Combine(external, "mine", "manifest.json"), "{\"idle\":[\"a.png\",\"b.png\"]}");
            var manager = new SkinManager(bundled, external);
            Assert.Equal(new[] { "black", "default", "mine" }, manager.AvailableSkinIds());
            Assert.Single(manager.LoadSkin("black").FramePaths("idle"));
            Assert.Equal(2, manager.LoadSkin("mine").FramePaths("idle").Count);
            Assert.Throws<FileNotFoundException>(() => manager.LoadSkin("ghost"));
            Assert.Throws<FileNotFoundException>(() => manager.LoadSkin(".."));
        }
        finally { Directory.Delete(temp, true); }
    }

    [Fact]
    public void LoadDefaultNeverThrows()
    {
        var skin = new SkinManager(Path.Combine(Path.GetTempPath(), "missing-" + Guid.NewGuid())).LoadDefault();
        Assert.Empty(skin.FramePaths("idle"));
    }

    [Fact]
    public void ManifestRejectsGarbage()
    {
        Assert.Throws<SpriteManifestException>(() => new SpriteManifest("[]"u8.ToArray()));
        Assert.Throws<SpriteManifestException>(() => new SpriteManifest("{\"idle\":[1]}"u8.ToArray()));
        Assert.Equal("white", SkinManager.Label("default"));
    }
}
