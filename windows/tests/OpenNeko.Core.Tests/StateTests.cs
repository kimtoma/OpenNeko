using OpenNeko.Core;

namespace OpenNeko.Core.Tests;

public class CatStateTests
{
    [Fact]
    public void RawValuesMatchSpriteFilePrefixes()
    {
        Assert.Equal(14, CatStateExtensions.All.Count);
        Assert.Equal("idle", CatState.Idle.RawValue());
        Assert.Equal("dragging", CatState.Dragging.RawValue());
        Assert.Equal(CatState.Thinking, CatStateExtensions.FromRawValue("thinking"));
        Assert.Null(CatStateExtensions.FromRawValue("Thinking"));
        Assert.Null(CatStateExtensions.FromRawValue(null));
    }

    [Fact]
    public void StateMachineIgnoresInputsWhileDragging()
    {
        var machine = new CatStateMachine();
        machine.Handle(CatInput.DragBegan);
        machine.Handle(CatInput.TypingStarted);
        machine.Handle(CatInput.Clicked);
        Assert.Equal(CatState.Dragging, machine.Current);
        machine.Handle(CatInput.DragEnded);
        Assert.Equal(CatState.Idle, machine.Current);
        machine.Handle(CatInput.IdleTimeout);
        Assert.Equal(CatState.Nap, machine.Current);
    }
}

public class NekoStatePriorityTests
{
    [Fact]
    public void OneShotStatesAreTheSettlingAnimations()
    {
        Assert.Equal(new[] { CatState.Click, CatState.Error, CatState.Jump, CatState.Success, CatState.Yawn }.OrderBy(s => s),
            NekoStatePriority.OneShotStates.OrderBy(s => s));
    }

    [Fact]
    public void ChatAnsweringBlocksBridgeAndAgentStates()
    {
        Assert.False(NekoStatePriority.AcceptsBridgeEvent(isChatAnswering: true));
        Assert.True(NekoStatePriority.AcceptsBridgeEvent(isChatAnswering: false));
        Assert.False(NekoStatePriority.AcceptsAgentCodingState(true, CatState.Idle));
        Assert.True(NekoStatePriority.AcceptsAgentCodingState(false, CatState.Walk));
        Assert.False(NekoStatePriority.AcceptsAgentCodingState(false, CatState.Nap));
        Assert.Equal(CatState.Thinking, NekoStatePriority.ChatAnsweringState);
    }
}

public class CatAnimationTimingTests
{
    [Theory]
    [InlineData(CatState.Typing, 0.125)]
    [InlineData(CatState.Walk, 0.12)]
    [InlineData(CatState.Nap, 0.4)]
    [InlineData(CatState.Thinking, 0.2)]
    [InlineData(CatState.Idle, 0.18)]
    public void TimePerFrameTable(CatState state, double expected) => Assert.Equal(expected, CatAnimationTiming.TimePerFrame(state));

    [Fact]
    public void TypingSpeedIsClamped()
    {
        Assert.Equal(0.8, CatAnimationTiming.ClampedTypingSpeed(0.1));
        Assert.Equal(1.8, CatAnimationTiming.ClampedTypingSpeed(9));
        Assert.Equal(1.2, CatAnimationTiming.ClampedTypingSpeed(1.2));
    }
}

public class CatAutonomousBehaviorTests
{
    private static CatAutonomousContext Context(double uptime = 100, int hour = 10, double lastInteraction = 90, double lastStretch = 0,
        double nextAutoEffect = 1000, bool lunch = false, bool leave = false, bool available = true) =>
        new(uptime, hour, lastInteraction, lastStretch, nextAutoEffect, lunch, leave, available);

    [Fact]
    public void UnavailableCatDoesNothing() =>
        Assert.Equal(CatAutonomousAction.None, CatAutonomousBehavior.Action(Context(available: false, uptime: 99999), 0));

    [Fact]
    public void PriorityOrderStretchLunchLeaveNapEffect()
    {
        Assert.Equal(CatAutonomousAction.Stretch, CatAutonomousBehavior.Action(Context(uptime: 3001, lastInteraction: 3000), 0));
        Assert.Equal(CatAutonomousAction.Lunch, CatAutonomousBehavior.Action(Context(hour: 12), 0));
        Assert.Equal(CatAutonomousAction.None, CatAutonomousBehavior.Action(Context(hour: 12, lunch: true), 0));
        Assert.Equal(CatAutonomousAction.LeaveWork, CatAutonomousBehavior.Action(Context(hour: 18), 0));
        Assert.Equal(CatAutonomousAction.Nap, CatAutonomousBehavior.Action(Context(uptime: 300, lastInteraction: 100), 0));
        Assert.Equal(CatAutonomousAction.Yawn, CatAutonomousBehavior.Action(Context(nextAutoEffect: 50), 0.2));
        Assert.Equal(CatAutonomousAction.Jump, CatAutonomousBehavior.Action(Context(nextAutoEffect: 50), 0.7));
    }
}

public class TypingActivityTrackerTests
{
    [Fact]
    public void KeyDownStartsTypingAndTickStopsAfterDelay()
    {
        var tracker = new TypingActivityTracker(0.8);
        Assert.True(tracker.KeyDown(10.0));
        Assert.False(tracker.KeyDown(10.1));
        Assert.False(tracker.Tick(10.8));
        Assert.True(tracker.Tick(10.9));
        Assert.False(tracker.IsTyping);
        Assert.Equal(1.0, tracker.AnimationSpeed);
    }

