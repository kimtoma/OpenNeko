using System;
using System.Windows;
using System.Windows.Interop;
using OpenNeko.Windows.Native;

namespace OpenNeko.Windows.UI;

/// <summary>
/// Overlay window rules (counterpart of OpenNekoOverlayWindowPolicy.swift):
/// hidden from Alt+Tab/taskbar, optionally non-activating, and excluded from screen
/// capture. The /capture route renders the cat itself, so it still works.
/// </summary>
internal static class OverlayWindowPolicy
{
    public static void Apply(Window window, bool noActivate)
    {
        var hwnd = new WindowInteropHelper(window).EnsureHandle();
        var style = NativeMethods.GetWindowLongPtr(hwnd, NativeMethods.GWL_EXSTYLE).ToInt64();
        style |= NativeMethods.WS_EX_TOOLWINDOW;
        style &= ~(long)NativeMethods.WS_EX_APPWINDOW;
        if (noActivate) style |= NativeMethods.WS_EX_NOACTIVATE;
        NativeMethods.SetWindowLongPtr(hwnd, NativeMethods.GWL_EXSTYLE, new IntPtr(style));
        // Windows 10 2004+; silently ignored on older builds.
        NativeMethods.SetWindowDisplayAffinity(hwnd, NativeMethods.WDA_EXCLUDEFROMCAPTURE);
    }
}
