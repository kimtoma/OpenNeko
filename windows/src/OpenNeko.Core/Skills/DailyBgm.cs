using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace OpenNeko.Core;

public sealed record DailyBgmPreset(string Id, string Title, IReadOnlyList<string> Terms);

public sealed record DailyBgm(string Id, string Title, string DateKey, string Query, Uri Url, string Service, bool Personalized);

/// <summary>Deterministic "today's BGM" pick that opens YouTube Music search. Mirrors DailyBGM.swift.</summary>
public static class DailyBgmSelector
{
    public static readonly IReadOnlyList<DailyBgmPreset> Presets = new[]
    {
        new DailyBgmPreset("lofi-coding", "Lo-fi coding playlist", new[] { "lofi", "coding", "focus" }),
        new DailyBgmPreset("cafe-jazz", "Cafe jazz work playlist", new[] { "cafe jazz", "work", "instrumental" }),
        new DailyBgmPreset("rainy-focus", "Rainy focus playlist", new[] { "rain sounds", "ambient", "study" }),
        new DailyBgmPreset("city-pop-work", "City pop work playlist", new[] { "city pop", "work", "upbeat" }),
        new DailyBgmPreset("piano-deep-work", "Piano deep work playlist", new[] { "piano", "deep work", "instrumental" }),
        new DailyBgmPreset("synthwave-night", "Synthwave night drive playlist", new[] { "synthwave", "night drive", "focus" }),
        new DailyBgmPreset("chillhop-desk", "Chillhop desk playlist", new[] { "chillhop", "desk work", "beats" }),
        new DailyBgmPreset("game-ost-study", "Game OST study playlist", new[] { "game ost", "study", "relaxing" }),
        new DailyBgmPreset("ambient-coding", "Ambient coding playlist", new[] { "ambient", "coding", "no vocals" }),
        new DailyBgmPreset("k-indie-focus", "K-indie focus playlist", new[] { "korean indie", "focus", "playlist" }),
    };

    public static DailyBgm Pick(DateTime date, string? preference, UserProfile profile, string? languageCode)
    {
        var key = DateKey(date);
        var language = AppLanguage.Normalized(languageCode) ?? "en";
        var normalizedPreference = NormalizePreference(preference);
        var seed = string.Join("|", key, language, normalizedPreference, profile.Name, profile.BirthDate, profile.Calendar);
        var preset = Presets[(int)(HashString(seed) % (uint)Presets.Count)];
        var terms = new List<string> { normalizedPreference };
        terms.AddRange(preset.Terms);
        terms.Add(TimeTerm(date.Hour, language));
        terms.AddRange(LanguageTerms(language));
        var query = string.Join(" ", UniqueTerms(terms));
        return new DailyBgm(preset.Id, preset.Title, key, query, YouTubeMusicSearchUrl(query), "YouTube Music",
            normalizedPreference.Length > 0 || profile.Name.Length > 0 || profile.BirthDate.Length > 0);
    }

    public static string DateKey(DateTime date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static bool IsStopCommand(string text) =>
        new[] { "stop", "off", "pause", "정지", "중지", "끄기" }.Contains(text.ToLowerInvariant());

    public static string NormalizePreference(string? value)
    {
        var text = TextUtil.Prefix(value ?? "", 80);
        text = Regex.Replace(text, @"\s+", " ").Replace("<", "").Replace(">", "");
        return text.Trim();
    }

    public static Uri YouTubeMusicSearchUrl(string query) => new("https://music.youtube.com/search?q=" + Uri.EscapeDataString(query));

    private static IEnumerable<string> LanguageTerms(string language) => language switch
    {
        "ko" => new[] { "BGM", "플레이리스트" },
        "ja" => new[] { "BGM", "プレイリスト" },
        "zh" => new[] { "BGM", "播放列表" },
        _ => new[] { "BGM", "playlist" },
    };

    private static string TimeTerm(int hour, string language)
    {
        var bucket = hour < 11 ? 0 : hour < 17 ? 1 : hour < 21 ? 2 : 3;
        return language switch
        {
            "ko" => new[] { "아침", "오후", "저녁", "밤" }[bucket],
            "ja" => new[] { "朝", "午後", "夕方", "夜" }[bucket],
            "zh" => new[] { "早晨", "下午", "傍晚", "夜晚" }[bucket],
            _ => new[] { "morning", "afternoon", "evening", "night" }[bucket],
        };
    }

    private static List<string> UniqueTerms(IEnumerable<string> terms)
    {
        var seen = new HashSet<string>();
        var result = new List<string>();
        foreach (var raw in terms)
        {
            var term = NormalizePreference(raw);
            if (term.Length == 0 || !seen.Add(term.ToLowerInvariant())) continue;
            result.Add(term);
        }
        return result;
    }

    /// <summary>FNV-1a over Unicode scalars, identical to the Swift implementation.</summary>
    public static uint HashString(string text)
    {
        uint hash = 2_166_136_261;
        foreach (var rune in text.EnumerateRunes())
        {
            hash ^= (uint)rune.Value;
            unchecked { hash *= 16_777_619; }
        }
        return hash;
    }
}
