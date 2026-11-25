using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using OpenNeko.Core;
using CoreRect = OpenNeko.Core.Rect;

namespace OpenNeko.Windows.UI;

/// <summary>Chat input above the cat with slash-command suggestions (counterpart of CatChatWindow.swift).</summary>
internal sealed class ChatWindow : FloatingWindow
{
    private readonly TextBox _input = new()
    {
        FontSize = 13,
        BorderThickness = new Thickness(0),
        Background = Brushes.Transparent,
        VerticalContentAlignment = VerticalAlignment.Center,
        Padding = new Thickness(4, 0, 4, 0),
        MaxLength = 6000,
    };
    private readonly TextBlock _placeholder = new()
    {
        FontSize = 13,
        Foreground = new SolidColorBrush(Color.FromRgb(0x9A, 0x9A, 0x9A)),
        IsHitTestVisible = false,
        VerticalAlignment = VerticalAlignment.Center,
        Margin = new Thickness(8, 0, 0, 0),
    };
    private readonly ListBox _suggestions = new()
    {
        BorderThickness = new Thickness(0),
        Background = Brushes.Transparent,
        MaxHeight = 150,
        Visibility = Visibility.Collapsed,
        Focusable = false,
    };
    private readonly Func<IReadOnlyList<SlashCommandDescriptor>> _slashCommands;

    public ChatWindow(Func<IReadOnlyList<SlashCommandDescriptor>> slashCommands) : base(noActivate: false)
    {
        _slashCommands = slashCommands;
        var send = new Button
        {
            Content = "➤",
            Width = 28,
            Height = 28,
            BorderThickness = new Thickness(0),
            Background = new SolidColorBrush(Color.FromRgb(0xFF, 0x9F, 0x43)),
            Foreground = Brushes.White,
            Cursor = Cursors.Hand,
        };
        send.Click += (_, _) => Submit();
        var close = new Button
        {
            Content = "✕",
            Width = 22,
            Height = 22,
            BorderThickness = new Thickness(0),
            Background = Brushes.Transparent,
            Foreground = Brushes.Gray,
            Cursor = Cursors.Hand,
            Margin = new Thickness(0, 0, 4, 0),
        };
        close.Click += (_, _) => HideChat();

        var inputGrid = new Grid { Height = 30 };
        inputGrid.Children.Add(_input);
        inputGrid.Children.Add(_placeholder);
        var row = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(close, Dock.Left);
        DockPanel.SetDock(send, Dock.Right);
        row.Children.Add(close);
        row.Children.Add(send);
        row.Children.Add(inputGrid);

        var stack = new StackPanel();
        stack.Children.Add(_suggestions);
        stack.Children.Add(row);
        Content = new Border
        {
            Width = FloatingLayout.ChatWidth,
            Background = Brushes.White,
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(8, 6, 6, 6),
            Margin = new Thickness(8),
            Child = stack,
            Effect = new DropShadowEffect { BlurRadius = 12, ShadowDepth = 2, Opacity = 0.2 },
        };

        _input.TextChanged += (_, _) => { UpdatePlaceholder(); UpdateSuggestions(); FrameChanged?.Invoke(); };
        _input.PreviewKeyDown += OnPreviewKeyDown;
        _suggestions.MouseLeftButtonUp += (_, _) => AcceptSuggestion();
    }

    public event Action<string>? Sent;
    public event Action? Cancelled;
    public event Action? FrameChanged;

    public void ShowChat(string placeholder)
    {
        _placeholder.Text = placeholder;
        UpdatePlaceholder();
        if (!IsVisible) Show();
        Activate();
        _input.Focus();
        Keyboard.Focus(_input);
    }

    public void HideChat()
    {
        _suggestions.Visibility = Visibility.Collapsed;
        Hide();
        FrameChanged?.Invoke();
    }

    public void Reposition(MonitorFrame monitor, CoreRect catFrame)
    {
        if (!IsVisible) return;
        MoveTo(monitor, FloatingLayout.ChatOrigin(catFrame, ContentSize(), monitor.LocalWork));
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        var suggesting = _suggestions.Visibility == Visibility.Visible && _suggestions.Items.Count > 0;
        switch (e.Key)
        {
            case Key.Escape:
                if (suggesting) _suggestions.Visibility = Visibility.Collapsed;
                else { HideChat(); Cancelled?.Invoke(); }
                e.Handled = true;
                break;
            case Key.Enter when (Keyboard.Modifiers & ModifierKeys.Shift) == 0:
                if (suggesting && _suggestions.SelectedIndex >= 0 && !_input.Text.Contains(' ')) AcceptSuggestion();
                else Submit();
                e.Handled = true;
                break;
            case Key.Tab when suggesting:
                AcceptSuggestion();
                e.Handled = true;
                break;
            case Key.Down when suggesting:
                _suggestions.SelectedIndex = Math.Min(_suggestions.Items.Count - 1, _suggestions.SelectedIndex + 1);
                e.Handled = true;
                break;
            case Key.Up when suggesting:
                _suggestions.SelectedIndex = Math.Max(0, _suggestions.SelectedIndex - 1);
                e.Handled = true;
                break;
        }
    }

    private void Submit()
    {
        var text = _input.Text;
        if (string.IsNullOrWhiteSpace(text)) return;
        _input.Clear();
        Sent?.Invoke(text);
    }

    private void UpdatePlaceholder() =>
        _placeholder.Visibility = _input.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void UpdateSuggestions()
    {
        var text = _input.Text;
        if (!text.StartsWith('/') || text.Contains(' '))
        {
            _suggestions.Visibility = Visibility.Collapsed;
            return;
        }
        var matches = SlashCommandParser.MatchingCommands(text[1..], _slashCommands());
        _suggestions.Items.Clear();
        foreach (var command in matches)
        {
            var item = new TextBlock { Margin = new Thickness(4, 2, 4, 2), Tag = command.Name };
            item.Inlines.Add(new System.Windows.Documents.Run("/" + command.Name) { FontWeight = FontWeights.SemiBold });
            item.Inlines.Add(new System.Windows.Documents.Run("  " + command.Description) { Foreground = Brushes.Gray });
            _suggestions.Items.Add(item);
        }
        _suggestions.Visibility = matches.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        if (matches.Count > 0) _suggestions.SelectedIndex = 0;
    }

    private void AcceptSuggestion()
    {
        if (_suggestions.SelectedItem is not TextBlock { Tag: string name }) return;
        _input.Text = "/" + name + " ";
        _input.CaretIndex = _input.Text.Length;
        _suggestions.Visibility = Visibility.Collapsed;
        _input.Focus();
    }
}
