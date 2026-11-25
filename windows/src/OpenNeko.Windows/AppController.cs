using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using OpenNeko.Core;
using OpenNeko.Windows.Services;
using OpenNeko.Windows.UI;
using CoreRect = OpenNeko.Core.Rect;

namespace OpenNeko.Windows;

/// <summary>
/// Composition root (counterpart of the AppDelegate in App/OpenNekoApp.swift).
/// Wires windows and services together; decisions come from OpenNeko.Core.
/// </summary>
internal sealed class AppController : ISettingsHost, IMenuHost, IDisposable
{
    private const double AutonomousTickInterval = 1.0 / 60.0;
    private const double AutonomousWalkSpeed = 90;
    private const int ChatHistoryLimit = 12;
    private const int TranscriptLimit = 160;

    private readonly Dispatcher _dispatcher;
    private readonly IReadOnlyDictionary<string, string?> _environment = ChatProviders.EnvironmentMap();
    private readonly WindowsAppPaths _paths;
    private readonly AppSettingsStore _settingsStore;
    private readonly ChatTranscriptStore _transcriptStore;
    private readonly CredentialStore _credentials = new();
    private readonly SkinManager _skins;
    private readonly string _bundledSkillsRoot;
    private readonly Stopwatch _uptime = Stopwatch.StartNew();
    private readonly Random _random = new();
    private readonly TypingActivityTracker _typing = new(idleDelay: 0.8);
    private readonly AgentProcessMonitor _agentMonitor = new();
    private readonly NekoActiveSkillSelection _activeSkill = new();

    private readonly DispatcherTimer _autonomousTimer;
    private readonly DispatcherTimer _agentTimer;
    private readonly DispatcherTimer _typingTimer;
    private DispatcherTimer? _bridgeIdleTimer;
    private DispatcherTimer? _autonomousStateTimer;
    private DispatcherTimer? _agentIdleTimer;

    private AppSettings _settings;
    private NekoSkillCatalog _skillCatalog = new(Array.Empty<NekoSkill>());
    private CatWindow _cat = null!;
    private BubbleWindow _bubble = null!;
    private ChatWindow _chat = null!;
    private TrayIcon? _tray;
    private SettingsWindow? _settingsWindow;
    private ChatHistoryWindow? _historyWindow;
    private KeyboardHook? _keyboard;
    private StateBridgeServer? _bridge;

    private List<ChatMessage> _chatHistory = new();
    private List<ChatMessage> _transcript = new();
    private CancellationTokenSource? _activeChat;
    private int _chatGeneration;
    private int _keyDownCount;

    private double _lastUserInteraction;
    private double _lastStretchAt;
    private double _nextAutoEffect;
    private double _autonomousModeUntil;
    private double _autonomousWalkUntil;
    private int _autonomousWalkDirection = 1;
    private bool _lunchedToday;
    private bool _cheeredLeaveWorkToday;

    private IReadOnlyList<AgentProcessActivity> _agentActivities = Array.Empty<AgentProcessActivity>();
    private string? _activeAgentSource;

