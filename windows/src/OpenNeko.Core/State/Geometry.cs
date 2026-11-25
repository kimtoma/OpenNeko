namespace OpenNeko.Core;

// Minimal y-up geometry types (origin bottom-left), matching CoreGraphics so
// the ported macOS physics stays identical. The Windows shell converts to
// WPF's y-down coordinates at the edges (see ScreenSpace).
public readonly record struct Point(double X, double Y)
{
    public static readonly Point Zero = new(0, 0);
}

public readonly record struct Size(double Width, double Height);

public readonly record struct Rect(double X, double Y, double Width, double Height)
{
    public double MinX => X;
    public double MinY => Y;
    public double MaxX => X + Width;
    public double MaxY => Y + Height;
    public double MidX => X + Width / 2;

    public Rect InsetBy(double dx, double dy) => new(X + dx, Y + dy, Width - 2 * dx, Height - 2 * dy);

    public bool Contains(Point p) => p.X >= MinX && p.X < MaxX && p.Y >= MinY && p.Y < MaxY;

    public bool Intersects(Rect other) =>
        Width > 0 && Height > 0 && other.Width > 0 && other.Height > 0 &&
        MinX < other.MaxX && other.MinX < MaxX && MinY < other.MaxY && other.MinY < MaxY;
}

/// <summary>
/// Converts between a monitor-local y-up space (used by the ported physics) and
/// y-down desktop coordinates (used by WPF/Win32).
/// </summary>
public static class ScreenSpace
{
    /// <summary>Local y-up rect of an inner y-down rect (e.g. the work area) relative to the screen bounds.</summary>
    public static Rect LocalRect(Rect innerYDown, Rect screenYDown) => new(
        innerYDown.X - screenYDown.X,
        screenYDown.MaxY - innerYDown.MaxY,
        innerYDown.Width,
        innerYDown.Height);

    /// <summary>Top-left y-down desktop position of a window whose local y-up origin (bottom-left) is given.</summary>
    public static Point DesktopTopLeft(Point localOrigin, Size size, Rect screenYDown) => new(
        screenYDown.X + localOrigin.X,
        screenYDown.MaxY - localOrigin.Y - size.Height);

    /// <summary>Local y-up point for a y-down desktop point.</summary>
    public static Point LocalPoint(Point desktop, Rect screenYDown) => new(
        desktop.X - screenYDown.X,
        screenYDown.MaxY - desktop.Y);
}
