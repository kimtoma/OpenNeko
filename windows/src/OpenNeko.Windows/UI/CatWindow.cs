using System;
using System.Diagnostics;
using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using OpenNeko.Core;
using OpenNeko.Windows.Native;
using OpenNeko.Windows.Services;
using CorePoint = OpenNeko.Core.Point;
using CoreSize = OpenNeko.Core.Size;
using CoreRect = OpenNeko.Core.Rect;

namespace OpenNeko.Windows.UI;

/// <summary>
/// The transparent, always-on-top cat. Counterpart of App/CatWindow.swift: positioning
/// on the taskbar "floor", drag with dangle, drop and fall, autonomous walking,
/// hover, and applying bridge/agent/chat states.
/// Positions are kept in monitor-local y-up DIPs so the ported physics is unchanged.
/// </summary>
internal sealed class CatWindow : Window
{
    private const double CatHitPadding = 8;
    private readonly CoreSize _catSize = CatLayoutMetrics.PrimaryCatSize;
    private readonly double _floorMargin = CatLayoutMetrics.FloorPadding;
    private readonly SpriteView _sprite = new();
    private readonly CatSoundPlayer _sound = new();
    private readonly Stopwatch _clock = Stopwatch.StartNew();
    private readonly DispatcherTimer _dragVisualTimer = new(DispatcherPriority.Render) { Interval = TimeSpan.FromMilliseconds(1000.0 / 60) };
    private readonly DispatcherTimer _landingTimer = new(DispatcherPriority.Render) { Interval = TimeSpan.FromMilliseconds(1000.0 / 60) };

    private MonitorFrame _monitor = MonitorFrame.Primary();
    private CorePoint _origin;
    private bool _typingActive;
    private double _typingSpeed = 1.0;
    private bool _dragging;
    private bool _mouseDown;
    private CorePoint _dragStartPx;
    private double? _lastDragMouseX;
    private double _dragVelocity;
    private double _dragAcceleration;
    private double _autonomousVerticalVelocity;
    private bool _autonomousAirborne;
    private (CorePoint From, CorePoint To, double Duration, bool Falling, double Start)? _landing;

    public CatWindow()
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        Width = _catSize.Width;
        Height = _catSize.Height;
        Title = "OpenNeko";
        Content = _sprite;
        WindowStartupLocation = WindowStartupLocation.Manual;

