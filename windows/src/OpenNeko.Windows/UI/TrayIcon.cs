using System;
using System.Collections.Generic;
using System.Linq;
using OpenNeko.Core;
using Forms = System.Windows.Forms;

namespace OpenNeko.Windows.UI;

/// <summary>What the tray / cat context menu shows and does (keeps the menu a thin view).</summary>
internal interface IMenuHost
{
    string LanguageCode { get; }
    bool IsCatVisible { get; }
    bool AlwaysOnTop { get; }
    AppSettings Settings { get; }
    IReadOnlyList<string> SkinIds { get; }
    IReadOnlyList<NekoSkill> EnabledSkills { get; }
    void ToggleCat();
    void OpenChat();
    void SetAlwaysOnTop(bool enabled);
    void SetSoundEffects(bool enabled);
    void RunSkill(string id);
    void PreviewState(CatState state);
    void SelectSkin(string id);
    void SetLanguage(string? code);
    void ShowChatHistory();
    void ShowSettings();
    void Quit();
}

/// <summary>
/// Notification-area icon (counterpart of MenuBarController.swift). The same menu is
/// shown for a right-click on the cat, so both entry points stay identical.
/// </summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly IMenuHost _host;
    private readonly Forms.NotifyIcon _icon;

    public TrayIcon(IMenuHost host)
    {
        _host = host;
        _icon = new Forms.NotifyIcon
        {
            Text = "OpenNeko",
            Icon = AppIcon.TrayIcon(),
            Visible = true,
            ContextMenuStrip = new Forms.ContextMenuStrip(),
        };
        _icon.ContextMenuStrip.Opening += (_, _) => Rebuild(_icon.ContextMenuStrip);
        _icon.DoubleClick += (_, _) => _host.ToggleCat();
        Rebuild(_icon.ContextMenuStrip);
    }

    /// <summary>Shows the menu at the cursor (used for a right-click on the cat).</summary>
    public void ShowAtCursor()
    {
        var menu = new Forms.ContextMenuStrip();
        Rebuild(menu);
        menu.Closed += (_, _) => menu.Dispose();
        menu.Show(Forms.Cursor.Position);
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.ContextMenuStrip?.Dispose();
        _icon.Dispose();
    }

    private void Rebuild(Forms.ContextMenuStrip menu)
    {
        var lang = _host.LanguageCode;
        var settings = _host.Settings;
        menu.Items.Clear();

        menu.Items.Add(Item(CatStateMenu.CatVisibilityTitle(_host.IsCatVisible, lang), _host.ToggleCat));
        menu.Items.Add(Item(WindowsCopy.Get(WindowsCopyKey.OpenChat, lang), _host.OpenChat));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(Check(WindowsCopy.Get(WindowsCopyKey.AlwaysOnTop, lang), _host.AlwaysOnTop, _host.SetAlwaysOnTop));
        menu.Items.Add(Check(WindowsCopy.Get(WindowsCopyKey.Sound, lang), settings.SoundEffectsEnabled, _host.SetSoundEffects));
        menu.Items.Add(new Forms.ToolStripSeparator());

        var skills = new Forms.ToolStripMenuItem(WindowsCopy.Get(WindowsCopyKey.Skills, lang));
        var enabled = _host.EnabledSkills;
        if (enabled.Count == 0)
        {
            skills.DropDownItems.Add(new Forms.ToolStripMenuItem(WindowsCopy.Get(WindowsCopyKey.NoSkills, lang)) { Enabled = false });
        }
        foreach (var skill in enabled)
        {
            var id = skill.Id;
            skills.DropDownItems.Add(Item(skill.Name, () => _host.RunSkill(id)));
        }
        menu.Items.Add(skills);

        var preview = new Forms.ToolStripMenuItem(WindowsCopy.Get(WindowsCopyKey.PreviewState, lang));
        foreach (var state in CatStateMenu.PreviewStates)
        {
            var s = state;
            preview.DropDownItems.Add(Item(CatStateMenu.Title(s, lang), () => _host.PreviewState(s)));
        }
        menu.Items.Add(preview);

        var skin = new Forms.ToolStripMenuItem(WindowsCopy.Get(WindowsCopyKey.Skin, lang));
        foreach (var id in _host.SkinIds)
        {
            var skinId = id;
            var item = Item(SkinManager.Label(skinId), () => _host.SelectSkin(skinId));
            item.Checked = settings.SelectedSkinId == skinId;
            skin.DropDownItems.Add(item);
        }
        menu.Items.Add(skin);

        var language = new Forms.ToolStripMenuItem(WindowsCopy.Get(WindowsCopyKey.Language, lang));
        var system = Item(WindowsCopy.Get(WindowsCopyKey.SystemLanguage, lang), () => _host.SetLanguage(null));
        system.Checked = settings.LanguageCode is null;
        language.DropDownItems.Add(system);
        language.DropDownItems.Add(new Forms.ToolStripSeparator());
        foreach (var code in AppLanguage.SupportedCodes)
        {
            var c = code;
            var item = Item(AppLanguage.DisplayName(c), () => _host.SetLanguage(c));
            item.Checked = settings.LanguageCode == c;
            language.DropDownItems.Add(item);
        }
        menu.Items.Add(language);

        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(Item(WindowsCopy.Get(WindowsCopyKey.ChatHistory, lang), _host.ShowChatHistory));
        menu.Items.Add(Item(WindowsCopy.Get(WindowsCopyKey.Settings, lang), _host.ShowSettings));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(Item(WindowsCopy.Get(WindowsCopyKey.Quit, lang), _host.Quit));
    }

    private static Forms.ToolStripMenuItem Item(string title, Action action)
    {
        var item = new Forms.ToolStripMenuItem(title);
        item.Click += (_, _) => action();
        return item;
    }

    private static Forms.ToolStripMenuItem Check(string title, bool value, Action<bool> set)
    {
        var item = new Forms.ToolStripMenuItem(title) { Checked = value };
        item.Click += (_, _) => set(!value);
        return item;
    }
}
