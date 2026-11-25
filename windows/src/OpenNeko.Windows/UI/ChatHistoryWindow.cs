using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OpenNeko.Core;

namespace OpenNeko.Windows.UI;

/// <summary>Read-only chat transcript (counterpart of ChatHistoryWindowController.swift).</summary>
internal sealed class ChatHistoryWindow : Window
{
    private readonly StackPanel _list = new() { Margin = new Thickness(12) };
    private readonly Button _clear = new() { Padding = new Thickness(10, 4, 10, 4), Margin = new Thickness(12, 0, 12, 12), HorizontalAlignment = HorizontalAlignment.Right };

    public ChatHistoryWindow(Action onClear)
    {
        Width = 420;
        Height = 560;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Icon = AppIcon.Image();
        _clear.Click += (_, _) => onClear();
        var dock = new DockPanel();
        DockPanel.SetDock(_clear, Dock.Bottom);
        dock.Children.Add(_clear);
        dock.Children.Add(new ScrollViewer { Content = _list, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        Content = dock;
    }

    public void Render(IReadOnlyList<ChatMessage> messages, string lang)
    {
        Title = "OpenNeko — " + WindowsCopy.Get(WindowsCopyKey.ChatHistory, lang).TrimEnd('.');
        _clear.Content = WindowsCopy.Get(WindowsCopyKey.ClearHistory, lang);
        _list.Children.Clear();
        if (messages.Count == 0)
        {
            _list.Children.Add(new TextBlock { Text = WindowsCopy.Get(WindowsCopyKey.NoHistory, lang), Foreground = Brushes.Gray });
            return;
        }
        foreach (var message in messages)
        {
            var mine = message.Role == ChatRole.User;
            _list.Children.Add(new Border
            {
                Background = new SolidColorBrush(mine ? Color.FromRgb(0xFF, 0xE8, 0xD1) : Color.FromRgb(0xF2, 0xF2, 0xF2)),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(10, 6, 10, 6),
                Margin = new Thickness(mine ? 40 : 0, 4, mine ? 0 : 40, 4),
                HorizontalAlignment = mine ? HorizontalAlignment.Right : HorizontalAlignment.Left,
                Child = new TextBox { Text = message.Text, TextWrapping = TextWrapping.Wrap, IsReadOnly = true, BorderThickness = new Thickness(0), Background = Brushes.Transparent },
            });
        }
    }
}
