using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using OpenNeko.Core;
using CorePoint = OpenNeko.Core.Point;

namespace OpenNeko.Windows.UI;

/// <summary>
/// Renders the cat sprite with per-state frame animation, walk bob, jump lift,
/// landing squash and drag dangle. Counterpart of App/CatScene.swift (SpriteKit).
/// Coordinates here are WPF's (y-down) inside a 128x128 canvas.
/// </summary>
internal sealed class SpriteView : Canvas
{
    private readonly double _size = CatLayoutMetrics.SpriteFrameLength;
    private readonly Image _sprite = new();
    private readonly Ellipse _shadow = new() { Width = 76, Height = 9, Fill = new SolidColorBrush(Color.FromArgb(41, 0, 0, 0)) };
    private readonly ScaleTransform _scale = new(1, 1);
    private readonly RotateTransform _rotate = new(0);
    private readonly TranslateTransform _translate = new(0, 0);
    private readonly Dictionary<string, BitmapSource?> _cache = new();

    private Skin? _skin;
    private CatState? _current;
    private BitmapSource[] _frames = Array.Empty<BitmapSource>();
    private double _timePerFrame = 0.18;
    private double _phase;
    private bool _loop = true;
    private bool _walkBob;
    private bool _jumpLift;
    private double _effectTime;
    private double _squashTime = -1;
    private double _typingSpeed = 1.0;
    private int _flip = 1;
    private TimeSpan? _lastRender;

    public SpriteView()
    {
        Width = _size;
        Height = _size;
        // Nearly transparent fill keeps the whole cat square clickable (the macOS hit box).
        Background = new SolidColorBrush(Color.FromArgb(1, 255, 255, 255));
        SnapsToDevicePixels = true;
        RenderOptions.SetBitmapScalingMode(_sprite, BitmapScalingMode.NearestNeighbor);
        _sprite.Width = _size;
        _sprite.Height = _size;
        _sprite.RenderTransform = new TransformGroup { Children = { _scale, _rotate, _translate } };
        SetLeft(_shadow, (_size - _shadow.Width) / 2);
        SetTop(_shadow, _size - 5 - _shadow.Height / 2);
        Children.Add(_shadow);
        Children.Add(_sprite);
        CompositionTarget.Rendering += OnRendering;
    }

    public CatState DisplayedState => _current ?? CatState.Idle;

    public void Detach() => CompositionTarget.Rendering -= OnRendering;

    public void Apply(Skin skin)
    {
        _skin = skin;
        _cache.Clear();
        _current = null;
        Play(CatState.Idle);
    }

    public IReadOnlyList<string> FramePaths(CatState state) => _skin?.FramePaths(state.RawValue()) ?? Array.Empty<string>();

    /// <summary>Loops a state; no-op when already playing it (like CatScene.play).</summary>
    public void Play(CatState state)
    {
        if (state == _current) { ApplySpeed(); return; }
        var frames = Load(state);
        if (frames.Length == 0) return; // keep the current frames when a skin lacks this state
        Start(state, frames, loop: true);
        _walkBob = state == CatState.Walk;
        _shadow.Visibility = state == CatState.Dragging ? Visibility.Hidden : Visibility.Visible;
    }

    public void PlayWalk(int direction)
    {
        Play(CatState.Walk);
        _flip = direction < 0 ? -1 : 1;
        _scale.ScaleX = _flip;
    }

    /// <summary>Plays once and returns to idle (click, yawn, success, error, jump).</summary>
    public void PlayOnce(CatState state)
    {
        var frames = Load(state);
        if (frames.Length == 0) return;
        Start(state, frames, loop: false);
        _shadow.Visibility = Visibility.Visible;
        _jumpLift = state == CatState.Jump;
    }

    public void SetTypingSpeed(double speed)
    {
        _typingSpeed = CatAnimationTiming.ClampedTypingSpeed(speed);
    }

    public void ShowDragging(double velocity, double acceleration, double time)
    {
        var frames = Load(CatState.Dragging);
        if (frames.Length == 0) return;
        if (_current != CatState.Dragging || _loop) Start(CatState.Dragging, frames, loop: false, paused: true);
        _shadow.Visibility = Visibility.Hidden;
        var index = Math.Min(CatDragGeometry.DangleFrameIndex(velocity, acceleration, time), frames.Length - 1);
        _sprite.Source = frames[index];
        var offset = CatDragGeometry.DangleBodyOffset(velocity, acceleration, time);
        PinForDragging(offset, CatDragGeometry.DangleSwingAngle(velocity, acceleration, time));
    }

    public void ShowFalling()
    {
        var frames = Load(CatState.Dragging);
        if (frames.Length == 0) { Play(CatState.Dragging); return; }
        Start(CatState.Dragging, frames, loop: false, paused: true);
        _shadow.Visibility = Visibility.Hidden;
        _sprite.Source = frames[0];
        PinForDragging(CorePoint.Zero, 0);
    }

