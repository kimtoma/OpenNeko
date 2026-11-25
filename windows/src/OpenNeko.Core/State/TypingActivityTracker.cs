namespace OpenNeko.Core;

/// <summary>
/// Turns keydown timestamps into typing activity and an animation speed.
/// Only timestamps are ever passed in: key contents are never read.
/// Mirrors TypingActivityTracker.swift.
/// </summary>
public sealed class TypingActivityTracker
{
    private const double MinimumAnimationSpeed = 0.8;
    private const double MaximumAnimationSpeed = 1.8;

    private double _typingUntil;
    private double? _previousKeyDownTime;

    public TypingActivityTracker(double idleDelay)
    {
        IdleDelay = Math.Max(0, idleDelay);
    }

    public double IdleDelay { get; }
    public bool IsTyping { get; private set; }
    public double AnimationSpeed { get; private set; } = 1.0;

    /// <returns>true when typing just started.</returns>
    public bool KeyDown(double time)
    {
        var changed = !IsTyping;
        UpdateAnimationSpeed(time);
        IsTyping = true;
        _typingUntil = time + IdleDelay;
        _previousKeyDownTime = time;
        return changed;
    }

    /// <returns>true when typing just stopped.</returns>
    public bool Tick(double time)
    {
        if (!IsTyping || time < _typingUntil) return false;
        IsTyping = false;
        AnimationSpeed = 1.0;
        _previousKeyDownTime = null;
        return true;
    }

    public double NextIdleCheckDelay(double time) => IsTyping ? Math.Max(0, _typingUntil - time) : 0;

    private void UpdateAnimationSpeed(double time)
    {
        if (_previousKeyDownTime is not double previous || time <= previous)
        {
            AnimationSpeed = 1.0;
            return;
        }
        var interval = time - previous;
        if (interval > Math.Max(0.05, IdleDelay))
        {
            AnimationSpeed = 1.0;
            return;
        }
        var target = SpeedForKeyInterval(interval);
        var blend = target > AnimationSpeed ? 0.7 : 0.45;
        AnimationSpeed += (target - AnimationSpeed) * blend;
        AnimationSpeed = Math.Min(MaximumAnimationSpeed, Math.Max(MinimumAnimationSpeed, AnimationSpeed));
    }

    private static double SpeedForKeyInterval(double interval)
    {
        var keysPerSecond = 1.0 / Math.Max(0.08, interval);
        var normalized = (keysPerSecond - 1.5) / (8.0 - 1.5);
        var clamped = Math.Min(1.0, Math.Max(0.0, normalized));
        return MinimumAnimationSpeed + clamped * (MaximumAnimationSpeed - MinimumAnimationSpeed);
    }
}
