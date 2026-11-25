using OpenNeko.Core;

namespace OpenNeko.Core.Tests;

public class SkillTests
{
    private static string BundledRoot => Path.Combine(AppContext.BaseDirectory, "Fixtures", "skills");

    [Fact]
    public void ParsesFrontMatter()
    {
        var skill = NekoSkillManifestParser.Parse("t", NekoSkillSource.User, "---\r\nname: 번역\r\ndescription: a: b\r\ninput: clipboard\r\n---\r\nBody\n---\nmore");
        Assert.Equal("번역", skill.Name);
        Assert.Equal("a: b", skill.Description);
        Assert.Equal(NekoSkillInput.Clipboard, skill.Input);
        Assert.Equal("Body\n---\nmore", skill.Body);
    }

    [Theory]
    [InlineData("no front matter", "missingFrontMatter")]
    [InlineData("---\nname: x\n---\n   ", "missingBody")]
    [InlineData("---\ndescription: x\n---\nbody", "missingName")]
    public void RejectsBadManifests(string text, string reason) =>
        Assert.Equal(reason, Assert.Throws<NekoSkillManifestException>(() => NekoSkillManifestParser.Parse("x", NekoSkillSource.User, text)).Message);

    [Fact]
    public void DiscoversRealBundledSkillsAndUserOverrides()
    {
        var user = Path.Combine(Path.GetTempPath(), "neko-skills-" + Guid.NewGuid());
        Directory.CreateDirectory(Path.Combine(user, "translate"));
        Directory.CreateDirectory(Path.Combine(user, "mine"));
        File.WriteAllText(Path.Combine(user, "translate", "SKILL.md"), "---\nname: My Translate\n---\nbody");
        File.WriteAllText(Path.Combine(user, "mine", "SKILL.md"), "---\nname: Mine\n---\nbody");
        try
        {
            var catalog = NekoSkillCatalog.Discover(BundledRoot, user);
            Assert.Equal(8, catalog.Skills.Count);
            Assert.Equal(NekoSkillSource.User, catalog.Skill("translate")!.Source);
            Assert.Equal(NekoSkillSource.Bundled, catalog.Skills[0].Source);
            Assert.Equal(NekoSkillSource.User, catalog.Skills[^1].Source);
            Assert.DoesNotContain(catalog.Enabled(new HashSet<string> { "saju" }), s => s.Id == "saju");
        }
        finally { Directory.Delete(user, true); }
    }

    [Fact]
    public void LocalizesBundledSkillsOnly()
    {
        var bundled = new NekoSkill("translate", "번역", "", NekoSkillInput.Clipboard, "원문", NekoSkillSource.Bundled);
        var en = NekoSkillLocalization.Localize(bundled, "en");
        Assert.NotEqual("번역", en.Name);
        Assert.Equal(NekoSkillInput.Clipboard, en.Input);
        Assert.Equal("번역", NekoSkillLocalization.Localize(bundled, "ko").Name);
        var user = bundled with { Source = NekoSkillSource.User };
        Assert.Same(user, NekoSkillLocalization.Localize(user, "en"));
        foreach (var lang in new[] { "ko", "en", "ja", "zh" })
            foreach (var id in new[] { "clipboard-summary", "daily-bgm", "daily-fortune", "explain", "saju", "translate", "youtube-summary" })
                Assert.False(string.IsNullOrWhiteSpace(NekoSkillLocalization.Localize(bundled with { Id = id }, lang).Body));
    }

    [Fact]
    public void ActiveSelectionResetsHistoryOnlyWhenSwitching()
    {
        var a = new NekoSkill("a", "A", "", NekoSkillInput.Prompt, "b", NekoSkillSource.Bundled);
        var b = a with { Id = "b" };
        var selection = new NekoActiveSkillSelection();
        Assert.False(selection.Activate(a));
        Assert.False(selection.Activate(a));
        Assert.True(selection.Activate(b));
        var catalog = new NekoSkillCatalog(new[] { a, b });
        Assert.Null(selection.Resolve(catalog, new HashSet<string> { "b" }));
        Assert.Null(selection.Id);
    }

