namespace OpenNeko.Core;

/// <summary>
/// Drag, dangle, landing and walk physics in monitor-local y-up coordinates.
/// Mirrors CatDragGeometry.swift (values and formulas kept identical).
/// </summary>
public static class CatDragGeometry
{
    public const double DefaultPinOffsetY = 4;
    public const double DragStartDistance = 6;
    public const double MaxSwingAngle = 0.3;
    public const double SwingVelocityScale = 0.025;
    public const double SwingAccelerationScale = 0.012;
    public const double IdleSwayAmplitude = 0.026;
    public const double IdleSwayPeriod = 0.58;
    public const double IdleWrigglePeriod = 0.18;
    public const double DragVelocityDecay = 0.82;
    public const double MaxDangleOffsetX = 12;
    public const double WalkGravity = 2_200;
    public const double WalkStepJumpPadding = 18;
    public const double WalkDropHopVelocity = 210;

    public static double SmoothedHorizontalVelocity(double previous, double previousMouseX, double currentMouseX) =>
        previous * 0.65 + (currentMouseX - previousMouseX) * 0.35;

    public static bool HasDraggedBeyondStartDistance(Point start, Point current) =>
        Math.Sqrt(Math.Pow(current.X - start.X, 2) + Math.Pow(current.Y - start.Y, 2)) > DragStartDistance;

    public static double SwingAngle(double horizontalVelocity) =>
        Clamp(-horizontalVelocity * SwingVelocityScale, -MaxSwingAngle, MaxSwingAngle);

    public static double SmoothedHorizontalAcceleration(double previous, double previousVelocity, double currentVelocity) =>
        previous * 0.55 + (currentVelocity - previousVelocity) * 0.45;

    public static double DecayedHorizontalVelocity(double velocity)
    {
        var decayed = velocity * DragVelocityDecay;
        return Math.Abs(decayed) < 0.05 ? 0 : decayed;
    }

    public static double DangleSwingAngle(double horizontalVelocity, double horizontalAcceleration, double time)
    {
        if (Math.Abs(horizontalVelocity) > 2.5 || Math.Abs(horizontalAcceleration) > 3)
        {
            var inertial = -horizontalVelocity * SwingVelocityScale - horizontalAcceleration * SwingAccelerationScale;
            return Clamp(inertial, -MaxSwingAngle, MaxSwingAngle);
        }
        var phase = time / IdleSwayPeriod * 2 * Math.PI;
        return Math.Sin(phase) * IdleSwayAmplitude;
    }

    public static int DangleFrameIndex(double horizontalVelocity, double horizontalAcceleration, double time)
    {
        if (horizontalAcceleration > 3) return 1;
        if (horizontalAcceleration < -3) return 3;
        if (horizontalVelocity > 2.5) return 1;
        if (horizontalVelocity < -2.5) return 3;
        return ((long)Math.Floor(time / IdleWrigglePeriod)) % 2 == 0 ? 0 : 2;
    }

    public static Point DangleBodyOffset(double horizontalVelocity, double horizontalAcceleration, double time)
    {
        if (Math.Abs(horizontalVelocity) > 2.5 || Math.Abs(horizontalAcceleration) > 2)
        {
            var inertial = -horizontalVelocity * 0.18 - horizontalAcceleration * 0.32;
            return new Point(Clamp(inertial, -MaxDangleOffsetX, MaxDangleOffsetX), 0);
        }
        var phase = time / IdleWrigglePeriod * 2 * Math.PI;
        var verticalPhase = time / 0.21 * 2 * Math.PI;
        return new Point(Math.Sin(phase) * 0.8, Math.Abs(Math.Sin(verticalPhase)) * 3.2);
    }

    public static Point TopPinnedDragOrigin(Point pointer, Size size) =>
        new(pointer.X - size.Width / 2, pointer.Y - size.Height + DefaultPinOffsetY);

    public static double LandingDuration(double drop) => Math.Min(0.45, Math.Max(0.12, drop * 0.0006));

    public static double LandingDistance(double originY, double floorY) => Math.Abs(originY - floorY);

    public static double WalkJumpVelocity(double heightDelta) =>
        Math.Sqrt(2 * WalkGravity * Math.Max(0, heightDelta + WalkStepJumpPadding));

    public readonly record struct VerticalMotionStep(double OriginY, double VerticalVelocity, bool IsGrounded, bool DidLaunch);

    public static VerticalMotionStep WalkVerticalMotionStep(
        double originY, double verticalVelocity, double previousFloorY, double targetFloorY, double deltaTime)
    {
        var dt = Math.Max(0, Math.Min(deltaTime, 1.0 / 20.0));
        var wasGrounded = Math.Abs(originY - previousFloorY) <= 0.75 && Math.Abs(verticalVelocity) < 1;
        var y = originY;
        var velocity = verticalVelocity;
        var didLaunch = false;

        if (wasGrounded)
        {
            var floorDelta = targetFloorY - previousFloorY;
            if (floorDelta > 1)
            {
                velocity = WalkJumpVelocity(floorDelta);
                didLaunch = true;
            }
            else if (floorDelta < -1)
            {
                velocity = WalkDropHopVelocity;
                didLaunch = true;
            }
        }

        y += velocity * dt - 0.5 * WalkGravity * dt * dt;
        velocity -= WalkGravity * dt;

        if (y <= targetFloorY && velocity <= 0)
            return new VerticalMotionStep(targetFloorY, 0, true, didLaunch);
        return new VerticalMotionStep(y, velocity, false, didLaunch);
    }

    public static double FloorY(Rect visibleFrame, double margin) => visibleFrame.MinY + margin;

    public static double SupportFloorY(double originX, Size size, Rect screenFrame, Rect visibleFrame, Rect? dockFrame, double margin)
    {
        var screenFloor = screenFrame.MinY + margin;
        if (dockFrame is not Rect dock || dock.Height <= 1 || dock.MinY > screenFrame.MinY + margin + 1)
            return screenFloor;

        var footRect = new Rect(originX + size.Width * 0.28, dock.MinY, size.Width * 0.44, dock.Height);
        return footRect.Intersects(dock.InsetBy(-margin, 0)) ? dock.MaxY + margin : screenFloor;
    }

    public static Point ClampedOrigin(Point origin, Size size, Rect visibleFrame) => new(
        Clamp(origin.X, visibleFrame.MinX, visibleFrame.MaxX - size.Width),
        Clamp(origin.Y, visibleFrame.MinY, visibleFrame.MaxY - size.Height));

    public static Point ClampedDragOrigin(Point origin, Size size, Rect visibleFrame, double floorMargin)
    {
        var floor = FloorY(visibleFrame, floorMargin);
        return new Point(
            Clamp(origin.X, visibleFrame.MinX, visibleFrame.MaxX - size.Width),
            Clamp(origin.Y, floor, visibleFrame.MaxY - size.Height));
    }

    private static double Clamp(double value, double min, double max) => Math.Max(min, Math.Min(value, max));
}
