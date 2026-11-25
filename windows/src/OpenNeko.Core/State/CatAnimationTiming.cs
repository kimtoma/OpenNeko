namespace OpenNeko.Core;

/// <summary>Per-state sprite timing. Mirrors CatAnimationTiming.swift.</summary>
public static class CatAnimationTiming
{
    public static double TimePerFrame(CatState state) => state switch
    {
        CatState.Typing or CatState.Click or CatState.Success or CatState.Jump => 0.125,
        CatState.Walk => 0.12,
        CatState.Nap => 0.4,
        CatState.Thinking => 0.2,
        _ => 0.18,
    };

    public static double ClampedTypingSpeed(double speed) => Math.Min(1.8, Math.Max(0.8, speed));
}
