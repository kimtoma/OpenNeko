using System;
using System.Diagnostics;
using OpenNeko.Windows.Native;

namespace OpenNeko.Windows.Services;

/// <summary>
/// Global keydown listener. PRIVACY INVARIANT: the hook only looks at the message
/// type (keydown vs. other). It never reads lParam (the KBDLLHOOKSTRUCT holding the
/// virtual key / scan code), and never stores or transmits key contents.
/// The callback runs on the UI thread that installed the hook.
/// </summary>
internal sealed class KeyboardHook : IDisposable
{
    private readonly Action _onKeyDown;
    private readonly NativeMethods.LowLevelKeyboardProc _proc; // keep the delegate alive
    private IntPtr _hook = IntPtr.Zero;

    public KeyboardHook(Action onKeyDown)
    {
        _onKeyDown = onKeyDown;
        _proc = HookCallback;
    }

    public bool IsActive => _hook != IntPtr.Zero;

    public bool Start()
    {
        if (IsActive) return true;
        using var module = Process.GetCurrentProcess().MainModule;
        _hook = NativeMethods.SetWindowsHookEx(NativeMethods.WH_KEYBOARD_LL, _proc, NativeMethods.GetModuleHandle(module?.ModuleName), 0);
        return IsActive;
    }

    public void Dispose()
    {
        if (_hook == IntPtr.Zero) return;
        NativeMethods.UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var message = wParam.ToInt32();
            if (message is NativeMethods.WM_KEYDOWN or NativeMethods.WM_SYSKEYDOWN)
            {
                try { _onKeyDown(); }
                catch { /* never let the app break the user's keyboard */ }
            }
        }
        return NativeMethods.CallNextHookEx(_hook, nCode, wParam, lParam);
    }
}
