using System.Globalization;

namespace OpenNeko.Core;

/// <summary>Mirrors AppLanguage.swift.</summary>
public static class AppLanguage
{
    public static readonly string[] SupportedCodes = { "ko", "en", "ja", "zh" };

    public static string? Normalized(string? rawValue)
    {
        if (rawValue is null) return null;
        var code = rawValue.Trim().ToLowerInvariant().Replace('_', '-');
        if (SupportedCodes.Contains(code)) return code;
        if (code.StartsWith("zh", StringComparison.Ordinal)) return "zh";
        var baseCode = code.Split('-')[0];
        return SupportedCodes.Contains(baseCode) ? baseCode : null;
    }

    public static string Resolved(string? storedCode, string? cultureName = null)
    {
        if (Normalized(storedCode) is string code) return code;
        var culture = (cultureName ?? CultureInfo.CurrentUICulture.Name).ToLowerInvariant();
        if (culture.StartsWith("zh", StringComparison.Ordinal)) return "zh";
        var language = culture.Split('-')[0];
        return SupportedCodes.Contains(language) ? language : "en";
    }

    public static string DisplayName(string? code) => Normalized(code) switch
    {
        "ko" => "한국어",
        "en" => "English",
        "ja" => "日本語",
        "zh" => "简体中文",
        _ => "시스템 기본",
    };

    /// <summary>Picks the string for a language, defaulting to Korean like the macOS copy tables.</summary>
    public static string Pick(string? languageCode, string ko, string en, string ja, string zh) =>
        (Normalized(languageCode) ?? "ko") switch
        {
            "en" => en,
            "ja" => ja,
            "zh" => zh,
            _ => ko,
        };
}
