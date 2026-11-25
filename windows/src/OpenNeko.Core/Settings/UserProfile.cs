namespace OpenNeko.Core;

/// <summary>Mirrors UserProfile.swift.</summary>
public sealed record UserProfile
{
    public static readonly UserProfile Empty = new();

    public UserProfile(string name = "", string birthDate = "", string birthTime = "", string calendar = "solar")
    {
        Name = Sanitized(name, 64);
        BirthDate = Sanitized(birthDate, 32);
        BirthTime = Sanitized(birthTime, 16);
        Calendar = calendar switch { "lunar" => "lunar", "unknown" => "unknown", _ => "solar" };
    }

    public string Name { get; }
    public string BirthDate { get; }
    public string BirthTime { get; }
    public string Calendar { get; }

    public bool IsEmpty => Name.Length == 0 && BirthDate.Length == 0 && BirthTime.Length == 0;

    public static string Sanitized(string? value, int limit) => TextUtil.Prefix((value ?? "").Trim(), limit);
}
