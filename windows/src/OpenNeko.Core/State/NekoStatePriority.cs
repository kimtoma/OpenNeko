namespace OpenNeko.Core;

/// <summary>Mirrors NekoStatePriority.swift.</summary>
public static class NekoStatePriority
{
    public static CatState ChatAnsweringState => CatState.Thinking;

    /// <summary>States that play once and settle on their own.</summary>
    public static IReadOnlySet<CatState> OneShotStates { get; } =
        new HashSet<CatState> { CatState.Click, CatState.Yawn, CatState.Success, CatState.Error, CatState.Jump };

    public static bool AcceptsBridgeEvent(bool isChatAnswering) => !isChatAnswering;

    public static bool AcceptsAgentCodingState(bool isChatAnswering, CatState currentState)
    {
        if (isChatAnswering) return false;
        return currentState is CatState.Idle or CatState.Coding or CatState.Walk;
    }
}
