namespace OpenNeko.Core;

/// <summary>The 14 sprite states. Mirrors CatState.swift; raw values match sprite file prefixes.</summary>
public enum CatState
{
    Idle, Hover, Click, Coding, Typing, Thinking,
    Lunch, Yawn, Nap, Success, Error, Dragging, Walk, Jump,
}

public static class CatStateExtensions
{
    public static IReadOnlyList<CatState> All { get; } = Enum.GetValues<CatState>();

    /// <summary>Lowercase raw value used in sprite manifests and the state bridge ("idle", "coding", ...).</summary>
    public static string RawValue(this CatState state) => state.ToString().ToLowerInvariant();

    public static CatState? FromRawValue(string? raw)
    {
        if (string.IsNullOrEmpty(raw)) return null;
        foreach (var state in All)
        {
            if (state.RawValue() == raw) return state;
        }
        return null;
    }
}
