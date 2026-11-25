using System;
using System.Linq;
using OpenNeko.Core;
using OpenNeko.Windows.Native;
using Forms = System.Windows.Forms;

namespace OpenNeko.Windows.UI;

/// <summary>
/// One monitor in the coordinate system the ported physics expects: local, y-up,
/// in device-independent units (1/96 inch), origin at the monitor's bottom-left.
/// Converts back to physical desktop pixels for SetWindowPos.
/// </summary>
internal sealed class MonitorFrame
{
    private MonitorFrame(Forms.Screen screen, double scale)
    {
        Screen = screen;
        Scale = scale;
        BoundsPx = ToRect(screen.Bounds);
        WorkPx = ToRect(screen.WorkingArea);
        var localWorkPx = ScreenSpace.LocalRect(WorkPx, BoundsPx);
        LocalBounds = new Rect(0, 0, BoundsPx.Width / scale, BoundsPx.Height / scale);
        LocalWork = new Rect(localWorkPx.X / scale, localWorkPx.Y / scale, localWorkPx.Width / scale, localWorkPx.Height / scale);
    }

    public Forms.Screen Screen { get; }
    public double Scale { get; }
    public Rect BoundsPx { get; }
    public Rect WorkPx { get; }
    public Rect LocalBounds { get; }
    public Rect LocalWork { get; }

    public static MonitorFrame ForPixelPoint(Point px)
    {
        var screen = Forms.Screen.FromPoint(new System.Drawing.Point((int)px.X, (int)px.Y));
        return new MonitorFrame(screen, ScaleFor(screen));
    }

    public static MonitorFrame Primary() => new(Forms.Screen.PrimaryScreen ?? Forms.Screen.AllScreens.First(), ScaleFor(Forms.Screen.PrimaryScreen ?? Forms.Screen.AllScreens.First()));

    public static Point CursorPx()
    {
        NativeMethods.GetCursorPos(out var p);
        return new Point(p.X, p.Y);
    }

    public Point LocalPoint(Point px)
    {
        var local = ScreenSpace.LocalPoint(px, BoundsPx);
        return new Point(local.X / Scale, local.Y / Scale);
    }

    public Point DesktopTopLeftPx(Point localOrigin, Size size) =>
        ScreenSpace.DesktopTopLeft(new Point(localOrigin.X * Scale, localOrigin.Y * Scale), new Size(size.Width * Scale, size.Height * Scale), BoundsPx);

    /// <summary>Local y-up DIP rect for a y-down physical-pixel desktop rect.</summary>
    public Rect LocalRectFromPx(Rect px)
    {
        var bottomLeft = LocalPoint(new Point(px.X, px.MaxY));
        return new Rect(bottomLeft.X, bottomLeft.Y, px.Width / Scale, px.Height / Scale);
    }

    public bool SameScreen(MonitorFrame other) => Screen.DeviceName == other.Screen.DeviceName;

    private static Rect ToRect(System.Drawing.Rectangle r) => new(r.X, r.Y, r.Width, r.Height);

    private static double ScaleFor(Forms.Screen screen)
    {
        try
        {
            var center = new NativeMethods.POINT { X = screen.Bounds.X + screen.Bounds.Width / 2, Y = screen.Bounds.Y + screen.Bounds.Height / 2 };
            var monitor = NativeMethods.MonitorFromPoint(center, NativeMethods.MONITOR_DEFAULTTONEAREST);
            if (NativeMethods.GetDpiForMonitor(monitor, 0, out var dpiX, out _) == 0 && dpiX > 0) return dpiX / 96.0;
        }
        catch (DllNotFoundException) { }
        catch (EntryPointNotFoundException) { }
        return 1.0;
    }
}