    [Fact]
    public void SlashCommands()
    {
        Assert.Equal(new SlashCommand("skin", "black cat"), SlashCommandParser.Parse("/SKIN   black cat "));
        Assert.Null(SlashCommandParser.Parse("/"));
        Assert.Null(SlashCommandParser.Parse("hello"));
        var catalog = SlashCommandParser.Catalog(new[] { new NekoSkill("saju", "사주", "", NekoSkillInput.Prompt, "b", NekoSkillSource.Bundled) }, "en");
        Assert.Equal(new[] { "saju", "skin", "sound" }, SlashCommandParser.MatchingCommands("S", catalog).Select(c => c.Name));
        Assert.Equal("사주", catalog.Single(c => c.Name == "saju").Description);
        Assert.True(SlashCommandParser.SoundArgument("켜기"));
        Assert.False(SlashCommandParser.SoundArgument("OFF"));
        Assert.Null(SlashCommandParser.SoundArgument(""));
        Assert.Throws<ArgumentException>(() => SlashCommandParser.SoundArgument("loud"));
        Assert.True(SlashCommandParser.IsSystemLanguageArgument("Auto"));
    }

    [Fact]
    public void DailyBgmIsStablePerDayAndEncodesQuery()
    {
        var morning = DailyBgmSelector.Pick(new DateTime(2026, 6, 24, 9, 0, 0), null, UserProfile.Empty, "en");
        var night = DailyBgmSelector.Pick(new DateTime(2026, 6, 24, 23, 0, 0), null, UserProfile.Empty, "en");
        Assert.Equal(morning.Id, night.Id);
        Assert.Equal("2026-06-24", morning.DateKey);
        Assert.StartsWith("https://music.youtube.com/search?q=", morning.Url.AbsoluteUri);
        var jazz = DailyBgmSelector.Pick(new DateTime(2026, 6, 24, 9, 0, 0), "jazz  <cafe>", UserProfile.Empty, "ko");
        Assert.StartsWith("jazz cafe ", jazz.Query);
        Assert.Contains("아침", jazz.Query);
        Assert.True(jazz.Personalized);
        Assert.True(DailyBgmSelector.IsStopCommand("PAUSE"));
        Assert.Equal(2_166_136_261u, DailyBgmSelector.HashString(""));
        Assert.Equal(0xe40c292cu, DailyBgmSelector.HashString("a")); // FNV-1a 32-bit reference value
    }
}

public class AgentProcessDetectorTests
{
    [Fact]
    public void DetectsPsOutputLikeMac()
    {
        var ps = "  0.0 /Applications/Cursor.app/Contents/MacOS/Cursor\n  3.4 /Users/me/.npm/_npx/123/node_modules/.bin/codex exec\n  1.2 Codex Helper\n  6.7 /opt/homebrew/bin/claude -p hello\n  0.2 /opt/homebrew/bin/claude idle\n";
        var activities = AgentProcessDetector.Detect(ps);
        Assert.Equal("claude", activities[0].Source);
        Assert.Equal(6.7, activities[0].Cpu);
        Assert.Contains(new AgentProcessActivity("cursor", "Cursor", 0.0), activities);
        Assert.Contains(new AgentProcessActivity("codex-cli", "Codex CLI", 3.4), activities);
    }

