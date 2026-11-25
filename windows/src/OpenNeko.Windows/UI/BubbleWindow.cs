using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;
using OpenNeko.Core;
using CoreRect = OpenNeko.Core.Rect;

namespace OpenNeko.Windows.UI;

/// <summary>The small speech bubble above the cat (counterpart of CatBubbleWindow.swift).</summary>
internal sealed class BubbleWindow : FloatingWindow
{
    private readonly TextBlock _text = new()
    {
        FontSize = 12,
        FontWeight = FontWeights.Medium,
        TextWrapping = TextWrapping.Wrap,
        TextAlignment = TextAlignment.Center,
        Foreground = new SolidColorBrush(Color.FromRgb(0x2B, 0x2B, 0x2B)),
        MaxWidth = FloatingLayout.MaximumBubbleWidth - 24,
        MinWidth = FloatingLayout.MinimumBubbleWidth - 24,
    };
    private readonly DispatcherTimer _hideTimer = new();
    private Action? _onClick;
    private readonly Action? _defaultOnClick;

    public BubbleWindow(Action? defaultOnClick) : base(noActivate: true)
    {
        _defaultOnClick = defaultOnClick;
        var scroller = new ScrollViewer
        {
            Content = _text,
            MaxHeight = FloatingLayout.MaximumTextHeight,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
        };
        var bubble = new Border
        {
            Background = Brushes.White,
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(12, 8, 12, 8),
            MinHeight = FloatingLayout.MinimumTextHeight + 16,
            Child = scroller,
            Effect = new DropShadowEffect { BlurRadius = 10, ShadowDepth = 2, Opacity = 0.18 },
        };
        var tail = new Polygon
        {
            Points = new PointCollection { new(0, 0), new(16, 0), new(8, 8) },
            Fill = Brushes.White,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, -1, 0, 0),
        };
        var stack = new StackPanel { Margin = new Thickness(8, 6, 8, 2) };
        stack.Children.Add(bubble);
        stack.Children.Add(tail);
        Content = stack;
        Cursor = Cursors.Hand;
        MouseLeftButtonUp += (_, _) =>
        {
            var action = _onClick ?? _defaultOnClick;
            HideBubble();
            action?.Invoke();
        };
        _hideTimer.Tick += (_, _) => HideBubble();
    }

    public void ShowText(string text, Action? onClick, string? helpText)
    {
        _text.Text = string.IsNullOrEmpty(text) ? " " : text;
        _onClick = onClick;
        ToolTip = helpText;
        if (!IsVisible) Show();
        _hideTimer.Stop();
        _hideTimer.Interval = TimeSpan.FromSeconds(FloatingLayout.BubbleDuration(text));
        _hideTimer.Start();
    }

    public void HideBubble()
    {
        _hideTimer.Stop();
        Hide();
    }

    public void Reposition(MonitorFrame monitor, CoreRect catFrame, CoreRect? avoid)
    {
        if (!IsVisible) return;
        var origin = FloatingLayout.BubbleOrigin(catFrame, ContentSize(), monitor.LocalWork, avoid);
        MoveTo(monitor, origin);
    }
}
