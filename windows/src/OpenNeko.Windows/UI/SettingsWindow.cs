using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OpenNeko.Core;

namespace OpenNeko.Windows.UI;

/// <summary>Operations the Settings window needs from the app (keeps the window a thin view).</summary>
internal interface ISettingsHost
{
    AppSettings Settings { get; }
    string LanguageCode { get; }
    IReadOnlyList<string> SkinIds { get; }
    IReadOnlyList<NekoSkill> AllSkills { get; }
    void Update(Func<AppSettings, AppSettings> change);
    bool HasApiKey(string presetId);
    bool SaveApiKey(string presetId, string key);
    void ClearApiKey(string presetId);
    bool? CliAvailable(AIProviderType type);
    System.Threading.Tasks.Task<string> TestConnectionAsync();
    void OpenSkillsFolder();
    void OpenSkinsFolder();
}

/// <summary>Settings (counterpart of SettingsView.swift, trimmed to the Windows feature set).</summary>
internal sealed class SettingsWindow : Window
{
    private readonly ISettingsHost _host;
    private string L => _host.LanguageCode;

    public SettingsWindow(ISettingsHost host)
    {
        _host = host;
        Width = 520;
        Height = 560;
        ResizeMode = ResizeMode.CanMinimize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Icon = AppIcon.Image();
        Rebuild();
    }

    public void Rebuild()
    {
        Title = "OpenNeko — " + WindowsCopy.Get(WindowsCopyKey.Settings, L).TrimEnd('.');
        var tabs = new TabControl { Margin = new Thickness(10) };
        tabs.Items.Add(new TabItem { Header = WindowsCopy.Get(WindowsCopyKey.General, L), Content = Scroll(GeneralPane()) });
        tabs.Items.Add(new TabItem { Header = WindowsCopy.Get(WindowsCopyKey.AIProvider, L), Content = Scroll(ProviderPane()) });
        tabs.Items.Add(new TabItem { Header = WindowsCopy.Get(WindowsCopyKey.Profile, L), Content = Scroll(ProfilePane()) });
        tabs.Items.Add(new TabItem { Header = WindowsCopy.Get(WindowsCopyKey.TabSkills, L), Content = Scroll(SkillsPane()) });
        var selected = (Content as TabControl)?.SelectedIndex ?? 0;
        tabs.SelectedIndex = Math.Max(0, selected);
        Content = tabs;
    }

    private static ScrollViewer Scroll(UIElement content) => new() { Content = content, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Padding = new Thickness(12) };