    [Theory]
    [InlineData("claude.exe", @"""C:\Users\me\.local\bin\claude.exe"" -p hi", "C:/Users/me/.local/bin/claude -p hi")]
    [InlineData("Cursor.exe", @"""C:\Users\me\AppData\Local\Programs\cursor\Cursor.exe"" --type=renderer", "C:/Users/me/AppData/Local/Programs/cursor/Cursor --type=renderer")]
    [InlineData("node.exe", @"node C:\Users\me\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\cli.js", "node C:/Users/me/AppData/Roaming/npm/node_modules/@anthropic-ai/claude-code/cli.js")]
    [InlineData("Kiro.exe", null, "Kiro")]
    public void NormalizesWindowsCommandLines(string name, string? commandLine, string expected) =>
        Assert.Equal(expected, AgentProcessDetector.NormalizeWindowsCommand(name, commandLine));

    [Fact]
    public void DetectsWindowsProcessSamples()
    {
        var samples = new[]
        {
            new ProcessSample("claude.exe", @"C:\Users\me\.local\bin\claude.exe", 5.0),
            new ProcessSample("node.exe", @"""C:\Program Files\nodejs\node.exe"" C:\Users\me\AppData\Roaming\npm\node_modules\@google\gemini-cli\dist\index.js", 3.0),
            new ProcessSample("codex.exe", @"C:\Users\me\AppData\Roaming\npm\node_modules\@openai\codex\vendor\x86_64-pc-windows-msvc\codex\codex.exe exec", 2.5),
            new ProcessSample("Cursor.exe", @"""C:\Users\me\AppData\Local\Programs\cursor\Cursor.exe""", 1.0),
            new ProcessSample("claude.exe", @"""C:\Users\me\AppData\Local\AnthropicClaude\app-1.0\claude.exe""", 40.0),
            new ProcessSample("notepad.exe", @"C:\Windows\notepad.exe", 50.0),
        };
        var activities = AgentProcessDetector.Detect(samples);
        Assert.Equal(new[] { "claude", "gemini", "codex-cli", "cursor" }, activities.Select(a => a.Source));
        Assert.Equal(5.0, activities[0].Cpu); // desktop chat app ignored
        Assert.Equal("claude", AgentProcessDetector.TopBusyActivity(activities)!.Source);
    }

    [Fact]
    public void PassiveCodexAppNeverBusy() =>
        Assert.Null(AgentProcessDetector.TopBusyActivity(new[] { new AgentProcessActivity("codex-app", "Codex App", 24), new AgentProcessActivity("claude", "Claude", 0.6) }));

    [Fact]
    public void ClaudeSessionsWithResumeAreIgnored() =>
        Assert.Empty(AgentProcessDetector.Detect("  9.0 /usr/local/bin/claude --resume abc --x\n"));

    [Fact]
    public void CpuPercentIsPerCore()
    {
        Assert.Equal(50, AgentProcessDetector.CpuPercent(TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(4)), 6);
        Assert.Equal(0, AgentProcessDetector.CpuPercent(TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(4)));
        Assert.Equal(0, AgentProcessDetector.CpuPercent(TimeSpan.Zero, TimeSpan.FromSeconds(1), TimeSpan.Zero));
    }
}

public class CatSoundSynthTests
{
    [Fact]
    public void ProducesValidShortWavFiles()
    {
        foreach (var effect in Enum.GetValues<CatSoundEffect>())
        {
            var wav = CatSoundSynth.Wav(effect);
            Assert.Equal("RIFF", System.Text.Encoding.ASCII.GetString(wav, 0, 4));
            Assert.Equal("WAVE", System.Text.Encoding.ASCII.GetString(wav, 8, 4));
            Assert.Equal(wav.Length - 8, BitConverter.ToInt32(wav, 4));
            var seconds = (wav.Length - 44) / 2.0 / CatSoundSynth.SampleRate;
            Assert.InRange(seconds, 0.03, 0.5);
        }
    }

    [Fact]
    public void ThrottlesPerEffect()
    {
        var last = new Dictionary<CatSoundEffect, double>();
        Assert.True(CatSoundSynth.ShouldPlay(last, CatSoundEffect.Chirp, 1.0));
        Assert.False(CatSoundSynth.ShouldPlay(last, CatSoundEffect.Chirp, 1.05));
        Assert.True(CatSoundSynth.ShouldPlay(last, CatSoundEffect.Land, 1.05));
        Assert.True(CatSoundSynth.ShouldPlay(last, CatSoundEffect.Chirp, 1.2));
        Assert.Equal(0.42, CatSoundSynth.Volume(CatSoundEffect.Success));
    }
}