        MouseLeftButtonDown += OnMouseDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseUp;
        MouseRightButtonUp += (_, e) => { CancelPendingDrag(); ContextMenuRequested?.Invoke(); e.Handled = true; };
        MouseEnter += (_, _) => SetHovering(true);
        MouseLeave += (_, _) => SetHovering(false);
        _dragVisualTimer.Tick += (_, _) => TickDragVisual();
        _landingTimer.Tick += (_, _) => TickLanding();
        SourceInitialized += (_, _) => OverlayWindowPolicy.Apply(this, noActivate: true);
        Closed += (_, _) => _sprite.Detach();
    }

    public event Action? Clicked;
    public event Action? ContextMenuRequested;
    public event Action? UserInteraction;
    public event Action? PositionChanged;

    public bool SoundEffectsEnabled { get; set; } = true;
    public Func<bool> IsChatVisible { get; set; } = () => false;
    public CatState CurrentState => _sprite.DisplayedState;
    public bool IsAutonomousMotionSettling => _autonomousAirborne;
    public IntPtr Handle => new WindowInteropHelper(this).Handle;

    /// <summary>Cat rect in physical desktop pixels (y-down), for placing the bubble and chat.</summary>
    public System.Windows.Rect ScreenRectPx
    {
        get
        {
            var topLeft = _monitor.DesktopTopLeftPx(_origin, _catSize);
            return new System.Windows.Rect(topLeft.X, topLeft.Y, _catSize.Width * _monitor.Scale, _catSize.Height * _monitor.Scale);
        }
    }

    public MonitorFrame Monitor => _monitor;

    /// <summary>Cat rect in the monitor's local y-up DIP space (what FloatingLayout expects).</summary>
    public CoreRect LocalFrame => new(_origin.X, _origin.Y, _catSize.Width, _catSize.Height);

    public void ShowCat(Skin skin)
    {
        ApplySkin(skin);
        Show();
        PositionBottomRight();
    }

    public void ApplySkin(Skin skin)
    {
        _sprite.Apply(skin);
        PlayRestingState();
    }

    public void Toggle()
    {
        if (IsVisible)
        {
            Hide();
            return;
        }
        Show();
        // Coming back always resets to the default spot (the "lost cat" recovery path).
        PositionBottomRight();
        _sprite.Play(CatState.Idle);
    }

    public void SetAlwaysOnTop(bool enabled) => Topmost = enabled;

    public bool CanStartAutonomousAction() =>
        IsVisible && !_dragging && !IsChatVisible() && CurrentState is CatState.Idle or CatState.Hover or CatState.Walk;

    public bool CanContinueAutonomousWalk() => IsVisible && !_dragging && !IsChatVisible();

    public void PlayAutonomousState(CatState state)
    {
        if (_dragging) return;
        ResetAutonomousMotion();
        _typingActive = false;
        if (NekoStatePriority.OneShotStates.Contains(state)) _sprite.PlayOnce(state);
        else _sprite.Play(state);
    }

    public void StopAutonomousWalk()
    {
        if (CurrentState == CatState.Walk) _sprite.Play(CatState.Idle);
        ResetAutonomousMotion();
    }

    public int AutonomousWalkStep(int direction, double distance, double deltaTime)
    {
        if (!CanContinueAutonomousWalk() || !(CanStartAutonomousAction() || CurrentState == CatState.Walk)) return direction;
        var next = direction == 0 ? 1 : direction;
        _sprite.PlayWalk(next);
        var work = _monitor.LocalWork;
        var origin = _origin;
        var previousFloor = FloorY();
        origin = origin with { X = origin.X + next * distance };
        if (origin.X <= work.MinX) { origin = origin with { X = work.MinX }; next = 1; }
        else if (origin.X >= work.MaxX - _catSize.Width) { origin = origin with { X = work.MaxX - _catSize.Width }; next = -1; }
        var targetFloor = FloorY();
        var vertical = CatDragGeometry.WalkVerticalMotionStep(origin.Y, _autonomousVerticalVelocity, previousFloor, targetFloor, deltaTime);
        var wasAirborne = _autonomousAirborne;
        _autonomousVerticalVelocity = vertical.VerticalVelocity;
        _autonomousAirborne = !vertical.IsGrounded;
        origin = origin with { Y = vertical.OriginY };
        _sprite.PlayWalk(next);
        SetOrigin(origin);
        if (vertical.DidLaunch) PlaySound(CatSoundEffect.Pluck);
        if (wasAirborne && vertical.IsGrounded)
        {
            _sprite.LandingSquash();
            PlaySound(CatSoundEffect.Land);
        }
        return next;
    }

    public void SetTypingActive(bool active, double animationSpeed = 1.0)
    {
        _typingSpeed = active ? animationSpeed : 1.0;
        _sprite.SetTypingSpeed(_typingSpeed);
        _typingActive = active;
        if (_dragging) return;
        ResetAutonomousMotion();
        PlayRestingState();
    }

    public void UpdateTypingSpeed(double speed)
    {
        _typingSpeed = speed;
        _sprite.SetTypingSpeed(speed);
    }

    public void ApplyBridgeState(CatState state)
    {
        if (_dragging) return;
        ResetAutonomousMotion();
        if (state == CatState.Idle)
        {
            _typingActive = false;
            _typingSpeed = 1.0;
            _sprite.SetTypingSpeed(1.0);
            _sprite.Play(CatState.Idle);
        }
        else if (state == CatState.Typing)
        {
            _typingActive = true;
            _sprite.SetTypingSpeed(_typingSpeed);
            _sprite.Play(CatState.Typing);
        }
        else if (NekoStatePriority.OneShotStates.Contains(state))
        {
            if (state == CatState.Success) PlaySound(CatSoundEffect.Success);
            else if (state == CatState.Error) PlaySound(CatSoundEffect.Error);
            _sprite.PlayOnce(state);
        }
        else
        {
            _typingActive = false;
            _typingSpeed = 1.0;
            _sprite.SetTypingSpeed(1.0);
            _sprite.Play(state);
        }
    }

    public void PlayChirp() => PlaySound(CatSoundEffect.Chirp);

    public byte[]? CapturePng() => IsVisible ? _sprite.CapturePng() : null;

    public string PositionDebugJson()
    {
        static string N(double v) => v.ToString("0.00", CultureInfo.InvariantCulture);
        var work = _monitor.WorkPx;
        var bounds = _monitor.BoundsPx;
        var cat = ScreenRectPx;
        return "{\"workArea\":{\"x\":" + N(work.X) + ",\"y\":" + N(work.Y) + ",\"width\":" + N(work.Width) + ",\"height\":" + N(work.Height) + "}," +
               "\"displayBounds\":{\"x\":" + N(bounds.X) + ",\"y\":" + N(bounds.Y) + ",\"width\":" + N(bounds.Width) + ",\"height\":" + N(bounds.Height) + "}," +
               "\"dockRect\":null,\"scale\":" + N(_monitor.Scale) + ",\"winX\":" + N(cat.X) + ",\"winY\":" + N(cat.Y) + "," +
               "\"catBounds\":{\"x\":" + N(cat.X) + ",\"y\":" + N(cat.Y) + ",\"width\":" + N(cat.Width) + ",\"height\":" + N(cat.Height) + "}}";
    }

    // ---- positioning ----

    private double FloorY() => CatDragGeometry.FloorY(_monitor.LocalWork, _floorMargin);

    private void PositionBottomRight()
    {
        _monitor = MonitorFrame.Primary();
        var work = _monitor.LocalWork;
        ResetAutonomousMotion();
        SetOrigin(new CorePoint(work.MaxX - _catSize.Width - _floorMargin, FloorY()));
    }

    private void SetOrigin(CorePoint origin)
    {
        _origin = origin;
        var handle = Handle;
        if (handle == IntPtr.Zero) return;
        var topLeft = _monitor.DesktopTopLeftPx(origin, _catSize);
        NativeMethods.SetWindowPos(handle, IntPtr.Zero, (int)Math.Round(topLeft.X), (int)Math.Round(topLeft.Y), 0, 0,
            NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOZORDER | NativeMethods.SWP_NOACTIVATE);
        PositionChanged?.Invoke();
    }

    private void ResetAutonomousMotion()
    {
        _autonomousVerticalVelocity = 0;
        _autonomousAirborne = false;
    }

    private void PlayRestingState()
    {
        _sprite.SetTypingSpeed(_typingSpeed);
        _sprite.Play(_typingActive ? CatState.Typing : CatState.Idle);
    }

    private void SetHovering(bool hovering)
    {
        if (_dragging || _typingActive || IsChatVisible()) return;
        if (hovering && CurrentState == CatState.Idle) _sprite.Play(CatState.Hover);
        else if (!hovering && CurrentState == CatState.Hover) _sprite.Play(CatState.Idle);
    }

    // ---- click / drag / drop ----

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        _mouseDown = true;
        _dragStartPx = MonitorFrame.CursorPx();
        CaptureMouse();
        e.Handled = true;
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (!_mouseDown) return;
        var cursorPx = MonitorFrame.CursorPx();
        if (!_dragging)
        {
            var scale = _monitor.Scale;
            var start = new CorePoint(_dragStartPx.X / scale, _dragStartPx.Y / scale);
            var current = new CorePoint(cursorPx.X / scale, cursorPx.Y / scale);
            if (!CatDragGeometry.HasDraggedBeyondStartDistance(start, current)) return;
            BeginDrag(cursorPx);
        }
        DragMoved(cursorPx);
    }

    private void OnMouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!_mouseDown) return;
        _mouseDown = false;
        ReleaseMouseCapture();
        if (_dragging) DropAndFall();
        else HandleClick();
        e.Handled = true;
    }

    private void CancelPendingDrag()
    {
        if (_dragging) DropAndFall();
        _mouseDown = false;
        ReleaseMouseCapture();
    }

    private void HandleClick()
    {
        UserInteraction?.Invoke();
        PlaySound(CatSoundEffect.Chirp);
        _sprite.PlayOnce(CatState.Click);
        Clicked?.Invoke();
    }

    private void BeginDrag(CorePoint cursorPx)
    {
        UserInteraction?.Invoke();
        _landingTimer.Stop();
        _landing = null;
        ResetAutonomousMotion();
        _dragging = true;
        _lastDragMouseX = null;
        _dragVelocity = 0;
        _dragAcceleration = 0;
        PlaySound(CatSoundEffect.Pluck);
        UpdateDraggedPosition(cursorPx);
        UpdateDragVisual();
        _dragVisualTimer.Start();
    }

    private void DragMoved(CorePoint cursorPx)
    {
        var mouseX = cursorPx.X / _monitor.Scale;
        if (_lastDragMouseX is double previous)
        {
            var previousVelocity = _dragVelocity;
            _dragVelocity = CatDragGeometry.SmoothedHorizontalVelocity(_dragVelocity, previous, mouseX);
            _dragAcceleration = CatDragGeometry.SmoothedHorizontalAcceleration(_dragAcceleration, previousVelocity, _dragVelocity);
        }
        _lastDragMouseX = mouseX;
        UpdateDraggedPosition(cursorPx);
        UpdateDragVisual();
    }

    private void UpdateDraggedPosition(CorePoint cursorPx)
    {
        var monitor = MonitorFrame.ForPixelPoint(cursorPx);
        if (!monitor.SameScreen(_monitor)) _monitor = monitor;
        var local = _monitor.LocalPoint(cursorPx);
        var next = CatDragGeometry.TopPinnedDragOrigin(local, _catSize);
        next = CatDragGeometry.ClampedDragOrigin(next, _catSize, _monitor.LocalWork, _floorMargin);
        SetOrigin(next);
    }

    private void TickDragVisual()
    {
        var previousVelocity = _dragVelocity;
        _dragVelocity = CatDragGeometry.DecayedHorizontalVelocity(_dragVelocity);
        _dragAcceleration = CatDragGeometry.SmoothedHorizontalAcceleration(_dragAcceleration, previousVelocity, _dragVelocity);
        UpdateDragVisual();
    }

    private void UpdateDragVisual() => _sprite.ShowDragging(_dragVelocity, _dragAcceleration, _clock.Elapsed.TotalSeconds);

    private void StopDragVisual()
    {
        _dragVisualTimer.Stop();
        _lastDragMouseX = null;
        _dragVelocity = 0;
        _dragAcceleration = 0;
    }

    /// <summary>Falls from the drop point to the floor with acceleration, then squashes on landing.</summary>
    private void DropAndFall()
    {
        StopDragVisual();
        var origin = _origin;
        var floor = FloorY();
        var distance = CatDragGeometry.LandingDistance(origin.Y, floor);
        if (distance <= 1)
        {
            SetOrigin(origin with { Y = floor });
            FinishLanding();
            return;
        }
        _sprite.ShowFalling();
        _landing = (origin, origin with { Y = floor }, CatDragGeometry.LandingDuration(distance), origin.Y >= floor, _clock.Elapsed.TotalSeconds);
        _landingTimer.Start();
    }

    private void TickLanding()
    {
        if (_landing is not { } landing) { _landingTimer.Stop(); return; }
        var (from, to, duration, falling, start) = landing;
        var p = Math.Min(1, (_clock.Elapsed.TotalSeconds - start) / duration);
        var eased = falling ? p * p : 1 - Math.Pow(1 - p, 2);
        SetOrigin(new CorePoint(to.X, from.Y + (to.Y - from.Y) * eased));
        if (p < 1) return;
        _landingTimer.Stop();
        _landing = null;
        SetOrigin(to);
        FinishLanding();
    }

    private void FinishLanding()
    {
        _dragging = false;
        ResetAutonomousMotion();
        PlayRestingState();
        _sprite.LandingSquash();
        PlaySound(CatSoundEffect.Land);
    }

    private void PlaySound(CatSoundEffect effect)
    {
        if (SoundEffectsEnabled) _sound.Play(effect);
    }
}