    private UIElement GeneralPane()
    {
        var s = _host.Settings;
        var panel = new StackPanel();

        var languages = new List<(string? Code, string Label)> { (null, WindowsCopy.Get(WindowsCopyKey.SystemLanguage, L)) };
        languages.AddRange(AppLanguage.SupportedCodes.Select(c => ((string?)c, AppLanguage.DisplayName(c))));
        var language = Combo(languages.Select(l => l.Label), languages.FindIndex(l => l.Code == s.LanguageCode));
        language.SelectionChanged += (_, _) =>
        {
            var code = languages[language.SelectedIndex].Code;
            _host.Update(x => x with { LanguageCode = code });
            Dispatcher.BeginInvoke(Rebuild);
        };
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.Language, L), language));

        var skins = _host.SkinIds.ToList();
        var skin = Combo(skins.Select(SkinManager.Label), Math.Max(0, skins.IndexOf(s.SelectedSkinId)));
        skin.SelectionChanged += (_, _) => _host.Update(x => x with { SelectedSkinId = skins[skin.SelectedIndex] });
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.Skin, L), skin));

        var catName = new TextBox { Text = s.CatName, MaxLength = 64 };
        catName.LostFocus += (_, _) => _host.Update(x => x with { CatName = catName.Text });
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.CatName, L), catName));

        panel.Children.Add(Check(WindowsCopy.Get(WindowsCopyKey.Sound, L), s.SoundEffectsEnabled, v => _host.Update(x => x with { SoundEffectsEnabled = v })));
        panel.Children.Add(Check(WindowsCopy.Get(WindowsCopyKey.LaunchAtLogin, L), s.LaunchAtLoginEnabled, v => _host.Update(x => x with { LaunchAtLoginEnabled = v })));
        panel.Children.Add(Check(WindowsCopy.Get(WindowsCopyKey.AgentDetection, L), s.AgentProcessDetectionEnabled, v => _host.Update(x => x with { AgentProcessDetectionEnabled = v })));
        panel.Children.Add(Check(WindowsCopy.Get(WindowsCopyKey.WebSearch, L), s.WebSearchEnabled, v => _host.Update(x => x with { WebSearchEnabled = v })));

        var skinsFolder = new Button { Content = WindowsCopy.Get(WindowsCopyKey.OpenSkinsFolder, L), Margin = new Thickness(0, 12, 0, 0), Padding = new Thickness(10, 4, 10, 4), HorizontalAlignment = HorizontalAlignment.Left };
        skinsFolder.Click += (_, _) => _host.OpenSkinsFolder();
        panel.Children.Add(skinsFolder);
        return panel;
    }

    private UIElement ProviderPane()
    {
        var s = _host.Settings;
        var panel = new StackPanel();
        var presets = AIProviderPreset.All.ToList();
        var presetIndex = Math.Max(0, presets.FindIndex(p => p.Id == s.AIProvider.PresetId));
        var preset = presets[presetIndex];
        var combo = Combo(presets.Select(p => p.Title(L) + (p.IsRecommended ? " ★" : "")), presetIndex);
        combo.SelectionChanged += (_, _) =>
        {
            var id = presets[combo.SelectedIndex].Id;
            _host.Update(x => x with { AIProvider = AIProviderPreset.Config(id) });
            Dispatcher.BeginInvoke(Rebuild);
        };
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.Provider, L), combo));
        panel.Children.Add(new TextBlock { Text = preset.Note(L), TextWrapping = TextWrapping.Wrap, Foreground = Brushes.Gray, Margin = new Thickness(0, 0, 0, 8) });

        if (_host.CliAvailable(preset.Type) is bool found)
        {
            panel.Children.Add(new TextBlock
            {
                Text = (found ? "✓ " : "⚠ ") + WindowsCopy.Get(found ? WindowsCopyKey.CliFound : WindowsCopyKey.CliMissing, L) + $" ({preset.Type.CliExecutableName()})",
                Foreground = found ? Brushes.SeaGreen : Brushes.DarkOrange,
                Margin = new Thickness(0, 0, 0, 8),
            });
        }

        if (preset.Fields.Contains(AIProviderField.BaseUrl))
        {
            var baseUrl = new TextBox { Text = s.AIProvider.BaseUrl };
            baseUrl.LostFocus += (_, _) => _host.Update(x => x with { AIProvider = x.AIProvider with { BaseUrl = baseUrl.Text.Trim() } });
            panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.BaseUrl, L), baseUrl));
        }
        if (preset.Fields.Contains(AIProviderField.Model))
        {
            var model = new TextBox { Text = s.AIProvider.Model };
            model.LostFocus += (_, _) => _host.Update(x => x with { AIProvider = x.AIProvider with { Model = model.Text.Trim() } });
            panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.Model, L), model));
        }
        if (preset.Fields.Contains(AIProviderField.ApiKey))
        {
            var key = new PasswordBox();
            var status = new TextBlock { Foreground = Brushes.Gray, Margin = new Thickness(0, 4, 0, 0) };
            void Refresh() => status.Text = WindowsCopy.Get(_host.HasApiKey(preset.Id) ? WindowsCopyKey.KeySaved : WindowsCopyKey.KeyMissing, L);
            Refresh();
            var save = new Button { Content = WindowsCopy.Get(WindowsCopyKey.SaveKey, L), Padding = new Thickness(10, 3, 10, 3), Margin = new Thickness(0, 6, 6, 0) };
            save.Click += (_, _) => { _host.SaveApiKey(preset.Id, key.Password); key.Clear(); Refresh(); };
            var clear = new Button { Content = WindowsCopy.Get(WindowsCopyKey.ClearKey, L), Padding = new Thickness(10, 3, 10, 3), Margin = new Thickness(0, 6, 0, 0) };
            clear.Click += (_, _) => { _host.ClearApiKey(preset.Id); Refresh(); };
            var buttons = new StackPanel { Orientation = Orientation.Horizontal };
            buttons.Children.Add(save);
            buttons.Children.Add(clear);
            var group = new StackPanel();
            group.Children.Add(key);
            group.Children.Add(buttons);
            group.Children.Add(status);
            panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.ApiKey, L), group));
        }

        var result = new TextBlock { TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 6, 0, 0) };
        var test = new Button { Content = WindowsCopy.Get(WindowsCopyKey.TestConnection, L), Padding = new Thickness(10, 4, 10, 4), Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Left };
        test.Click += async (_, _) =>
        {
            test.IsEnabled = false;
            result.Text = WindowsCopy.Get(WindowsCopyKey.Testing, L);
            result.Text = await _host.TestConnectionAsync();
            test.IsEnabled = true;
        };
        panel.Children.Add(test);
        panel.Children.Add(result);
        return panel;
    }

    private UIElement ProfilePane()
    {
        var p = _host.Settings.UserProfile;
        var panel = new StackPanel();
        var name = new TextBox { Text = p.Name, MaxLength = 64 };
        var birthDate = new TextBox { Text = p.BirthDate, MaxLength = 32 };
        var birthTime = new TextBox { Text = p.BirthTime, MaxLength = 16 };
        var calendars = new[] { "solar", "lunar", "unknown" };
        var calendar = Combo(new[] { WindowsCopy.Get(WindowsCopyKey.Solar, L), WindowsCopy.Get(WindowsCopyKey.Lunar, L), WindowsCopy.Get(WindowsCopyKey.Unknown, L) },
            Math.Max(0, Array.IndexOf(calendars, p.Calendar)));
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.ProfileName, L), name));
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.BirthDate, L), birthDate));
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.BirthTime, L), birthTime));
        panel.Children.Add(Field(WindowsCopy.Get(WindowsCopyKey.Calendar, L), calendar));
        var save = new Button { Content = WindowsCopy.Get(WindowsCopyKey.Save, L), Padding = new Thickness(14, 4, 14, 4), HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 10, 0, 0) };
        save.Click += (_, _) => _host.Update(x => x with { UserProfile = new UserProfile(name.Text, birthDate.Text, birthTime.Text, calendars[calendar.SelectedIndex]) });
        panel.Children.Add(save);
        return panel;
    }

    private UIElement SkillsPane()
    {
        var panel = new StackPanel();
        var disabled = _host.Settings.DisabledSkillIds;
        foreach (var skill in _host.AllSkills)
        {
            var id = skill.Id;
            var box = Check($"/{skill.Id} · {skill.Name}", !disabled.Contains(id), enabled => _host.Update(x =>
            {
                var set = new HashSet<string>(x.DisabledSkillIds);
                if (enabled) set.Remove(id); else set.Add(id);
                return x with { DisabledSkillIds = set };
            }));
            box.ToolTip = skill.Description;
            panel.Children.Add(box);
        }
        var folder = new Button { Content = WindowsCopy.Get(WindowsCopyKey.OpenSkillsFolder, L), Margin = new Thickness(0, 12, 0, 0), Padding = new Thickness(10, 4, 10, 4), HorizontalAlignment = HorizontalAlignment.Left };
        folder.Click += (_, _) => _host.OpenSkillsFolder();
        panel.Children.Add(folder);
        return panel;
    }

    private static ComboBox Combo(IEnumerable<string> items, int selected)
    {
        var combo = new ComboBox { MinWidth = 240, HorizontalAlignment = HorizontalAlignment.Left };
        foreach (var item in items) combo.Items.Add(item);
        combo.SelectedIndex = Math.Max(0, selected);
        return combo;
    }

    private static CheckBox Check(string label, bool value, Action<bool> onChange)
    {
        var box = new CheckBox { Content = label, IsChecked = value, Margin = new Thickness(0, 6, 0, 0) };
        box.Checked += (_, _) => onChange(true);
        box.Unchecked += (_, _) => onChange(false);
        return box;
    }

    private static UIElement Field(string label, UIElement control)
    {
        var panel = new StackPanel { Margin = new Thickness(0, 0, 0, 10) };
        panel.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 4) });
        panel.Children.Add(control);
        return panel;
    }
}