    public AppController(Dispatcher dispatcher)
    {
        _dispatcher = dispatcher;
        _paths = new WindowsAppPaths(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            _environment);
        _settingsStore = new AppSettingsStore(_paths.SettingsFile);
        _transcriptStore = new ChatTranscriptStore(_paths.ChatHistoryFile);
        var resources = Path.Combine(AppContext.BaseDirectory, "Resources");
        _skins = new SkinManager(Path.Combine(resources, "sprites"), _paths.SkinsDirectory);
        _bundledSkillsRoot = Path.Combine(resources, "skills", "builtin");
        _settings = _settingsStore.Load();

        _autonomousTimer = new DispatcherTimer(DispatcherPriority.Render, dispatcher) { Interval = TimeSpan.FromSeconds(AutonomousTickInterval) };
        _autonomousTimer.Tick += (_, _) => RunAutonomousTick();
        _agentTimer = new DispatcherTimer(DispatcherPriority.Background, dispatcher) { Interval = TimeSpan.FromSeconds(4) };
        _agentTimer.Tick += async (_, _) => await RunAgentScanAsync();
        _typingTimer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher);
        _typingTimer.Tick += (_, _) => HandleTypingIdleCheck();
    }

    private double Now => _uptime.Elapsed.TotalSeconds;
    public string LanguageCode => AppLanguage.Resolved(_settings.LanguageCode, CultureInfo.CurrentUICulture.Name);

    // ---- Lifecycle ----

    public void Start()
    {
        try { _transcript = _transcriptStore.Load().ToList(); } catch (IOException) { _transcript = new(); }
        ReloadSkills();

        _cat = new CatWindow { SoundEffectsEnabled = _settings.SoundEffectsEnabled };
        _bubble = new BubbleWindow(defaultOnClick: () => ToggleChat());
        _chat = new ChatWindow(() => SlashCommandParser.Catalog(EnabledSkills, LanguageCode));
        _cat.IsChatVisible = () => _chat.IsVisible;
        _cat.Clicked += () => { NoteUserInteraction(); ToggleChat(); };
        _cat.ContextMenuRequested += () => { NoteUserInteraction(); _tray?.ShowAtCursor(); };
        _cat.UserInteraction += () => NoteUserInteraction();
        _cat.PositionChanged += RepositionFloatingWindows;
        _chat.Sent += text => SendChat(text);
        _chat.Cancelled += () => _pendingPromptSkill = null;
        _chat.FrameChanged += RepositionFloatingWindows;

        _cat.ShowCat(LoadSelectedSkin());
        _tray = new TrayIcon(this);

        _keyboard = new KeyboardHook(HandleKeyDown);
        if (!_keyboard.Start()) ShowBubble(WindowsCopy.Get(WindowsCopyKey.KeyboardHookFailed, LanguageCode));

        StartBridge();
        StartAutonomousLoop();
        ApplyAgentDetection();
        SyncLaunchAtLogin();

        if (!_settings.HasCompletedFirstLaunch)
        {
            Update(s => s with { HasCompletedFirstLaunch = true });
            ShowBubble(NekoBubbleCopy.SetupReady(LanguageCode));
        }
    }

    public void Dispose()
    {
        _autonomousTimer.Stop();
        _agentTimer.Stop();
        _typingTimer.Stop();
        _bridgeIdleTimer?.Stop();
        _autonomousStateTimer?.Stop();
        _agentIdleTimer?.Stop();
        _activeChat?.Cancel();
        _keyboard?.Dispose();
        _bridge?.Dispose();
        _tray?.Dispose();
    }

    private void StartBridge()
    {
        var handlers = new StateBridgeServer.Handlers
        {
            CurrentState = () => _cat.CurrentState,
            KeyDownCount = () => _keyDownCount,
            PositionJson = () => _cat.PositionDebugJson(),
            CapturePng = () => _cat.CapturePng(),
            SettingsJson = SettingsDebugJson,
            AgentJson = AgentDebugJson,
            TypingJson = TypingDebugJson,
            DebugTyping = () => { HandleKeyDown(); return TypingDebugJson(); },
            OnEvent = HandleBridgeEvent,
        };
        _bridge = new StateBridgeServer(StateBridgePort.Resolve(_environment), handlers, _dispatcher);
        if (!_bridge.Start()) ShowBubble(WindowsCopy.Get(WindowsCopyKey.BridgePortBusy, LanguageCode));
    }

    // ---- Bubble / chat placement ----

    private void ShowBubble(string text, Action? onClick = null, string? helpText = null)
    {
        _bubble.ShowText(text, onClick, helpText);
        RepositionFloatingWindows();
        // The bubble measures itself after layout; place it again once it has a size.
        _dispatcher.BeginInvoke(RepositionFloatingWindows, DispatcherPriority.Loaded);
    }

    private void RepositionFloatingWindows()
    {
        if (_cat is null || !_cat.IsVisible) return;
        var monitor = _cat.Monitor;
        var catFrame = _cat.LocalFrame;
        _chat.Reposition(monitor, catFrame);
        CoreRect? avoid = _chat.IsVisible ? _chat.LocalFrame(monitor) : null;
        _bubble.Reposition(monitor, catFrame, avoid);
    }

    private void ToggleChat()
    {
        if (_chat.IsVisible) { _chat.HideChat(); return; }
        OpenChat();
    }

    public void OpenChat()
    {
        if (!_cat.IsVisible) _cat.Toggle();
        var skill = ActiveSkillForCurrentLanguage();
        _chat.ShowChat(skill is null ? NekoBubbleCopy.ChatPlaceholder(LanguageCode) : NekoBubbleCopy.SkillPlaceholder(skill.Name, LanguageCode));
        RepositionFloatingWindows();
        _dispatcher.BeginInvoke(RepositionFloatingWindows, DispatcherPriority.Loaded);
    }

    // ---- Interaction + autonomous loop (mirrors runAutonomousTick in OpenNekoApp.swift) ----

    private void NoteUserInteraction(bool showWakeBubble = true)
    {
        _lastUserInteraction = Now;
        _nextAutoEffect = Math.Max(_nextAutoEffect, _lastUserInteraction + 25);
        if (_cat?.CurrentState == CatState.Nap)
        {
            _cat.ApplyBridgeState(CatState.Idle);
            if (showWakeBubble) ShowBubble(StateBubbleText.WakeText(LanguageCode));
        }
    }

    private void StartAutonomousLoop()
    {
        var now = Now;
        _lastUserInteraction = now;
        _lastStretchAt = now;
        _nextAutoEffect = now + 25;
        _autonomousModeUntil = now + 3;
        _autonomousTimer.Start();
    }

    private void RunAutonomousTick()
    {
        var cat = _cat;
        var now = Now;
        UpdateDailyRitualFlags();

        if (now < _autonomousWalkUntil || cat.IsAutonomousMotionSettling)
        {
            if (!cat.CanContinueAutonomousWalk() || !(cat.CanStartAutonomousAction() || cat.CurrentState == CatState.Walk))
            {
                StopAutonomousWalk(now);
                return;
            }
            _autonomousWalkDirection = cat.AutonomousWalkStep(_autonomousWalkDirection,
                now < _autonomousWalkUntil ? AutonomousWalkSpeed * AutonomousTickInterval : 0, AutonomousTickInterval);
            RepositionFloatingWindows();
            return;
        }
        if (_autonomousWalkUntil > 0 && cat.CurrentState == CatState.Walk) StopAutonomousWalk(now);

        if (!cat.CanStartAutonomousAction()) return;

        var context = new CatAutonomousContext(now, DateTime.Now.Hour, _lastUserInteraction, _lastStretchAt, _nextAutoEffect,
            _lunchedToday, _cheeredLeaveWorkToday, IsAvailable: true);
        switch (CatAutonomousBehavior.Action(context, _random.NextDouble()))
        {
            case CatAutonomousAction.None:
                MaybeStartAutonomousWalk(now, cat);
                break;
            case CatAutonomousAction.Stretch:
                _lastStretchAt = now;
                PlayAutonomousState(CatState.Yawn, NekoBubbleCopy.Stretch(LanguageCode));
                break;
            case CatAutonomousAction.Lunch:
                _lunchedToday = true;
                PlayAutonomousState(CatState.Lunch, NekoBubbleCopy.Lunch(LanguageCode), revertAfter: 90);
                break;
            case CatAutonomousAction.LeaveWork:
                _cheeredLeaveWorkToday = true;
                PlayAutonomousState(CatState.Success, NekoBubbleCopy.LeaveWork(LanguageCode));
                break;
            case CatAutonomousAction.Nap:
                PlayAutonomousState(CatState.Nap, null);
                break;
            case CatAutonomousAction.Yawn:
                ScheduleNextAutoEffect(now);
                PlayAutonomousState(CatState.Yawn, null);
                break;
            case CatAutonomousAction.Jump:
                ScheduleNextAutoEffect(now);
                PlayAutonomousState(CatState.Jump, null);
                break;
        }
    }

    private void MaybeStartAutonomousWalk(double now, CatWindow cat)
    {
        if (now <= _autonomousModeUntil) return;
        if (_random.NextDouble() < 0.72)
        {
            _autonomousWalkDirection = _random.Next(2) == 0 ? 1 : -1;
            _autonomousWalkUntil = now + Uniform(2.0, 5.0);
            _autonomousModeUntil = _autonomousWalkUntil + Uniform(0.8, 1.8);
            _autonomousWalkDirection = cat.AutonomousWalkStep(_autonomousWalkDirection, AutonomousWalkSpeed * AutonomousTickInterval, AutonomousTickInterval);
        }
        else
        {
            _autonomousModeUntil = now + Uniform(1.2, 3.2);
        }
    }

    private void StopAutonomousWalk(double now)
    {
        _autonomousWalkUntil = 0;
        _autonomousModeUntil = now + Uniform(2, 5);
        _cat.StopAutonomousWalk();
    }

    private void PlayAutonomousState(CatState state, string? bubble, double? revertAfter = null)
    {
        _autonomousStateTimer?.Stop();
        _cat.PlayAutonomousState(state);
        if (bubble is not null) ShowBubble(bubble);
        if (revertAfter is double seconds)
        {
            _autonomousStateTimer = After(seconds, () =>
            {
                if (_cat.CurrentState == state) _cat.ApplyBridgeState(CatState.Idle);
            });
        }
    }

    private void ScheduleNextAutoEffect(double now) => _nextAutoEffect = now + Uniform(30, 70);

    private void UpdateDailyRitualFlags()
    {
        var hour = DateTime.Now.Hour;
        if (hour < CatAutonomousBehavior.LunchHour) _lunchedToday = false;
        if (hour < CatAutonomousBehavior.LeaveWorkHour) _cheeredLeaveWorkToday = false;
    }

    private double Uniform(double min, double max) => min + _random.NextDouble() * (max - min);

    private DispatcherTimer After(double seconds, Action action)
    {
        var timer = new DispatcherTimer(DispatcherPriority.Normal, _dispatcher) { Interval = TimeSpan.FromSeconds(seconds) };
        timer.Tick += (_, _) => { timer.Stop(); action(); };
        timer.Start();
        return timer;
    }

    // ---- Typing (keydown timing only; key contents are never seen) ----

    private void HandleKeyDown()
    {
        NoteUserInteraction();
        _keyDownCount++;
        if (_typing.KeyDown(Now)) _cat.SetTypingActive(true, _typing.AnimationSpeed);
        else _cat.UpdateTypingSpeed(_typing.AnimationSpeed);
        ScheduleTypingIdleCheck();
    }

    private void ScheduleTypingIdleCheck()
    {
        _typingTimer.Stop();
        _typingTimer.Interval = TimeSpan.FromSeconds(Math.Max(0.05, _typing.NextIdleCheckDelay(Now)));
        _typingTimer.Start();
    }

    private void HandleTypingIdleCheck()
    {
        _typingTimer.Stop();
        if (_typing.Tick(Now)) _cat.SetTypingActive(false);
        if (_typing.IsTyping) ScheduleTypingIdleCheck();
    }

    // ---- State bridge ----

    private bool IsChatAnswering => _activeChat is not null;

    private void HandleBridgeEvent(StateBridgeEvent evt)
    {
        if (!NekoStatePriority.AcceptsBridgeEvent(IsChatAnswering)) return;
        NoteUserInteraction(showWakeBubble: false);
        _bridgeIdleTimer?.Stop();
        _autonomousStateTimer?.Stop();
        _cat.ApplyBridgeState(evt.State);
        if (StateBubbleText.Text(evt, LanguageCode) is string text) ShowBubble(text);
        if (evt.State == CatState.Idle || NekoStatePriority.OneShotStates.Contains(evt.State)) return;
        _bridgeIdleTimer = After(90, () => _cat.ApplyBridgeState(CatState.Idle));
    }

    public void PreviewState(CatState state)
    {
        NoteUserInteraction();
        _bridgeIdleTimer?.Stop();
        _autonomousStateTimer?.Stop();
        _cat.ApplyBridgeState(state);
        if (state == CatState.Idle || NekoStatePriority.OneShotStates.Contains(state)) return;
        _bridgeIdleTimer = After(12, () => _cat.ApplyBridgeState(CatState.Idle));
    }

    private string SettingsDebugJson() => new JsonObject
    {
        ["ok"] = true,
        ["settings"] = new JsonObject
        {
            ["selectedSkinID"] = _settings.SelectedSkinId,
            ["languageCode"] = _settings.LanguageCode,
            ["resolvedLanguageCode"] = LanguageCode,
            ["soundEffectsEnabled"] = _settings.SoundEffectsEnabled,
            ["launchAtLoginEnabled"] = _settings.LaunchAtLoginEnabled,
            ["agentProcessDetectionEnabled"] = _settings.AgentProcessDetectionEnabled,
            ["webSearchEnabled"] = _settings.WebSearchEnabled,
            ["aiProviderPresetID"] = _settings.AIProvider.PresetId,
            ["aiProviderType"] = _settings.AIProvider.Type.RawValue(),
            ["aiProviderModel"] = _settings.AIProvider.Model,
            ["hasAPIKey"] = HasApiKey(_settings.AIProvider.PresetId),
        },
    }.ToJsonString();

    private string AgentDebugJson()
    {
        var activities = new JsonArray();
        foreach (var a in _agentActivities)
            activities.Add(new JsonObject { ["source"] = a.Source, ["label"] = a.Label, ["cpu"] = a.Cpu });
        return new JsonObject
        {
            ["enabled"] = _settings.AgentProcessDetectionEnabled,
            ["activeSource"] = _activeAgentSource,
            ["activities"] = activities,
        }.ToJsonString();
    }

    private string TypingDebugJson() => new JsonObject
    {
        ["isTyping"] = _typing.IsTyping,
        ["animationSpeed"] = _typing.AnimationSpeed,
        ["keyDownCount"] = _keyDownCount,
        ["hookActive"] = _keyboard?.IsActive ?? false,
        ["state"] = _cat.CurrentState.RawValue(),
    }.ToJsonString();

    // ---- Agent detection ----

    private void ApplyAgentDetection()
    {
        if (_settings.AgentProcessDetectionEnabled)
        {
            if (!_agentTimer.IsEnabled) _agentTimer.Start();
            return;
        }
        _agentTimer.Stop();
        _agentIdleTimer?.Stop();
        _agentIdleTimer = null;
        _agentActivities = Array.Empty<AgentProcessActivity>();
        if (_activeAgentSource is not null && _cat.CurrentState == CatState.Coding) _cat.ApplyBridgeState(CatState.Idle);
        _activeAgentSource = null;
    }

    private async Task RunAgentScanAsync()
    {
        if (!_settings.AgentProcessDetectionEnabled) return;
        var activities = await _agentMonitor.ScanAsync();
        if (activities is null) return;
        HandleAgentActivities(activities);
    }

    private void HandleAgentActivities(IReadOnlyList<AgentProcessActivity> activities)
    {
        _agentActivities = activities;
        if (!_settings.AgentProcessDetectionEnabled) return;
        var activity = AgentProcessDetector.TopBusyActivity(activities);
        if (activity is null)
        {
            ScheduleAgentIdle(resetExisting: false);
            return;
        }
        if (!NekoStatePriority.AcceptsAgentCodingState(IsChatAnswering, _cat.CurrentState)) return;
        if (_activeAgentSource != activity.Source) ShowBubble(NekoBubbleCopy.AgentWorking(activity.Label, LanguageCode));
        _lastUserInteraction = Now;
        _activeAgentSource = activity.Source;
        _cat.ApplyBridgeState(CatState.Coding);
        ScheduleAgentIdle(resetExisting: true);
    }

    private void ScheduleAgentIdle(bool resetExisting)
    {
        if (_activeAgentSource is null) return;
        if (_agentIdleTimer is not null && !resetExisting) return;
        _agentIdleTimer?.Stop();
        _agentIdleTimer = After(9, () =>
        {
            _agentIdleTimer = null;
            var wasCoding = _cat.CurrentState == CatState.Coding;
            _activeAgentSource = null;
            if (wasCoding) _cat.ApplyBridgeState(CatState.Idle);
        });
    }

    // ---- Skills ----

    private NekoSkill? _pendingPromptSkill;

    private void ReloadSkills()
    {
        _skillCatalog = NekoSkillCatalog.Discover(_bundledSkillsRoot, _paths.UserSkillsDirectory);
        _activeSkill.Reconcile(_skillCatalog, _settings.DisabledSkillIds);
    }

    public IReadOnlyList<NekoSkill> AllSkills
    {
        get { ReloadSkills(); return NekoSkillLocalization.Localize(_skillCatalog.Skills, LanguageCode); }
    }

    public IReadOnlyList<NekoSkill> EnabledSkills =>
        NekoSkillLocalization.Localize(_skillCatalog.Enabled(_settings.DisabledSkillIds), LanguageCode);

    private NekoSkill? ActiveSkillForCurrentLanguage() =>
        _activeSkill.Resolve(_skillCatalog, _settings.DisabledSkillIds) is NekoSkill skill ? NekoSkillLocalization.Localize(skill, LanguageCode) : null;

    public void RunSkill(string id)
    {
        NoteUserInteraction();
        ReloadSkills();
        if (_skillCatalog.Skill(id) is not NekoSkill raw)
        {
            _cat.ApplyBridgeState(CatState.Error);
            ShowBubble(NekoBubbleCopy.SkillMissing(LanguageCode));
            return;
        }
        if (_settings.DisabledSkillIds.Contains(raw.Id))
        {
            ShowBubble(NekoBubbleCopy.SkillDisabled(LanguageCode));
            return;
        }
        RunSkill(NekoSkillLocalization.Localize(raw, LanguageCode), inputOverride: null);
    }

    private void RunSkill(NekoSkill skill, string? inputOverride)
    {
        if (skill.Id == "daily-bgm")
        {
            RunDailyBgm(inputOverride);
            return;
        }
        if (inputOverride is not null)
        {
            SendSkillChat(skill, inputOverride);
            return;
        }
        switch (skill.Input)
        {
            case NekoSkillInput.Prompt:
                if (_activeSkill.Activate(skill)) _chatHistory.Clear();
                _pendingPromptSkill = null;
                ShowBubble(NekoBubbleCopy.SkillActivated(skill.Name, LanguageCode));
                OpenChat();
                break;
            case NekoSkillInput.Clipboard:
                var text = ReadClipboard().Trim();
                if (text.Length == 0)
                {
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(NekoBubbleCopy.ClipboardEmpty(LanguageCode));
                    return;
                }
                SendSkillChat(skill, text);
                break;
            case NekoSkillInput.None:
                SendSkillChat(skill, $"{skill.Name} 실행해줘");
                break;
        }
    }

    private void RunDailyBgm(string? preference)
    {
        var normalized = DailyBgmSelector.NormalizePreference(preference);
        if (DailyBgmSelector.IsStopCommand(normalized))
        {
            _cat.ApplyBridgeState(CatState.Success);
            ShowBubble(NekoBubbleCopy.BgmStopped(LanguageCode));
            return;
        }
        var bgm = DailyBgmSelector.Pick(DateTime.Now, normalized, _settings.UserProfile, LanguageCode);
        _cat.ApplyBridgeState(CatState.Thinking);
        ShowBubble(NekoBubbleCopy.BgmSearching(LanguageCode));
        if (OpenUrl(bgm.Url.AbsoluteUri))
        {
            _cat.ApplyBridgeState(CatState.Success);
            ShowBubble(NekoBubbleCopy.BgmOpened(bgm.Title, bgm.Query, LanguageCode));
        }
        else
        {
            _cat.ApplyBridgeState(CatState.Error);
            ShowBubble(NekoBubbleCopy.BgmOpenFailed(LanguageCode));
        }
    }

    // ---- Chat ----

    private void SendChat(string text)
    {
        NoteUserInteraction();
        var message = text.Trim();
        if (message.Length == 0) return;

        if (_pendingPromptSkill is NekoSkill pending)
        {
            _pendingPromptSkill = null;
            SendSkillChat(pending, message);
            return;
        }
        if (HandleSlashCommand(message)) return;

        CancelActiveChat();
        var stored = TextUtil.Prefix(message, 2000);
        _chatHistory.Add(new ChatMessage(ChatRole.User, stored));
        AppendTranscript(new ChatMessage(ChatRole.User, stored));
        TrimChatHistory();

        var skill = ActiveSkillForCurrentLanguage();
        _cat.ApplyBridgeState(CatState.Thinking);
        ShowBubble(NekoBubbleCopy.Thinking(skill?.Name, LanguageCode));
        RunChat(_chatHistory.ToList(), CurrentSystemPrompt(skill), stream: true,
            onReply: reply =>
            {
                _chatHistory.Add(new ChatMessage(ChatRole.Assistant, reply));
                TrimChatHistory();
            },
            onFailure: () =>
            {
                if (_chatHistory.Count > 0 && _chatHistory[^1].Role == ChatRole.User && _chatHistory[^1].Text == stored)
                    _chatHistory.RemoveAt(_chatHistory.Count - 1);
                RemoveFailedTranscriptTurn(stored);
            });
    }

    private void SendSkillChat(NekoSkill skill, string input)
    {
        var stored = TextUtil.Prefix(input.Trim(), 6000);
        if (stored.Length == 0) return;
        CancelActiveChat();
        AppendTranscript(new ChatMessage(ChatRole.User, stored));
        _cat.ApplyBridgeState(CatState.Thinking);
        ShowBubble(NekoBubbleCopy.SkillRunning(skill.Name, LanguageCode));
        RunChat(new List<ChatMessage> { new(ChatRole.User, stored) }, CurrentSystemPrompt(skill), stream: false,
            onReply: _ => { },
            onFailure: () => RemoveFailedTranscriptTurn(stored));
    }

    private void RunChat(List<ChatMessage> history, string system, bool stream, Action<string> onReply, Action onFailure)
    {
        var generation = ++_chatGeneration;
        var cts = new CancellationTokenSource();
        _activeChat = cts;
        var config = _settings.AIProvider;
        var apiKey = ResolvedApiKey(config);
        var lang = LanguageCode;
        Action<string>? onPartial = stream
            ? partial => _dispatcher.BeginInvoke(() =>
            {
                if (generation != _chatGeneration || _activeChat is null) return;
                _cat.ApplyBridgeState(NekoStatePriority.ChatAnsweringState);
                ShowBubble(partial);
            })
            : null;

        _ = Task.Run(async () =>
        {
            try
            {
                var reply = await ChatProviders.ReplyAsync(config, apiKey, history, system, lang, onPartial, cts.Token);
                await _dispatcher.InvokeAsync(() =>
                {
                    if (generation != _chatGeneration) return;
                    _activeChat = null;
                    var display = NekoBubbleCopy.StyledChatReply(reply, LanguageCode);
                    onReply(display);
                    AppendTranscript(new ChatMessage(ChatRole.Assistant, display));
                    _cat.ApplyBridgeState(CatState.Success);
                    ShowCopyableReply(display);
                });
            }
            catch (OperationCanceledException) when (cts.IsCancellationRequested)
            {
            }
            catch (Exception error)
            {
                await _dispatcher.InvokeAsync(() =>
                {
                    if (generation != _chatGeneration) return;
                    _activeChat = null;
                    onFailure();
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(error is ChatFailure failure ? failure.UserMessage : NekoBubbleCopy.GenericChatError(LanguageCode));
                });
            }
        });
    }

    private void CancelActiveChat()
    {
        _chatGeneration++;
        _activeChat?.Cancel();
        _activeChat = null;
    }

    private void TrimChatHistory()
    {
        if (_chatHistory.Count > ChatHistoryLimit) _chatHistory = _chatHistory.Skip(_chatHistory.Count - ChatHistoryLimit).ToList();
    }

    private string CurrentSystemPrompt(NekoSkill? skill)
    {
        var lang = LanguageCode;
        var parts = new List<string> { ChatPromptBuilder.SystemPrompt(skill, lang, _settings.UserProfile, DateTime.Now) };
        if (ChatPromptBuilder.CatNameContext(_settings.CatName, lang) is string name) parts.Add(name);
        if (_settings.WebSearchEnabled) parts.Add(ChatPromptBuilder.WebSearchContext(lang));
        return string.Join("\n\n", parts);
    }

    private string? ResolvedApiKey(AIProviderConfig config) =>
        AIProviderPreset.ResolveApiKey(config.PresetId, _credentials.ApiKey(config.PresetId), _environment);

    private void ShowCopyableReply(string reply) =>
        ShowBubble(reply, () =>
        {
            try { Clipboard.SetText(reply); } catch (System.Runtime.InteropServices.COMException) { return; }
            ShowBubble(NekoBubbleCopy.ReplyCopied(LanguageCode));
        }, NekoBubbleCopy.CopyReplyHelp(LanguageCode));

    private bool HandleSlashCommand(string message)
    {
        if (SlashCommandParser.Parse(message) is not SlashCommand slash) return false;
        var lang = LanguageCode;
        var argument = slash.Arguments;
        switch (slash.Command)
        {
            case "help":
                var names = string.Join(" ", EnabledSkills.Take(3).Select(s => "/" + s.Id));
                ShowBubble(NekoBubbleCopy.SlashHelp(names.Length == 0 ? "" : "\n" + names, lang));
                return true;
            case "reset":
                CancelActiveChat();
                _chatHistory.Clear();
                _transcript.Clear();
                SaveTranscript();
                _pendingPromptSkill = null;
                _activeSkill.Clear();
                _cat.ApplyBridgeState(CatState.Success);
                ShowBubble(NekoBubbleCopy.ChatReset(lang));
                return true;
            case "skin":
                var ids = _skins.AvailableSkinIds();
                if (argument.Length == 0)
                {
                    ShowBubble(NekoBubbleCopy.SkinList(string.Join(", ", ids), lang));
                    return true;
                }
                if (!ids.Contains(argument))
                {
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(NekoBubbleCopy.SkinMissing(lang));
                    return true;
                }
                SelectSkin(argument);
                _cat.ApplyBridgeState(CatState.Success);
                ShowBubble(NekoBubbleCopy.SkinChanged(SkinManager.Label(argument), LanguageCode));
                return true;
            case "lang":
                if (argument.Length == 0)
                {
                    ShowBubble(NekoBubbleCopy.CurrentLanguage(AppLanguage.DisplayName(lang), lang));
                    return true;
                }
                if (SlashCommandParser.IsSystemLanguageArgument(argument))
                {
                    SetLanguage(null);
                    ShowBubble(NekoBubbleCopy.SystemLanguage(LanguageCode));
                    return true;
                }
                if (AppLanguage.Normalized(argument.ToLowerInvariant()) is not string code)
                {
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(NekoBubbleCopy.SupportedLanguages(lang));
                    return true;
                }
                SetLanguage(code);
                ShowBubble(NekoBubbleCopy.CurrentLanguage(AppLanguage.DisplayName(code), LanguageCode));
                return true;
            case "sound":
                bool enabled;
                try { enabled = SlashCommandParser.SoundArgument(argument) ?? !_settings.SoundEffectsEnabled; }
                catch (ArgumentException)
                {
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(NekoBubbleCopy.SoundUsage(lang));
                    return true;
                }
                SetSoundEffects(enabled);
                ShowBubble(NekoBubbleCopy.SoundEnabled(enabled, lang));
                return true;
            default:
                ReloadSkills();
                if (_skillCatalog.Skill(slash.Command) is not NekoSkill raw)
                {
                    _cat.ApplyBridgeState(CatState.Error);
                    ShowBubble(NekoBubbleCopy.UnknownCommand(lang));
                    return true;
                }
                if (_settings.DisabledSkillIds.Contains(raw.Id))
                {
                    ShowBubble(NekoBubbleCopy.SkillDisabled(lang));
                    return true;
                }
                RunSkill(NekoSkillLocalization.Localize(raw, lang), argument.Length == 0 ? null : argument);
                return true;
        }
    }

    // ---- Transcript ----

    private void AppendTranscript(ChatMessage message)
    {
        _transcript.Add(message);
        if (_transcript.Count > TranscriptLimit) _transcript = _transcript.Skip(_transcript.Count - TranscriptLimit).ToList();
        SaveTranscript();
    }

    private void RemoveFailedTranscriptTurn(string message)
    {
        if (_transcript.Count > 0 && _transcript[^1].Role == ChatRole.User && _transcript[^1].Text == message)
        {
            _transcript.RemoveAt(_transcript.Count - 1);
            SaveTranscript();
        }
    }

    private void SaveTranscript()
    {
        try { _transcriptStore.Save(_transcript); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { Debug.WriteLine("[openNeko] failed to save chat history"); }
        _historyWindow?.Render(_transcript, LanguageCode);
    }

    public void ShowChatHistory()
    {
        if (_historyWindow is null)
        {
            _historyWindow = new ChatHistoryWindow(onClear: () =>
            {
                _transcript.Clear();
                SaveTranscript();
            });
            _historyWindow.Closed += (_, _) => _historyWindow = null;
        }
        _historyWindow.Render(_transcript, LanguageCode);
        _historyWindow.Show();
        _historyWindow.Activate();
    }

    // ---- Settings (ISettingsHost) + menu (IMenuHost) ----

    public AppSettings Settings => _settings;
    public IReadOnlyList<string> SkinIds => _skins.AvailableSkinIds();
    public bool IsCatVisible => _cat.IsVisible;
    public bool AlwaysOnTop => _cat.Topmost;

    public void Update(Func<AppSettings, AppSettings> change)
    {
        var old = _settings;
        var updated = change(old);
        if (updated.Equals(old))
            return;
        _settings = updated;
        try { _settingsStore.Save(updated); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { Debug.WriteLine("[openNeko] failed to save settings"); }

        if (updated.SelectedSkinId != old.SelectedSkinId) _cat.ApplySkin(LoadSelectedSkin());
        _cat.SoundEffectsEnabled = updated.SoundEffectsEnabled;
        if (updated.LaunchAtLoginEnabled != old.LaunchAtLoginEnabled) SyncLaunchAtLogin();
        if (updated.AgentProcessDetectionEnabled != old.AgentProcessDetectionEnabled) ApplyAgentDetection();
        if (!updated.DisabledSkillIds.SetEquals(old.DisabledSkillIds)) _activeSkill.Reconcile(_skillCatalog, updated.DisabledSkillIds);
        if (updated.LanguageCode != old.LanguageCode)
        {
            _settingsWindow?.Rebuild();
            _historyWindow?.Render(_transcript, LanguageCode);
        }
    }

    public void SetAlwaysOnTop(bool enabled) => _cat.SetAlwaysOnTop(enabled);
    public void SetSoundEffects(bool enabled) => Update(s => s with { SoundEffectsEnabled = enabled });
    public void SetLanguage(string? code) => Update(s => s with { LanguageCode = code });

    public void SelectSkin(string id)
    {
        if (!_skins.AvailableSkinIds().Contains(id)) return;
        Update(s => s with { SelectedSkinId = id });
    }

    public void ToggleCat()
    {
        _cat.Toggle();
        if (!_cat.IsVisible)
        {
            _bubble.HideBubble();
            _chat.HideChat();
        }
    }

    public void ShowSettings()
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = new SettingsWindow(this);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    public void Quit() => Application.Current.Shutdown();

    public bool HasApiKey(string presetId) => !string.IsNullOrEmpty(_credentials.ApiKey(presetId));
    public bool SaveApiKey(string presetId, string key) => _credentials.Save(presetId, key);
    public void ClearApiKey(string presetId) => _credentials.Delete(presetId);

    public bool? CliAvailable(AIProviderType type) =>
        CliKindExtensions.FromProvider(type) is CliKind kind ? ChatProviders.ResolveCli(kind) is not null : null;

    public async Task<string> TestConnectionAsync()
    {
        var config = _settings.AIProvider;
        var history = new List<ChatMessage> { new(ChatRole.User, "openNeko 연결 테스트입니다. '준비됨'이라고 짧게 답해주세요.") };
        try
        {
            var reply = await Task.Run(() => ChatProviders.ReplyAsync(config, ResolvedApiKey(config), history,
                CurrentSystemPrompt(null), LanguageCode, null, CancellationToken.None));
            return WindowsCopy.Get(WindowsCopyKey.ConnectionOk, LanguageCode) + "\n" + TextUtil.Prefix(reply.Trim(), 120);
        }
        catch (ChatFailure failure)
        {
            return failure.UserMessage;
        }
        catch (Exception)
        {
            return NekoBubbleCopy.GenericChatError(LanguageCode);
        }
    }

    public void OpenSkillsFolder() => OpenFolder(_paths.UserSkillsDirectory);
    public void OpenSkinsFolder() => OpenFolder(_paths.SkinsDirectory);

    private Skin LoadSelectedSkin()
    {
        try { return _skins.LoadSkin(_settings.SelectedSkinId); }
        catch (Exception e) when (e is FileNotFoundException or SpriteManifestException or IOException) { return _skins.LoadDefault(); }
    }

    private void SyncLaunchAtLogin()
    {
        if (LaunchAtLogin.IsEnabled() != _settings.LaunchAtLoginEnabled) LaunchAtLogin.SetEnabled(_settings.LaunchAtLoginEnabled);
    }

    private static void OpenFolder(string path)
    {
        try
        {
            Directory.CreateDirectory(path);
            Process.Start(new ProcessStartInfo("explorer.exe", "\"" + path + "\"") { UseShellExecute = false });
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.ComponentModel.Win32Exception) { }
    }

    private static bool OpenUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            return true;
        }
        catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            return false;
        }
    }

    private static string ReadClipboard()
    {
        try { return Clipboard.ContainsText() ? Clipboard.GetText() : ""; }
        catch (System.Runtime.InteropServices.COMException) { return ""; }
    }
}
