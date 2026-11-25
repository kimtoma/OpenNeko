namespace OpenNeko.Core;

public sealed record CatAutonomousContext(
    double Uptime,
    int Hour,
    double LastInteraction,
    double LastStretch,
    double NextAutoEffect,
    bool LunchAlreadyShown,
    bool LeaveWorkAlreadyShown,
    bool IsAvailable);

public enum CatAutonomousAction { None, Stretch, Lunch, LeaveWork, Nap, Yawn, Jump }

/// <summary>Idle-time rituals. Mirrors CatAutonomousBehavior.swift.</summary>
public static class CatAutonomousBehavior
{
    public const double StretchInterval = 50 * 60;
    public const double NapAfter = 2 * 60;
    public const int LunchHour = 12;
    public const int LeaveWorkHour = 18;

    public static CatAutonomousAction Action(CatAutonomousContext context, double randomValue)
    {
        if (!context.IsAvailable) return CatAutonomousAction.None;
        if (context.Uptime - context.LastStretch > StretchInterval) return CatAutonomousAction.Stretch;
        if (context.Hour == LunchHour && !context.LunchAlreadyShown) return CatAutonomousAction.Lunch;
        if (context.Hour == LeaveWorkHour && !context.LeaveWorkAlreadyShown) return CatAutonomousAction.LeaveWork;
        if (context.Uptime - context.LastInteraction > NapAfter) return CatAutonomousAction.Nap;
        if (context.Uptime > context.NextAutoEffect)
            return randomValue < 0.5 ? CatAutonomousAction.Yawn : CatAutonomousAction.Jump;
        return CatAutonomousAction.None;
    }
}
