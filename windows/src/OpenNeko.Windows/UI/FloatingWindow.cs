using System;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using OpenNeko.Core;
using OpenNeko.Windows.Native;
using CorePoint = OpenNeko.Core.Point;
using CoreRect = OpenNeko.Core.Rect;
using CoreSize = OpenNeko.Core.Size;

namespace OpenNeko.Windows.UI;

/// <summary>Base for the bubble and chat: borderless, transparent, topmost overlay windows placed next to the cat.</summary>
internal abstract class FloatingWindow : Window
{
    protected FloatingWindow(bool noActivate)
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        ShowActivated = !noActivate;
        SizeToContent = SizeToContent.WidthAndHeight;
        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = -10000;
        Top = -10000;
        SourceInitialized += (_, _) => OverlayWindowPolicy.Apply(this, noActivate);
    }

    /// <summary>The window's current rect as local y-up DIPs of the cat's monitor.</summary>
    public CoreRect LocalFrame(MonitorFrame monitor) => new(CurrentOrigin.X, CurrentOrigin.Y, ActualWidth, ActualHeight);

    protected CorePoint CurrentOrigin { get; private set; }

    protected CoreSize ContentSize()
    {
        UpdateLayout();
        return new CoreSize(ActualWidth > 0 ? ActualWidth : DesiredSize.Width, ActualHeight > 0 ? ActualHeight : DesiredSize.Height);
    }

    protected void MoveTo(MonitorFrame monitor, CorePoint localOrigin)
    {
        CurrentOrigin = localOrigin;
        var hwnd = new WindowInteropHelper(this).Handle;
        if (hwnd == IntPtr.Zero) return;
        var px = monitor.DesktopTopLeftPx(localOrigin, ContentSize());
        NativeMethods.SetWindowPos(hwnd, IntPtr.Zero, (int)Math.Round(px.X), (int)Math.Round(px.Y), 0, 0,
            NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE);
    }
}