    public void LandingSquash()
    {
        _shadow.Visibility = Visibility.Visible;
        ResetTransform();
        _sprite.RenderTransformOrigin = new System.Windows.Point(0.5, 1);
        _squashTime = 0;
    }

    public byte[]? CapturePng()
    {
        var dpi = VisualTreeHelper.GetDpi(this);
        var bitmap = new RenderTargetBitmap((int)Math.Ceiling(_size * dpi.DpiScaleX), (int)Math.Ceiling(_size * dpi.DpiScaleY),
            dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
        bitmap.Render(this);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new MemoryStream();
        encoder.Save(stream);
        return stream.ToArray();
    }

    private void Start(CatState state, BitmapSource[] frames, bool loop, bool paused = false)
    {
        _current = state;
        _frames = frames;
        _loop = loop;
        _phase = paused ? double.NaN : 0;
        _timePerFrame = CatAnimationTiming.TimePerFrame(state);
        _walkBob = false;
        _jumpLift = false;
        _effectTime = 0;
        _squashTime = -1;
        ResetTransform();
        _sprite.Source = frames[0];
    }

    private void ApplySpeed() { /* speed is read every frame */ }

    private void ResetTransform()
    {
        _sprite.RenderTransformOrigin = new System.Windows.Point(0.5, 0.5);
        _rotate.Angle = 0;
        _scale.ScaleX = _current == CatState.Walk ? _flip : 1;
        _scale.ScaleY = 1;
        _translate.X = 0;
        _translate.Y = 0;
        SetLeft(_sprite, 0);
        SetTop(_sprite, 0);
    }

    private void PinForDragging(CorePoint offset, double radians)
    {
        // macOS pins the sprite's top-center 4pt below the window top (y-up offset).
        _sprite.RenderTransformOrigin = new System.Windows.Point(0.5, 0);
        _scale.ScaleX = 1;
        _scale.ScaleY = 1;
        _translate.X = offset.X;
        _translate.Y = CatDragGeometry.DefaultPinOffsetY - offset.Y;
        // SpriteKit's zRotation is counter-clockwise; WPF's angle is clockwise.
        _rotate.Angle = -radians * 180 / Math.PI;
    }

    private void OnRendering(object? sender, EventArgs e)
    {
        var now = ((RenderingEventArgs)e).RenderingTime;
        var dt = _lastRender is TimeSpan last ? Math.Min(0.1, (now - last).TotalSeconds) : 0;
        _lastRender = now;
        if (dt <= 0 || _frames.Length == 0) return;

        if (!double.IsNaN(_phase))
        {
            var speed = _current == CatState.Typing ? _typingSpeed : 1.0;
            _phase += dt * speed / _timePerFrame;
            var index = (int)Math.Floor(_phase);
            if (_loop) index %= _frames.Length;
            if (!_loop && index >= _frames.Length)
            {
                _current = null;
                Play(CatState.Idle);
                return;
            }
            _sprite.Source = _frames[index];
        }

        _effectTime += dt;
        if (_walkBob)
        {
            var cycle = _effectTime % 0.24;
            _translate.Y = cycle < 0.12 ? cycle / 0.12 * 2 : (0.24 - cycle) / 0.12 * 2;
        }
        if (_jumpLift)
        {
            var t = _effectTime;
            double lift;
            if (t < 0.18) { var p = t / 0.18; lift = 23 * (1 - (1 - p) * (1 - p)); }
            else if (t < 0.38) { var p = (t - 0.18) / 0.20; lift = 23 * (1 - p * p); }
            else lift = 0;
            _translate.Y = -lift;
        }
        if (_squashTime >= 0)
        {
            _squashTime += dt;
            if (_squashTime < 0.06)
            {
                var p = _squashTime / 0.06;
                _scale.ScaleX = 1 + 0.12 * p;
                _scale.ScaleY = 1 - 0.12 * p;
            }
            else if (_squashTime < 0.16)
            {
                var p = (_squashTime - 0.06) / 0.10;
                var eased = 1 - (1 - p) * (1 - p);
                _scale.ScaleX = 1.12 - 0.12 * eased;
                _scale.ScaleY = 0.88 + 0.12 * eased;
            }
            else
            {
                _squashTime = -1;
                ResetTransform();
            }
        }
    }

    private BitmapSource[] Load(CatState state)
    {
        if (_skin is null) return Array.Empty<BitmapSource>();
        return _skin.FramePaths(state.RawValue()).Select(LoadFrame).Where(b => b is not null).Cast<BitmapSource>().ToArray();
    }

    private BitmapSource? LoadFrame(string path)
    {
        if (_cache.TryGetValue(path, out var cached)) return cached;
        BitmapSource? image = null;
        try
        {
            if (File.Exists(path))
            {
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.UriSource = new Uri(path, UriKind.Absolute);
                bitmap.EndInit();
                bitmap.Freeze();
                image = bitmap;
            }
        }
        catch (Exception) { image = null; }
        _cache[path] = image;
        return image;
    }
}