    [Fact]
    public void NextIdleDelayUsesRemainingTime()
    {
        var tracker = new TypingActivityTracker(0.8);
        tracker.KeyDown(10.0);
        Assert.Equal(0.5, tracker.NextIdleCheckDelay(10.3), 4);
        Assert.Equal(0.0, tracker.NextIdleCheckDelay(10.9), 4);
    }

    [Fact]
    public void FastTypingRaisesSpeedSlowTypingResets()
    {
        var tracker = new TypingActivityTracker(0.8);
        tracker.KeyDown(10.0);
        tracker.KeyDown(10.09);
        Assert.InRange(tracker.AnimationSpeed, 1.3001, 1.8);
        tracker.KeyDown(11.5); // gap longer than idle delay
        Assert.Equal(1.0, tracker.AnimationSpeed);
    }
}

public class CatDragGeometryTests
{
    [Fact]
    public void DragStartsOnlyBeyondSixPoints()
    {
        Assert.False(CatDragGeometry.HasDraggedBeyondStartDistance(new Point(0, 0), new Point(3, 4)));
        Assert.True(CatDragGeometry.HasDraggedBeyondStartDistance(new Point(0, 0), new Point(6, 1)));
    }

    [Fact]
    public void DangleFrameFollowsVelocityAndWriggles()
    {
        Assert.Equal(1, CatDragGeometry.DangleFrameIndex(3, 0, 0));
        Assert.Equal(3, CatDragGeometry.DangleFrameIndex(-3, 0, 0));
        Assert.Equal(1, CatDragGeometry.DangleFrameIndex(-3, 4, 0));
        Assert.Equal(0, CatDragGeometry.DangleFrameIndex(0, 0, 0.1));
        Assert.Equal(2, CatDragGeometry.DangleFrameIndex(0, 0, 0.2));
    }

    [Fact]
    public void SwingIsClamped()
    {
        Assert.Equal(-0.3, CatDragGeometry.DangleSwingAngle(100, 0, 0));
        Assert.Equal(0.3, CatDragGeometry.SwingAngle(-100));
    }

    [Fact]
    public void LandingDurationIsClamped()
    {
        Assert.Equal(0.12, CatDragGeometry.LandingDuration(10));
        Assert.Equal(0.45, CatDragGeometry.LandingDuration(5000));
        Assert.Equal(0.3, CatDragGeometry.LandingDuration(500), 6);
    }

    [Fact]
    public void TopPinnedOriginHangsCatFromPointer()
    {
        var origin = CatDragGeometry.TopPinnedDragOrigin(new Point(200, 300), new Size(128, 128));
        Assert.Equal(new Point(136, 176), origin);
    }

    [Fact]
    public void WalkStepStaysGroundedOnFlatFloor()
    {
        var step = CatDragGeometry.WalkVerticalMotionStep(2, 0, 2, 2, 1.0 / 60);
        Assert.True(step.IsGrounded);
        Assert.False(step.DidLaunch);
        Assert.Equal(2, step.OriginY);
    }

    [Fact]
    public void WalkStepJumpsUpOntoHigherFloor()
    {
        var step = CatDragGeometry.WalkVerticalMotionStep(2, 0, 2, 50, 1.0 / 60);
        Assert.True(step.DidLaunch);
        Assert.False(step.IsGrounded);
        Assert.True(step.VerticalVelocity > 0);
    }

    [Fact]
    public void SupportFloorUsesDockOnlyUnderFeet()
    {
        var screen = new Rect(0, 0, 1000, 800);
        var dock = new Rect(300, 0, 400, 60);
        var size = new Size(128, 128);
        Assert.Equal(62, CatDragGeometry.SupportFloorY(400, size, screen, screen, dock, 2));
        Assert.Equal(2, CatDragGeometry.SupportFloorY(10, size, screen, screen, dock, 2));
        Assert.Equal(2, CatDragGeometry.SupportFloorY(400, size, screen, screen, null, 2));
    }

    [Fact]
    public void ClampedDragOriginKeepsCatAboveFloor()
    {
        var visible = new Rect(0, 40, 1000, 760);
        var clamped = CatDragGeometry.ClampedDragOrigin(new Point(-50, 0), new Size(128, 128), visible, 2);
        Assert.Equal(new Point(0, 42), clamped);
    }
}

public class ScreenSpaceTests
{
    [Fact]
    public void WorkAreaAboveBottomTaskbarBecomesRaisedLocalRect()
    {
        var screen = new Rect(0, 0, 1920, 1080);
        var workArea = new Rect(0, 0, 1920, 1040); // taskbar 40px at bottom
        var local = ScreenSpace.LocalRect(workArea, screen);
        Assert.Equal(new Rect(0, 40, 1920, 1040), local);
    }

    [Fact]
    public void LocalOriginRoundTripsThroughDesktopCoordinates()
    {
        var screen = new Rect(1920, -200, 2560, 1440); // secondary monitor
        var size = new Size(128, 128);
        var topLeft = ScreenSpace.DesktopTopLeft(new Point(100, 42), size, screen);
        Assert.Equal(new Point(2020, 1440 - 200 - 42 - 128), topLeft);
        var bottomLeft = new Point(topLeft.X, topLeft.Y + size.Height);
        Assert.Equal(new Point(100, 42), ScreenSpace.LocalPoint(bottomLeft, screen));
    }
}
