import AppKit
import Darwin
import SwiftUI
import UniformTypeIdentifiers
import OpenNekoKit

@main
struct OpenNekoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement 앱: 보이는 Scene 없음. 메뉴바/창은 AppDelegate가 관리.
        Settings { EmptyView() }
    }
}

private struct DebugSettingsMutation: Decodable {
    let aiProviderPresetID: String?
    let aiProviderBaseURL: String?
    let aiProviderModel: String?
    let selectedSkinID: String?
    let hasCompletedFirstLaunch: Bool?
    let disabledSkillIDs: [String]?
    let agentProcessDetectionEnabled: Bool?
    let languageCode: String?
    let soundEffectsEnabled: Bool?
    let webSearchEnabled: Bool?
    let catName: String?
    let userProfile: UserProfile?
    let neighborEnabled: Bool?
    let neighborDisplayName: String?
}

private struct DebugSettingsApplyResponse: Encodable {
    let ok: Bool
    let reason: String?
    let settings: AppSettingsDebugSnapshot

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8)
        else {
            return #"{"ok":false,"reason":"encoding-failed"}"#
        }
        return text
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var catWindow: CatWindow?
    private var keyboardMonitor: KeyboardMonitor?
    private var keyboardMonitorRetryTimer: Timer?
    private var agentProcessMonitor = AgentProcessMonitor()
    private var stateBridgeServer: StateBridgeServer?
    private var neighborNetwork: NeighborNetwork?
    private var settingsWindow: SettingsWindowController?
    private var chatHistoryWindowController: ChatHistoryWindowController?
    private var skinManager: SkinManager?
    private var skillCatalog = NekoSkillCatalog(skills: [])
    private let settingsStore = AppSettingsStore()
    private let apiKeyStore = APIKeyStore()
    private let updateController = GitUpdateController()
    private let launchOptions = AppLaunchOptions(environment: ProcessInfo.processInfo.environment)
    private var guestCatWindows: [String: GuestCatWindow] = [:]
    private var appSettings = AppSettings.defaults
    private var selectedSkinID = SkinManager.defaultID
    private var typingTracker = TypingActivityTracker(idleDelay: 0.8)
    private var chatHistory: [ChatMessage] = []
    private var chatTranscript: [ChatMessage] = []
    private var pendingPromptSkill: NekoSkill?
    private var activeSkillSelection = NekoActiveSkillSelection()
    private var aiConnectionTestStatus = AIProviderConnectionTestStatus.idle
    private var aiProviderDetections: [AIProviderDetection] = []
    private var isOnboardingVisible = false
    private var updateStatus = AppUpdateStatus.idle
    private var updateBranch = "main"
    private var updateRepositoryRoot: URL?
    private var activeChatTask: Task<Void, Never>?
    private var chatGeneration = 0
    private var aiConnectionTestTask: Task<Void, Never>?
    private var aiProviderDetectionTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var aiConnectionTestGeneration = 0
    private var keyDownCount = 0
    private var typingTimer: Timer?
    private var bridgeIdleTimer: Timer?
    private var agentProcessTimer: Timer?
    private var agentProcessIdleTimer: Timer?
    private var autonomousTimer: Timer?
    private var autonomousStateTimer: Timer?
    private var activeAgentProcessSource: String?
    private var agentProcessActivities: [AgentProcessActivity] = []
    private var lastUserInteraction = ProcessInfo.processInfo.systemUptime
    private var lastStretchAt = ProcessInfo.processInfo.systemUptime
    private var nextAutoEffect = ProcessInfo.processInfo.systemUptime + 25
    private var lunchedToday = false
    private var cheeredLeaveWorkToday = false
    private var autonomousWalkDirection = 1
    private var autonomousWalkUntil: TimeInterval = 0
    private var autonomousModeUntil: TimeInterval = ProcessInfo.processInfo.systemUptime + 3
    private let autonomousTickInterval: TimeInterval = 1.0 / 60.0
    private let autonomousWalkSpeed: CGFloat = 90

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let cat = CatWindow()
        catWindow = cat
        cat.onChatSend = { [weak self, weak cat] text in
            self?.sendChat(text, cat: cat)
        }
        cat.onChatCancel = { [weak self] in
            self?.pendingPromptSkill = nil
        }
        cat.onContextMenu = { [weak self] view in
            self?.menuBar?.popUpContextMenu(anchorView: view)
        }
        cat.onUserInteraction = { [weak self] in
            self?.noteUserInteraction()
        }
        cat.onPositionChanged = { [weak self] in
            self?.repositionGuestCats()
        }
        cat.slashCommandsProvider = { [weak self] in
            self?.slashCommandCatalog() ?? []
        }
        cat.chatPlaceholderProvider = { [weak self] in
            NekoBubbleCopy.chatPlaceholder(languageCode: self?.currentLanguageCode())
        }

        let spritesURL = bundledSpritesRootURL()
        let manager = SkinManager(bundledRoot: spritesURL, externalRoot: externalSkinsRootURL())
        skinManager = manager
        appSettings = settingsStore.load()
        skillCatalog = loadSkillCatalog()
        let shouldShowFirstLaunchSettings = !appSettings.hasCompletedFirstLaunch
        isOnboardingVisible = shouldShowFirstLaunchSettings
        reconcileLaunchAtLoginPreference()
        selectedSkinID = appSettings.selectedSkinID
        let initialSkin = (try? manager.loadSkin(id: selectedSkinID)) ?? manager.loadDefault()
        selectedSkinID = initialSkin.id
        appSettings.selectedSkinID = selectedSkinID
        cat.soundEffectsEnabled = appSettings.soundEffectsEnabled
        cat.showCat(skin: initialSkin)
        settingsWindow = SettingsWindowController(
            state: { [weak self] in
                self?.settingsState() ?? SettingsWindowController.State(
                    permissionMenu: InputMonitoringPermissionMenu(status: .missing),
                    launchAtLogin: LaunchAtLoginSetting(isEnabled: false),
                    aiProvider: AIProviderPreset.defaultConfig,
                    aiProviderHasAPIKey: false,
                    aiProviderReadiness: AIProviderReadiness.evaluate(
                        config: AIProviderPreset.defaultConfig,
                        preset: AIProviderPreset.preset(for: AIProviderPreset.defaultID)!,
                        hasResolvedAPIKey: false,
                        cliExecutableAvailable: false,
                        languageCode: AppLanguage.resolved(nil)
                    ),
                    aiProviderConnectionTest: .idle,
                    aiProviderDetections: [],
                    isOnboardingVisible: false,
                    skills: [],
                    disabledSkillIDs: [],
                    agentProcessDetectionEnabled: true,
                    languageCode: nil,
                    resolvedLanguageCode: AppLanguage.resolved(nil),
                    soundEffectsEnabled: true,
                    webSearchEnabled: false,
                    catName: "",
                    userProfile: .empty,
                    neighborSettings: .defaults,
                    neighborPeerCount: 0,
                    peerID: "",
                    stateBridgePort: StateBridgeServer.defaultPort(),
                    skinIDs: [SkinManager.defaultID],
                    skinPreviewFrameURLs: [:],
                    selectedSkinID: SkinManager.defaultID,
                    version: OpenNekoKit.version
                )
            },
            openAccessibility: { [weak self] in
                self?.openAccessibilitySettings()
            },
            openInputMonitoring: { [weak self] in
                self?.openInputMonitoringSettings()
            },
            retryKeyboardMonitor: { [weak self, weak cat] in
                self?.restartKeyboardMonitor(for: cat)
            },
            setLaunchAtLogin: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            setAgentProcessDetection: { [weak self] enabled in
                self?.setAgentProcessDetection(enabled)
            },
            setLanguageCode: { [weak self] code in
                self?.setLanguageCode(code)
            },
            setSoundEffects: { [weak self] enabled in
                self?.setSoundEffects(enabled)
            },
            setWebSearch: { [weak self] enabled in
                self?.setWebSearch(enabled)
            },
            setCatName: { [weak self] name in
                self?.setCatName(name)
            },
            setUserProfile: { [weak self] profile in
                self?.setUserProfile(profile)
            },
            setNeighborEnabled: { [weak self] enabled in
                self?.setNeighborEnabled(enabled)
            },
            setNeighborDisplayName: { [weak self] name in
                self?.setNeighborDisplayName(name)
            },
            sendNeighborWave: { [weak self] in
                self?.sendNeighborWave()
            },
            selectAIProviderPreset: { [weak self] id in
                self?.selectAIProviderPreset(id)
            },
            updateAIProviderBaseURL: { [weak self] baseURL in
                self?.updateAIProviderBaseURL(baseURL)
            },
            updateAIProviderModel: { [weak self] model in
                self?.updateAIProviderModel(model)
            },
            saveAIProviderAPIKey: { [weak self] apiKey in
                self?.saveAIProviderAPIKey(apiKey)
            },
            clearAIProviderAPIKey: { [weak self] in
                self?.clearAIProviderAPIKey()
            },
            testAIProviderConnection: { [weak self] in
                self?.testAIProviderConnection()
            },
            applyAIProviderDetection: { [weak self] detection in
                self?.applyAIProviderDetection(detection)
            },
            refreshAIProviderDetections: { [weak self] in
                self?.refreshAIProviderDetections()
            },
            showOnboarding: { [weak self] in
                self?.showOnboarding()
            },
            completeOnboarding: { [weak self] in
                self?.completeOnboarding()
            },
            runSkill: { [weak self] id in
                self?.runSkill(id: id)
            },
            setSkillEnabled: { [weak self] id, enabled in
                self?.setSkillEnabled(id: id, enabled: enabled)
            },
            openSkillsFolder: { [weak self] in
                self?.openSkillsFolder()
            },
            createCustomSkinRequest: { [weak self] in
                self?.createCustomSkinRequest()
            },
            importCustomSkinPackage: { [weak self] in
                self?.importCustomSkinPackage()
            },
            openSkinsFolder: { [weak self] in
                self?.openSkinsFolder()
            },
            selectSkin: { [weak self, weak cat] id in
                self?.selectSkin(id, cat: cat)
            }
        )

        menuBar = MenuBarController(
            onToggleCat: { [weak cat] in cat?.toggle() },
            onOpenChatHistory: { [weak self] in self?.showChatHistory() },
            onOpenSettings: { [weak self] in self?.settingsWindow?.show() },
            onQuit: { NSApp.terminate(nil) },
            isCatVisible: { [weak cat] in cat?.isVisible ?? false },
            isAlwaysOnTopEnabled: { [weak cat] in cat?.isAlwaysOnTopEnabled ?? false },
            soundEffectsEnabled: { [weak self] in self?.appSettings.soundEffectsEnabled ?? true },
            permissionMenu: { [weak self] in
                self?.runtimeTypingPermissionMenu() ?? InputMonitoringPermissionController.menu
            },
            enabledSkills: { [weak self] in
                self?.enabledSkills() ?? []
            },
            neighborPeerCount: { [weak self] in
                self?.neighborNetwork?.peers.count ?? 0
            },
            updateStatus: { [weak self] in
                self?.updateStatus ?? .idle
            },
            languageCode: { [weak self] in
                self?.currentLanguageCode() ?? AppLanguage.resolved(nil)
            },
            onToggleAlwaysOnTop: { [weak self] in
                self?.toggleAlwaysOnTop()
            },
            onToggleSoundEffects: { [weak self] in
                self?.toggleSoundEffects()
            },
            onPreviewState: { [weak self] state in
                self?.previewState(state)
            },
            onRunSkill: { [weak self] id in
                self?.runSkill(id: id)
            },
            onSendNeighborWave: { [weak self] in
                self?.sendNeighborWave()
            },
            onCheckForUpdates: { [weak self] in
                self?.checkForUpdates(silent: false)
            },
            onApplyUpdate: { [weak self] in
                self?.applyUpdate()
            },
            onOpenAccessibility: { [weak self] in
                self?.openAccessibilitySettings()
            },
            onOpenInputMonitoring: { [weak self] in
                self?.openInputMonitoringSettings()
            },
            onRetryKeyboardMonitor: { [weak self, weak cat] in
                self?.restartKeyboardMonitor(for: cat)
            }
        )
        startKeyboardMonitor(for: cat)
        configureAgentProcessDetection()
        stateBridgeServer = StateBridgeServer(
            currentState: { [weak cat] in cat?.currentState ?? .idle },
            keyDownCount: { [weak self] in
                let snapshot = {
                    self?.keyDownCount ?? 0
                }
                if Thread.isMainThread {
                    return snapshot()
                }
                return DispatchQueue.main.sync(execute: snapshot)
            },
            currentPositionJSON: { [weak cat] in
                let snapshot = {
                    cat?.positionDebugJSON()
                }
                if Thread.isMainThread {
                    return snapshot()
                }
                return DispatchQueue.main.sync(execute: snapshot)
            },
            capturePNG: { [weak cat] in
                if Thread.isMainThread {
                    return cat?.capturePNGData()
                }
                return DispatchQueue.main.sync { cat?.capturePNGData() }
            },
            settingsJSON: { [weak self] in
                guard let self else { return nil }
                return AppSettingsDebugSnapshot.jsonString(settings: self.appSettings)
            },
            agentProcessJSON: { [weak self] in
                self?.agentProcessDebugJSON()
            },
            debugDragAndDrop: { [weak cat] in
                cat?.debugDragAndDropJSON()
            },
            debugTyping: { [weak self, weak cat] in
                self?.debugTypingJSON(cat: cat)
            },
            typingStatusJSON: { [weak self] in
                self?.typingStatusDebugJSON()
            },
            debugSettingsApply: { [weak self] body in
                self?.debugSettingsApplyJSON(body: body)
            },
            onEvent: { [weak self, weak cat] event in
                self?.handleBridgeEvent(event, cat: cat)
            }
        )
        stateBridgeServer?.start()
        configureNeighborNetwork()
        startAutonomousLoop()
        refreshAIProviderDetections()

        if launchOptions.opensSettingsOnLaunch || launchOptions.settingsSnapshotPath != nil || shouldShowFirstLaunchSettings {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindow?.show()
            }
        }
        if let snapshotPath = launchOptions.settingsSnapshotPath {
            scheduleSettingsSnapshot(path: snapshotPath)
        }
        if !shouldShowFirstLaunchSettings {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                self?.checkForUpdates(silent: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridgeIdleTimer?.invalidate()
        typingTimer?.invalidate()
        keyboardMonitorRetryTimer?.invalidate()
        agentProcessTimer?.invalidate()
        agentProcessIdleTimer?.invalidate()
        autonomousTimer?.invalidate()
        autonomousStateTimer?.invalidate()
        activeChatTask?.cancel()
        aiConnectionTestTask?.cancel()
        aiProviderDetectionTask?.cancel()
        updateTask?.cancel()
        neighborNetwork?.stop()
        clearGuestCats()
        keyboardMonitor?.stop()
        stateBridgeServer?.stop()
    }

    private func startKeyboardMonitor(for cat: CatWindow) {
        let monitor = KeyboardMonitor { [weak self, weak cat] in
            self?.handleKeyDown(cat: cat)
        }
        keyboardMonitor = monitor
        if monitor.start() {
            keyboardMonitorRetryTimer?.invalidate()
            keyboardMonitorRetryTimer = nil
        } else {
            NSLog("[openNeko] keyboard monitor unavailable; listen=\(KeyboardMonitor.hasListenPermission) accessibility=\(InputMonitoringPermissionController.hasAccessibilityPermission)")
            if !KeyboardMonitor.hasListenPermission {
                _ = KeyboardMonitor.requestListenPermission()
            }
            scheduleKeyboardMonitorRetry(cat: cat)
        }
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func runtimeTypingPermissionMenu() -> InputMonitoringPermissionMenu {
        let permission = InputMonitoringPermissionController.menu
        guard keyboardMonitor?.isActive == true else {
            return permission
        }
        return InputMonitoringPermissionMenu(
            status: .granted,
            accessibilityGranted: permission.accessibilityGranted,
            inputMonitoringGranted: permission.inputMonitoringGranted
        )
    }

    private func scheduleKeyboardMonitorRetry(cat: CatWindow) {
        guard keyboardMonitorRetryTimer == nil else { return }
        keyboardMonitorRetryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self, weak cat] timer in
            guard let self, cat != nil else {
                timer.invalidate()
                return
            }
            if self.keyboardMonitor?.start() == true {
                timer.invalidate()
                self.keyboardMonitorRetryTimer = nil
                self.menuBar?.refresh()
                self.settingsWindow?.refresh()
            } else if !KeyboardMonitor.hasListenPermission {
                _ = KeyboardMonitor.requestListenPermission()
            }
        }
    }

    private func restartKeyboardMonitor(for cat: CatWindow?) {
        typingTimer?.invalidate()
        typingTimer = nil
        keyboardMonitorRetryTimer?.invalidate()
        keyboardMonitorRetryTimer = nil
        typingTracker = TypingActivityTracker(idleDelay: typingTracker.idleDelay)
        cat?.setTypingActive(false)
        keyboardMonitor?.stop()
        guard let cat else { return }
        startKeyboardMonitor(for: cat)
    }

    private func openInputMonitoringSettings() {
        _ = InputMonitoringPermissionController.requestPermission()
        InputMonitoringPermissionController.openInputMonitoringSystemSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func openAccessibilitySettings() {
        _ = InputMonitoringPermissionController.requestAccessibilityPermission()
        InputMonitoringPermissionController.openAccessibilitySystemSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func selectSkin(_ id: String, cat: CatWindow?) {
        guard let skin = try? skinManager?.loadSkin(id: id) else { return }
        selectedSkinID = id
        appSettings.selectedSkinID = id
        saveSettings()
        cat?.applySkin(skin)
        configureNeighborNetwork()
        settingsWindow?.refresh()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
        } catch {
            NSLog("[openNeko] failed to update launch at login: \(error)")
        }
        appSettings.launchAtLoginEnabled = LaunchAtLoginController.isEnabled
        saveSettings()
        settingsWindow?.refresh()
    }

    private func setAgentProcessDetection(_ enabled: Bool) {
        appSettings.agentProcessDetectionEnabled = enabled
        saveSettings()
        configureAgentProcessDetection()
        settingsWindow?.refresh()
    }

    private func setLanguageCode(_ code: String?) {
        appSettings.languageCode = AppLanguage.normalized(code)
        resetAIConnectionTest(refresh: false)
        saveSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func setSoundEffects(_ enabled: Bool) {
        appSettings.soundEffectsEnabled = enabled
        catWindow?.soundEffectsEnabled = enabled
        saveSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func toggleAlwaysOnTop() {
        guard let catWindow else { return }
        let next = !catWindow.isAlwaysOnTopEnabled
        catWindow.setAlwaysOnTopEnabled(next)
        for guest in guestCatWindows.values {
            guest.setAlwaysOnTopEnabled(next)
        }
        if next {
            catWindow.orderFrontRegardless()
        }
        menuBar?.refresh()
    }

    private func toggleSoundEffects() {
        setSoundEffects(!appSettings.soundEffectsEnabled)
    }

    private func previewState(_ state: CatState) {
        noteUserInteraction()
        bridgeIdleTimer?.invalidate()
        autonomousStateTimer?.invalidate()
        catWindow?.applyBridgeState(state)
        neighborNetwork?.setPresence(NeighborPresence.coarse(for: state))
        if state != .idle, !bridgeOneShotStates.contains(state) {
            bridgeIdleTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
                self?.catWindow?.applyBridgeState(.idle)
                self?.neighborNetwork?.setPresence(.idle)
            }
        }
        menuBar?.refresh()
    }

    private func noteUserInteraction(showWakeBubble: Bool = true) {
        lastUserInteraction = ProcessInfo.processInfo.systemUptime
        nextAutoEffect = max(nextAutoEffect, lastUserInteraction + 25)
        if catWindow?.currentState == .nap {
            catWindow?.applyBridgeState(.idle)
            if showWakeBubble {
                catWindow?.showBubble(StateBubbleText.wakeText(languageCode: currentLanguageCode()))
            }
        }
    }

    private func startAutonomousLoop() {
        autonomousTimer?.invalidate()
        let now = ProcessInfo.processInfo.systemUptime
        lastUserInteraction = now
        lastStretchAt = now
        nextAutoEffect = now + 25
        autonomousModeUntil = now + 3
        autonomousTimer = Timer.scheduledTimer(withTimeInterval: autonomousTickInterval, repeats: true) { [weak self] _ in
            self?.runAutonomousTick()
        }
    }

    private func runAutonomousTick() {
        guard let cat = catWindow else { return }
        let now = ProcessInfo.processInfo.systemUptime
        updateDailyRitualFlags()

        if now < autonomousWalkUntil || cat.isAutonomousMotionSettling {
            guard cat.canContinueAutonomousWalk(), cat.canStartAutonomousAction() || cat.currentState == .walk else {
                stopAutonomousWalk(now: now)
                return
            }
            autonomousWalkDirection = cat.autonomousWalkStep(
                direction: autonomousWalkDirection,
                distance: now < autonomousWalkUntil ? autonomousWalkDistance : 0,
                deltaTime: autonomousTickInterval
            )
            return
        } else if autonomousWalkUntil > 0, cat.currentState == .walk {
            stopAutonomousWalk(now: now)
        }

        guard cat.canStartAutonomousAction() else { return }

        let context = CatAutonomousContext(
            uptime: now,
            hour: Calendar.current.component(.hour, from: Date()),
            lastInteraction: lastUserInteraction,
            lastStretch: lastStretchAt,
            nextAutoEffect: nextAutoEffect,
            lunchAlreadyShown: lunchedToday,
            leaveWorkAlreadyShown: cheeredLeaveWorkToday,
            isAvailable: true
        )

        switch CatAutonomousBehavior.action(for: context, randomValue: Double.random(in: 0..<1)) {
        case .none:
            maybeStartAutonomousWalk(now: now, cat: cat)
        case .stretch:
            lastStretchAt = now
            playAutonomousState(.yawn, bubble: NekoBubbleCopy.stretch(languageCode: currentLanguageCode()))
        case .lunch:
            lunchedToday = true
            playAutonomousState(.lunch, bubble: NekoBubbleCopy.lunch(languageCode: currentLanguageCode()), revertAfter: 90)
        case .leaveWork:
            cheeredLeaveWorkToday = true
            playAutonomousState(.success, bubble: NekoBubbleCopy.leaveWork(languageCode: currentLanguageCode()))
        case .nap:
            playAutonomousState(.nap, bubble: nil)
        case .yawn:
            scheduleNextAutoEffect(after: now)
            playAutonomousState(.yawn, bubble: nil)
        case .jump:
            scheduleNextAutoEffect(after: now)
            playAutonomousState(.jump, bubble: nil)
        }
    }

    private func maybeStartAutonomousWalk(now: TimeInterval, cat: CatWindow) {
        guard now > autonomousModeUntil else { return }
        if Double.random(in: 0..<1) < 0.72 {
            autonomousWalkDirection = Bool.random() ? 1 : -1
            autonomousWalkUntil = now + Double.random(in: 2.0...5.0)
            autonomousModeUntil = autonomousWalkUntil + Double.random(in: 0.8...1.8)
            _ = cat.autonomousWalkStep(
                direction: autonomousWalkDirection,
                distance: autonomousWalkDistance,
                deltaTime: autonomousTickInterval
            )
        } else {
            autonomousModeUntil = now + Double.random(in: 1.2...3.2)
        }
    }

    private var autonomousWalkDistance: CGFloat {
        autonomousWalkSpeed * CGFloat(autonomousTickInterval)
    }

    private func stopAutonomousWalk(now: TimeInterval) {
        autonomousWalkUntil = 0
        autonomousModeUntil = now + Double.random(in: 2...5)
        catWindow?.stopAutonomousWalk()
    }

    private func playAutonomousState(
        _ state: CatState,
        bubble: String?,
        revertAfter: TimeInterval? = nil
    ) {
        autonomousStateTimer?.invalidate()
        catWindow?.playAutonomousState(state)
        neighborNetwork?.setPresence(NeighborPresence.coarse(for: state))
        if let bubble {
            catWindow?.showBubble(bubble)
        }
        if let revertAfter {
            autonomousStateTimer = Timer.scheduledTimer(withTimeInterval: revertAfter, repeats: false) { [weak self] _ in
                guard self?.catWindow?.currentState == state else { return }
                self?.catWindow?.applyBridgeState(.idle)
                self?.neighborNetwork?.setPresence(.idle)
            }
        }
    }

    private func scheduleNextAutoEffect(after now: TimeInterval) {
        nextAutoEffect = now + Double.random(in: 30...70)
    }

    private func updateDailyRitualFlags() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < CatAutonomousBehavior.lunchHour {
            lunchedToday = false
        }
        if hour < CatAutonomousBehavior.leaveWorkHour {
            cheeredLeaveWorkToday = false
        }
    }

    private func setWebSearch(_ enabled: Bool) {
        appSettings.webSearchEnabled = enabled
        resetAIConnectionTest(refresh: false)
        saveSettings()
        settingsWindow?.refresh()
    }

    private func setCatName(_ name: String) {
        appSettings.catName = UserProfile.sanitized(name, limit: 64)
        saveSettings()
        configureNeighborNetwork()
    }

    private func setUserProfile(_ profile: UserProfile) {
        appSettings.userProfile = profile.normalized()
        saveSettings()
    }

    private func setNeighborEnabled(_ enabled: Bool) {
        appSettings.neighborSettings.enabled = enabled
        saveSettings()
        configureNeighborNetwork()
        settingsWindow?.refresh()
    }

    private func setNeighborDisplayName(_ name: String) {
        appSettings.neighborSettings.displayName = UserProfile.sanitized(name, limit: 64)
        saveSettings()
        configureNeighborNetwork()
    }

    private func sendNeighborWave() {
        noteUserInteraction()
        guard appSettings.neighborSettings.enabled, let neighborNetwork else {
            catWindow?.showBubble(NeighborEventPresentation.disabledText(languageCode: currentLanguageCode()))
            return
        }
        neighborNetwork.sendWave()
        catWindow?.applyBridgeState(.jump)
        catWindow?.showBubble(NeighborEventPresentation.sentWaveText(languageCode: currentLanguageCode()))
        for guest in guestCatWindows.values {
            guest.showBubble(NeighborEventPresentation.greeting(key: 0, languageCode: currentLanguageCode()))
        }
    }

    private func sendNeighborWave(to peerID: String) {
        noteUserInteraction()
        guard appSettings.neighborSettings.enabled, let neighborNetwork else {
            catWindow?.showBubble(NeighborEventPresentation.disabledText(languageCode: currentLanguageCode()))
            return
        }
        neighborNetwork.sendWave(to: peerID)
        neighborNetwork.sendGreeting(to: peerID, key: 0)
        catWindow?.applyBridgeState(.jump)
        guestCatWindows[peerID]?.showBubble(NeighborEventPresentation.greeting(key: 0, languageCode: currentLanguageCode()))
    }

    private func reconcileLaunchAtLoginPreference() {
        if appSettings.launchAtLoginEnabled && !LaunchAtLoginController.isEnabled {
            do {
                try LaunchAtLoginController.setEnabled(true)
            } catch {
                NSLog("[openNeko] failed to migrate launch at login preference: \(error)")
            }
        }
        appSettings.launchAtLoginEnabled = LaunchAtLoginController.isEnabled
    }

    private func selectAIProviderPreset(_ id: String) {
        appSettings.aiProvider = AIProviderPreset.config(for: id)
        resetAIConnectionTest(refresh: false)
        saveSettings()
        settingsWindow?.refresh()
    }

    private func applyAIProviderDetection(_ detection: AIProviderDetection) {
        appSettings.aiProvider = detection.config()
        resetAIConnectionTest(refresh: false)
        saveSettings()
        settingsWindow?.refresh()
    }

    private func refreshAIProviderDetections() {
        aiProviderDetectionTask?.cancel()
        aiProviderDetectionTask = Task.detached(priority: .utility) {
            let detections = await AppDelegate.detectReadyAIProviders()
            await MainActor.run { [weak self] in
                self?.aiProviderDetections = detections
                self?.settingsWindow?.refresh()
            }
        }
    }

    private func updateAIProviderBaseURL(_ baseURL: String) {
        let previousReadiness = currentAIProviderReadiness()
        let previousConnectionTest = aiConnectionTestStatus
        var provider = appSettings.aiProvider
        provider.baseURL = baseURL
        appSettings.aiProvider = AIProviderPreset.config(for: provider.presetID, overrides: provider)
        resetAIConnectionTest(refresh: false)
        saveSettings()
        refreshAISettingsIfNeeded(
            previousReadiness: previousReadiness,
            previousConnectionTest: previousConnectionTest
        )
    }

    private func updateAIProviderModel(_ model: String) {
        let previousReadiness = currentAIProviderReadiness()
        let previousConnectionTest = aiConnectionTestStatus
        var provider = appSettings.aiProvider
        provider.model = model
        appSettings.aiProvider = AIProviderPreset.config(for: provider.presetID, overrides: provider)
        resetAIConnectionTest(refresh: false)
        saveSettings()
        refreshAISettingsIfNeeded(
            previousReadiness: previousReadiness,
            previousConnectionTest: previousConnectionTest
        )
    }

    private func saveAIProviderAPIKey(_ apiKey: String) {
        do {
            try apiKeyStore.save(apiKey, for: appSettings.aiProvider.presetID)
        } catch {
            NSLog("[openNeko] failed to save API key: \(error)")
        }
        resetAIConnectionTest(refresh: false)
        settingsWindow?.refresh()
    }

    private func clearAIProviderAPIKey() {
        do {
            try apiKeyStore.delete(for: appSettings.aiProvider.presetID)
        } catch {
            NSLog("[openNeko] failed to delete API key: \(error)")
        }
        resetAIConnectionTest(refresh: false)
        settingsWindow?.refresh()
    }

    private func settingsState() -> SettingsWindowController.State {
        let languageCode = currentLanguageCode()
        let provider = appSettings.aiProvider
        let resolvedKey = resolvedAPIKey(for: provider)
        return SettingsWindowController.State(
            permissionMenu: runtimeTypingPermissionMenu(),
            launchAtLogin: LaunchAtLoginSetting(isEnabled: LaunchAtLoginController.isEnabled),
            aiProvider: provider,
            aiProviderHasAPIKey: apiKeyStore.hasAPIKey(for: provider.presetID),
            aiProviderReadiness: aiProviderReadiness(for: provider, resolvedAPIKey: resolvedKey),
            aiProviderConnectionTest: aiConnectionTestStatus,
            aiProviderDetections: aiProviderDetections,
            isOnboardingVisible: isOnboardingVisible,
            skills: localizedSkills(skillCatalog.skills, languageCode: languageCode),
            disabledSkillIDs: appSettings.disabledSkillIDs,
            agentProcessDetectionEnabled: appSettings.agentProcessDetectionEnabled,
            languageCode: appSettings.languageCode,
            resolvedLanguageCode: languageCode,
            soundEffectsEnabled: appSettings.soundEffectsEnabled,
            webSearchEnabled: appSettings.webSearchEnabled,
            catName: appSettings.catName,
            userProfile: appSettings.userProfile,
            neighborSettings: appSettings.neighborSettings,
            neighborPeerCount: neighborNetwork?.peers.count ?? 0,
            peerID: appSettings.peerID,
            stateBridgePort: StateBridgeServer.defaultPort(),
            skinIDs: skinManager?.availableSkinIDs() ?? [SkinManager.defaultID],
            skinPreviewFrameURLs: skinPreviewFrameURLs(),
            selectedSkinID: selectedSkinID,
            version: OpenNekoKit.version
        )
    }

    private func skinPreviewFrameURLs() -> [String: [URL]] {
        guard let skinManager else { return [:] }
        return skinManager.availableSkinIDs().reduce(into: [String: [URL]]()) { result, id in
            guard let skin = try? skinManager.loadSkin(id: id) else { return }
            let walkFrames = existingFrameURLs(skin.frameURLs(for: CatState.walk.rawValue))
            result[id] = walkFrames.isEmpty
                ? existingFrameURLs(skin.frameURLs(for: CatState.idle.rawValue))
                : walkFrames
        }
    }

    private func existingFrameURLs(_ urls: [URL]) -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func showOnboarding() {
        isOnboardingVisible = true
        settingsWindow?.refresh()
    }

    private func completeOnboarding() {
        isOnboardingVisible = false
        if !appSettings.hasCompletedFirstLaunch {
            appSettings.hasCompletedFirstLaunch = true
            saveSettings()
            catWindow?.showBubble(NekoBubbleCopy.setupReady(languageCode: currentLanguageCode()))
        }
        settingsWindow?.refresh()
    }

    private func setFirstLaunchCompleted(_ completed: Bool) {
        appSettings.hasCompletedFirstLaunch = completed
        isOnboardingVisible = !completed
        saveSettings()
        settingsWindow?.refresh()
    }

    private func currentLanguageCode() -> String {
        AppLanguage.resolved(appSettings.languageCode)
    }

    private func currentSystemPrompt(skill: NekoSkill?) -> String {
        let languageCode = currentLanguageCode()
        var system = ChatPromptBuilder.systemPrompt(
            skill: skill,
            languageCode: languageCode,
            userProfile: appSettings.userProfile
        )
        if let catName = ChatPromptBuilder.catNameContext(appSettings.catName, languageCode: languageCode) {
            system += "\n\(catName)"
        }
        if appSettings.webSearchEnabled {
            system += "\n\(ChatPromptBuilder.webSearchContext(languageCode: languageCode))"
        }
        return system
    }

    private func skinLabel(_ id: String) -> String {
        id == SkinManager.defaultID ? "white" : id
    }

    private func aiProviderReadiness(
        for provider: AIProviderConfig,
        resolvedAPIKey: String?
    ) -> AIProviderReadiness {
        let preset = AIProviderPreset.preset(for: provider.presetID)
            ?? AIProviderPreset.preset(for: AIProviderPreset.defaultID)!
        return AIProviderReadiness.evaluate(
            config: provider,
            preset: preset,
            hasResolvedAPIKey: !(resolvedAPIKey ?? "").isEmpty,
            cliExecutableAvailable: cliExecutableAvailable(for: provider.type),
            languageCode: currentLanguageCode()
        )
    }

    private func currentAIProviderReadiness() -> AIProviderReadiness {
        aiProviderReadiness(
            for: appSettings.aiProvider,
            resolvedAPIKey: resolvedAPIKey(for: appSettings.aiProvider)
        )
    }

    private func refreshAISettingsIfNeeded(
        previousReadiness: AIProviderReadiness,
        previousConnectionTest: AIProviderConnectionTestStatus
    ) {
        if previousReadiness != currentAIProviderReadiness()
            || previousConnectionTest != aiConnectionTestStatus {
            settingsWindow?.refresh()
        }
    }

    private func cliExecutableAvailable(for type: AIProviderType) -> Bool? {
        switch type {
        case .codexCLI:
            return commandExists("codex")
        case .claudeCLI:
            return commandExists("claude")
        case .geminiCLI:
            return commandExists("gemini")
        case .openAICompatible, .gemini, .anthropic:
            return nil
        }
    }

    private func commandExists(_ executable: String) -> Bool {
        Self.commandExists(executable, environment: ProcessInfo.processInfo.environment)
    }

    private static func commandExists(_ executable: String, environment: [String: String]) -> Bool {
        let searchPaths = ProcessPathEnvironment.augmentPath(environment["PATH"])
            .split(separator: ":")
            .map(String.init)

        return searchPaths.contains { directory in
            FileManager.default.isExecutableFile(atPath: URL(fileURLWithPath: directory)
                .appendingPathComponent(executable)
                .path)
        }
    }

    private static func detectReadyAIProviders() async -> [AIProviderDetection] {
        let environment = ProcessInfo.processInfo.environment
        var detections = AIProviderDetection.environmentDetections(environment: environment)

        let codexAvailable = commandExists("codex", environment: environment)
        let codexStatus = codexAvailable
            ? runCommandOutput("codex", arguments: ["login", "status"], timeout: 2)
            : nil
        if let detection = AIProviderDetection.cliDetection(
            presetID: "chatgpt-oauth",
            executable: "codex",
            executableAvailable: codexAvailable,
            codexLoginStatusOutput: codexStatus
        ) {
            detections.append(detection)
        }

        if let detection = AIProviderDetection.cliDetection(
            presetID: "claude-oauth",
            executable: "claude",
            executableAvailable: commandExists("claude", environment: environment)
        ) {
            detections.append(detection)
        }

        if let detection = AIProviderDetection.cliDetection(
            presetID: "gemini-oauth",
            executable: "gemini",
            executableAvailable: commandExists("gemini", environment: environment)
        ) {
            detections.append(detection)
        }

        if let detection = AIProviderDetection.ollamaDetection(models: await fetchOllamaModels()) {
            detections.append(detection)
        }

        return AIProviderDetection.uniqueReady(detections)
    }

    private static func fetchOllamaModels() async -> [String] {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else {
            return []
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            return AIProviderDetection.ollamaModels(from: data)
        } catch {
            return []
        }
    }

    private static func runCommandOutput(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.environment = commandEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdout = Data()
        var stderr = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        var didTimeout = false
        let timeoutItem = DispatchWorkItem {
            didTimeout = true
            if process.isRunning {
                process.terminate()
            }
        }

        do {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
            try process.run()
            process.waitUntilExit()
            timeoutItem.cancel()
            group.wait()
        } catch {
            timeoutItem.cancel()
            return nil
        }

        guard !didTimeout else {
            return nil
        }
        return String(decoding: stdout + stderr, as: UTF8.self)
    }

    private static func commandEnvironment() -> [String: String] {
        ProcessPathEnvironment.spawnEnvironment(terminalDefaults: true)
    }

    private func saveSettings() {
        do {
            try settingsStore.save(appSettings)
        } catch {
            NSLog("[openNeko] failed to save settings: \(error)")
        }
    }

    private func checkForUpdates(silent: Bool) {
        guard !updateStatus.isBusy else { return }
        updateStatus = .checking
        menuBar?.refresh()
        if !silent {
            catWindow?.showBubble(updateStatus.bubbleText(languageCode: currentLanguageCode()))
        }

        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try self.updateController.check()
                await self.finishUpdateCheck(result, silent: silent)
            } catch {
                await self.failUpdateCheck(silent: silent)
            }
        }
    }

    @MainActor
    private func finishUpdateCheck(_ result: GitUpdateCheckResult, silent: Bool) {
        updateBranch = result.branch
        updateRepositoryRoot = result.repositoryRoot
        switch result.decision.reason {
        case .behind where result.decision.available:
            updateStatus = .available(behind: result.decision.behind, branch: result.branch)
        case .dirty:
            updateStatus = .dirty(behind: result.decision.behind)
        case .notGit:
            updateStatus = .notGit
        case .upToDate, .behind:
            updateStatus = .upToDate
        }
        menuBar?.refresh()
        if !silent || updateStatus.isUpdateAvailable {
            catWindow?.showBubble(updateStatus.bubbleText(languageCode: currentLanguageCode()))
        }
    }

    @MainActor
    private func failUpdateCheck(silent: Bool) {
        updateStatus = .checkFailed
        menuBar?.refresh()
        if !silent {
            catWindow?.showBubble(updateStatus.bubbleText(languageCode: currentLanguageCode()))
        }
    }

    private func applyUpdate() {
        guard case .available(_, let branch) = updateStatus else {
            checkForUpdates(silent: false)
            return
        }
        guard !updateStatus.isBusy else { return }
        updateStatus = .updating
        menuBar?.refresh()
        catWindow?.applyBridgeState(.coding)
        catWindow?.showBubble(updateStatus.bubbleText(languageCode: currentLanguageCode()))

        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            do {
                let root = try self.updateController.apply(branch: branch)
                await self.finishUpdateApply(repositoryRoot: root)
            } catch {
                await self.failUpdateApply()
            }
        }
    }

    @MainActor
    private func finishUpdateApply(repositoryRoot: URL) {
        updateRepositoryRoot = repositoryRoot
        catWindow?.applyBridgeState(.success)
        catWindow?.showBubble(NekoBubbleCopy.updateRestart(languageCode: currentLanguageCode()))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.relaunchFromRepository(repositoryRoot)
        }
    }

    @MainActor
    private func failUpdateApply() {
        updateStatus = .failed
        menuBar?.refresh()
        catWindow?.applyBridgeState(.error)
        catWindow?.showBubble(updateStatus.bubbleText(languageCode: currentLanguageCode()))
    }

    private func relaunchFromRepository(_ repositoryRoot: URL) {
        let script = repositoryRoot.appendingPathComponent("script/build_and_run.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path) else {
            updateStatus = .failed
            menuBar?.refresh()
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.missingRunScript(languageCode: currentLanguageCode()))
            return
        }

        let command = """
        sleep 1
        cd \(shellQuoted(repositoryRoot.path))
        ./script/build_and_run.sh >/tmp/openneko-update-relaunch.log 2>&1
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", command]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            updateStatus = .failed
            menuBar?.refresh()
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.restartFailed(languageCode: currentLanguageCode()))
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func scheduleSettingsSnapshot(path: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            guard let data = settingsWindow?.capturePNGData() else {
                NSLog("[openNeko] failed to capture settings snapshot")
                Darwin.exit(1)
            }
            do {
                let url = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                NSLog("[openNeko] settings snapshot written to \(url.path)")
                NSApp.terminate(nil)
            } catch {
                NSLog("[openNeko] failed to write settings snapshot: \(error)")
                Darwin.exit(1)
            }
        }
    }

    private func configureAgentProcessDetection() {
        agentProcessTimer?.invalidate()
        agentProcessTimer = nil
        agentProcessIdleTimer?.invalidate()
        agentProcessIdleTimer = nil
        activeAgentProcessSource = nil
        agentProcessActivities = []

        guard appSettings.agentProcessDetectionEnabled else { return }

        runAgentProcessScan()
        agentProcessTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.runAgentProcessScan()
        }
    }

    private func runAgentProcessScan() {
        guard appSettings.agentProcessDetectionEnabled else { return }
        agentProcessMonitor.scan { [weak self] activities in
            self?.handleAgentProcessActivities(activities)
        }
    }

    private func handleAgentProcessActivities(_ activities: [AgentProcessActivity]) {
        agentProcessActivities = activities
        guard appSettings.agentProcessDetectionEnabled else { return }
        guard let cat = catWindow else { return }
        guard let activity = AgentProcessDetector.topBusyActivity(in: activities) else {
            scheduleAgentProcessIdle(resetExisting: false)
            return
        }

        guard cat.currentState == .idle || cat.currentState == .coding || cat.currentState == .walk else { return }
        if activeAgentProcessSource != activity.source {
            cat.showBubble(NekoBubbleCopy.agentWorking(activity.label, languageCode: currentLanguageCode()))
        }
        lastUserInteraction = ProcessInfo.processInfo.systemUptime
        activeAgentProcessSource = activity.source
        cat.applyBridgeState(.coding)
        neighborNetwork?.setPresence(.coding)
        scheduleAgentProcessIdle(resetExisting: true)
    }

    private func scheduleAgentProcessIdle(resetExisting: Bool) {
        guard activeAgentProcessSource != nil else { return }
        if agentProcessIdleTimer != nil, !resetExisting { return }
        agentProcessIdleTimer?.invalidate()
        agentProcessIdleTimer = Timer.scheduledTimer(withTimeInterval: 9, repeats: false) { [weak self] _ in
            guard let self, let cat = self.catWindow else { return }
            self.agentProcessIdleTimer = nil
            guard cat.currentState == .coding else {
                self.activeAgentProcessSource = nil
                return
            }
            self.activeAgentProcessSource = nil
            cat.applyBridgeState(.idle)
            self.neighborNetwork?.setPresence(.idle)
        }
    }

    private func agentProcessDebugJSON() -> String? {
        let activityPayloads = agentProcessActivities.map { activity in
            [
                "source": activity.source,
                "label": activity.label,
                "cpu": activity.cpu,
            ] as [String: Any]
        }
        let payload: [String: Any] = [
            "enabled": appSettings.agentProcessDetectionEnabled,
            "activeSource": activeAgentProcessSource as Any? ?? NSNull(),
            "activities": activityPayloads,
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func configureNeighborNetwork() {
        neighborNetwork?.stop()
        neighborNetwork = nil
        clearGuestCats()

        guard appSettings.neighborSettings.enabled else {
            menuBar?.refresh()
            return
        }
        let peerID = ensureNeighborPeerID()
        let network = NeighborNetwork(
            myID: peerID,
            getSelf: { [weak self] in
                self?.neighborSelf() ?? NeighborSelf(name: "openNeko", skin: SkinManager.defaultID)
            },
            onEvent: { [weak self] event in
                self?.handleNeighborEvent(event)
            }
        )
        neighborNetwork = network
        network.start()
        menuBar?.refresh()
    }

    private func ensureNeighborPeerID() -> String {
        if !appSettings.peerID.isEmpty {
            return appSettings.peerID
        }
        appSettings.peerID = UUID().uuidString.lowercased()
        saveSettings()
        return appSettings.peerID
    }

    private func neighborSelf() -> NeighborSelf {
        let displayName = appSettings.catName.isEmpty ? "openNeko" : appSettings.catName
        return NeighborSelf(name: displayName, skin: selectedSkinID)
    }

    private func handleNeighborEvent(_ event: NeighborEvent) {
        menuBar?.refresh()
        settingsWindow?.refresh()
        if let text = NeighborEventPresentation.mainBubbleText(for: event, languageCode: currentLanguageCode()) {
            catWindow?.showBubble(text)
        }
        switch event {
        case .joined(let peer):
            showGuestCat(peer)
        case .left(let peer):
            removeGuestCat(peer)
        case .presence(let peer):
            updateGuestCat(peer)
        case .wave(let peer):
            showGuestCat(peer)
            catWindow?.applyBridgeState(.jump)
            guestCatWindows[peer.id]?.showBubble(NeighborEventPresentation.greeting(key: 0, languageCode: currentLanguageCode()))
            neighborNetwork?.sendGreeting(to: peer.id, key: 0)
        case .greeting(let peer, let key):
            showGuestCat(peer)
            guestCatWindows[peer.id]?.showBubble(NeighborEventPresentation.greeting(key: key, languageCode: currentLanguageCode()))
        }
    }

    private func showGuestCat(_ peer: NeighborPeer) {
        guard let catWindow, let skin = guestSkin(for: peer) else { return }
        if let guest = guestCatWindows[peer.id] {
            guest.update(peer: peer, skin: skin, languageCode: currentLanguageCode(), near: catWindow)
            return
        }

        let guest = GuestCatWindow(peer: peer, skin: skin, languageCode: currentLanguageCode(), near: catWindow)
        guest.setAlwaysOnTopEnabled(catWindow.isAlwaysOnTopEnabled)
        guest.onWave = { [weak self] peer in
            self?.sendNeighborWave(to: peer.id)
        }
        guest.onVisitExpired = { [weak self] peer in
            self?.removeGuestCat(peer)
        }
        guestCatWindows[peer.id] = guest
        guest.enter(near: catWindow)
    }

    private func updateGuestCat(_ peer: NeighborPeer) {
        if let guest = guestCatWindows[peer.id] {
            guest.updatePresence(peer.presence)
        }
    }

    private func removeGuestCat(_ peer: NeighborPeer) {
        guard let guest = guestCatWindows[peer.id] else { return }
        guest.leave(near: catWindow) { [weak self] in
            self?.guestCatWindows.removeValue(forKey: peer.id)
        }
    }

    private func clearGuestCats() {
        for guest in guestCatWindows.values {
            guest.leave(near: catWindow) {}
        }
        guestCatWindows.removeAll()
    }

    private func repositionGuestCats() {
        guard let catWindow else { return }
        for guest in guestCatWindows.values {
            guest.reposition(near: catWindow, animated: true)
        }
    }

    private func guestSkin(for peer: NeighborPeer) -> Skin? {
        if let skin = try? skinManager?.loadSkin(id: peer.skin) {
            return skin
        }
        return skinManager?.loadDefault()
    }

    private func loadSkillCatalog() -> NekoSkillCatalog {
        NekoSkillCatalog.discover(
            bundledRoot: Bundle.main.resourceURL?
                .appendingPathComponent("skills", isDirectory: true)
                .appendingPathComponent("builtin", isDirectory: true),
            userRoot: userSkillsRootURL()
        )
    }

    private func userSkillsRootURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".openneko", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
    }

    private func bundledSpritesRootURL() -> URL {
        Bundle.main.resourceURL!.appendingPathComponent("sprites", isDirectory: true)
    }

    private func externalSkinsRootURL() -> URL {
        AppSettingsStore.defaultFileURL()
            .deletingLastPathComponent()
            .appendingPathComponent("skins", isDirectory: true)
    }

    private func makeSkinPackageService() throws -> SkinPackageService {
        try SkinPackageService(
            externalRoot: externalSkinsRootURL(),
            rootManifestURL: bundledSpritesRootURL().appendingPathComponent("manifest.json")
        )
    }

    private func reloadSkills() {
        skillCatalog = loadSkillCatalog()
        reconcileActiveSkill()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func enabledSkills() -> [NekoSkill] {
        localizedSkills(skillCatalog.enabled(disabledIDs: appSettings.disabledSkillIDs))
    }

    private func localizedSkill(_ skill: NekoSkill, languageCode: String? = nil) -> NekoSkill {
        NekoSkillLocalization.localize(skill, languageCode: languageCode ?? currentLanguageCode())
    }

    private func localizedSkills(_ skills: [NekoSkill], languageCode: String? = nil) -> [NekoSkill] {
        NekoSkillLocalization.localize(skills, languageCode: languageCode ?? currentLanguageCode())
    }

    private func setSkillEnabled(id: String, enabled: Bool) {
        if enabled {
            appSettings.disabledSkillIDs.remove(id)
        } else {
            appSettings.disabledSkillIDs.insert(id)
            activeSkillSelection.clearIfMatches(id)
        }
        saveSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func setDisabledSkillIDs(_ ids: [String]) {
        appSettings.disabledSkillIDs = Set(
            ids
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        reconcileActiveSkill()
        saveSettings()
        menuBar?.refresh()
        settingsWindow?.refresh()
    }

    private func openSkillsFolder() {
        let url = userSkillsRootURL()
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
            reloadSkills()
        } catch {
            NSLog("[openNeko] failed to open skills folder: \(error)")
        }
    }

    private func openSkinsFolder() {
        let url = externalSkinsRootURL()
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
            settingsWindow?.refresh()
        } catch {
            NSLog("[openNeko] failed to open skins folder: \(error)")
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.customSkinFailed(languageCode: currentLanguageCode()))
        }
    }

    private func createCustomSkinRequest() {
        noteUserInteraction()
        let panel = NSOpenPanel()
        panel.title = "고양이 사진 선택"
        panel.message = "스킨을 만들 때 참고할 고양이 사진을 골라주세요."
        panel.prompt = "사진 선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let savePanel = NSSavePanel()
        let catName = appSettings.catName.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = SkinPackageSupport.sanitizedSkinID(from: catName.isEmpty ? "my-cat" : catName)
        savePanel.title = "스킨 요청 파일 저장"
        savePanel.message = "ChatGPT에 넣거나 제작자에게 보낼 요청 파일을 저장합니다."
        savePanel.prompt = "저장"
        savePanel.nameFieldStringValue = "\(defaultName).\(SkinPackageSupport.skinRequestExtension)"
        savePanel.allowedContentTypes = customFileTypes(extensions: [SkinPackageSupport.skinRequestExtension])

        guard savePanel.runModal() == .OK, let rawDestination = savePanel.url else { return }
        let destination = url(rawDestination, ensuringExtension: SkinPackageSupport.skinRequestExtension)

        do {
            let result = try makeSkinPackageService().createRequestPackage(
                catName: catName.isEmpty ? defaultName : catName,
                displayName: defaultName,
                baseSkinID: selectedSkinID,
                photoURLs: panel.urls,
                destinationURL: destination
            )
            NSWorkspace.shared.activateFileViewerSelecting([result.packageURL])
            catWindow?.applyBridgeState(.success)
            catWindow?.showBubble(
                NekoBubbleCopy.customSkinRequestCreated(result.recipe.displayName, languageCode: currentLanguageCode())
            )
        } catch {
            NSLog("[openNeko] failed to create custom skin request: \(error)")
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.customSkinFailed(languageCode: currentLanguageCode()))
        }
    }

    private func importCustomSkinPackage() {
        noteUserInteraction()
        let panel = NSOpenPanel()
        panel.title = "스킨팩 가져오기"
        panel.message = "완성된 .openneko-skin 파일이나 스킨 폴더를 선택하세요."
        panel.prompt = "가져오기"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = customFileTypes(extensions: [SkinPackageSupport.skinPackageExtension, "zip"])

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let result = try makeSkinPackageService().importSkinPackage(from: url)
            selectSkin(result.validation.skinID, cat: catWindow)
            NSWorkspace.shared.activateFileViewerSelecting([result.installedURL])
            catWindow?.applyBridgeState(.success)
            catWindow?.showBubble(
                NekoBubbleCopy.customSkinImported(result.validation.displayName, languageCode: currentLanguageCode())
            )
        } catch {
            NSLog("[openNeko] failed to import custom skin package: \(error)")
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.customSkinFailed(languageCode: currentLanguageCode()))
        }
    }

    private func customFileTypes(extensions: [String]) -> [UTType] {
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.data] : types
    }

    private func url(_ url: URL, ensuringExtension pathExtension: String) -> URL {
        url.pathExtension == pathExtension
            ? url
            : url.appendingPathExtension(pathExtension)
    }

    private func runSkill(id: String) {
        noteUserInteraction()
        reloadSkills()
        guard let rawSkill = skillCatalog.skill(id: id) else {
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.skillMissing(languageCode: currentLanguageCode()))
            return
        }
        let skill = localizedSkill(rawSkill)
        guard !appSettings.disabledSkillIDs.contains(skill.id) else {
            catWindow?.showBubble(NekoBubbleCopy.skillDisabled(languageCode: currentLanguageCode()))
            return
        }

        runSkill(skill: skill, inputOverride: nil)
    }

    private func runSkill(skill: NekoSkill, inputOverride: String?) {
        if skill.id == "daily-bgm" {
            runDailyBGMSkill(preference: inputOverride)
            return
        }

        if let inputOverride {
            sendSkillChat(skill: skill, input: inputOverride)
            return
        }

        switch skill.input {
        case .prompt:
            activatePromptSkill(skill)
        case .clipboard:
            let text = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                catWindow?.applyBridgeState(.error)
                catWindow?.showBubble(NekoBubbleCopy.clipboardEmpty(languageCode: currentLanguageCode()))
                return
            }
            sendSkillChat(skill: skill, input: text)
        case .none:
            sendSkillChat(skill: skill, input: "\(skill.name) 실행해줘")
        }
    }

    private func activatePromptSkill(_ skill: NekoSkill) {
        if activeSkillSelection.activate(skill) {
            chatHistory = []
        }
        pendingPromptSkill = nil
        catWindow?.showBubble(NekoBubbleCopy.skillActivated(skill.name, languageCode: currentLanguageCode()))
        catWindow?.showChat(placeholder: NekoBubbleCopy.skillPlaceholder(skill.name, languageCode: currentLanguageCode()))
    }

    private func activeSkillForCurrentLanguage() -> NekoSkill? {
        guard let skill = activeSkillSelection.resolve(
            catalog: skillCatalog,
            disabledIDs: appSettings.disabledSkillIDs
        ) else { return nil }
        return localizedSkill(skill)
    }

    private func reconcileActiveSkill() {
        activeSkillSelection.reconcile(catalog: skillCatalog, disabledIDs: appSettings.disabledSkillIDs)
    }

    private func runDailyBGMSkill(preference: String?) {
        let preference = DailyBGMSelector.normalizePreference(preference)
        if isBGMStopCommand(preference) {
            catWindow?.applyBridgeState(.success)
            catWindow?.showBubble(NekoBubbleCopy.bgmStopped(languageCode: currentLanguageCode()))
            return
        }

        let bgm = DailyBGMSelector.pick(
            preference: preference,
            profile: appSettings.userProfile,
            languageCode: currentLanguageCode()
        )
        catWindow?.applyBridgeState(.thinking)
        catWindow?.showBubble(NekoBubbleCopy.bgmSearching(languageCode: currentLanguageCode()))

        if NSWorkspace.shared.open(bgm.url) {
            catWindow?.applyBridgeState(.success)
            catWindow?.showBubble(NekoBubbleCopy.bgmOpened(title: bgm.title, query: bgm.query, languageCode: currentLanguageCode()))
        } else {
            catWindow?.applyBridgeState(.error)
            catWindow?.showBubble(NekoBubbleCopy.bgmOpenFailed(languageCode: currentLanguageCode()))
        }
    }

    private func isBGMStopCommand(_ text: String) -> Bool {
        ["stop", "off", "pause", "정지", "중지", "끄기"].contains(text.lowercased())
    }

    private func resetAIConnectionTest(refresh: Bool) {
        aiConnectionTestGeneration += 1
        aiConnectionTestTask?.cancel()
        aiConnectionTestTask = nil
        aiConnectionTestStatus = .idle(languageCode: currentLanguageCode())
        if refresh {
            settingsWindow?.refresh()
        }
    }

    private func handleKeyDown(cat: CatWindow?) {
        noteUserInteraction()
        keyDownCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        if typingTracker.keyDown(at: now) {
            cat?.setTypingActive(true, animationSpeed: typingTracker.animationSpeed)
            neighborNetwork?.setPresence(.typing)
        } else {
            cat?.updateTypingAnimationSpeed(typingTracker.animationSpeed)
        }
        scheduleTypingIdleCheck(cat: cat)
    }

    private func scheduleTypingIdleCheck(cat: CatWindow?) {
        typingTimer?.invalidate()
        let delay = max(0.05, typingTracker.nextIdleCheckDelay(at: ProcessInfo.processInfo.systemUptime))
        typingTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, weak cat] _ in
            self?.handleTypingIdleCheck(cat: cat)
        }
    }

    private func handleTypingIdleCheck(cat: CatWindow?) {
        let now = ProcessInfo.processInfo.systemUptime
        if typingTracker.tick(at: now) {
            cat?.setTypingActive(false)
            neighborNetwork?.setPresence(.idle)
        }
        if typingTracker.isTyping {
            scheduleTypingIdleCheck(cat: cat)
        }
    }

    private func debugTypingJSON(cat: CatWindow?) -> String {
        handleKeyDown(cat: cat)
        return #"{"ok":true,"keydownCount":\#(keyDownCount),"typingAnimationSpeed":\#(typingTracker.animationSpeed)}"#
    }

    private func typingStatusDebugJSON() -> String? {
        let permission = InputMonitoringPermissionController.menu
        let payload: [String: Any] = [
            "keyDownCount": keyDownCount,
            "isTyping": typingTracker.isTyping,
            "typingAnimationSpeed": typingTracker.animationSpeed,
            "monitorActive": keyboardMonitor?.isActive == true,
            "monitorMode": keyboardMonitor?.mode.rawValue ?? KeyboardMonitor.Mode.inactive.rawValue,
            "retryScheduled": keyboardMonitorRetryTimer != nil,
            "accessibilityGranted": permission.accessibilityGranted,
            "inputMonitoringGranted": permission.inputMonitoringGranted,
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func debugSettingsApplyJSON(body: Data) -> String {
        guard launchOptions.debugSettingsMutationEnabled else {
            return DebugSettingsApplyResponse(
                ok: false,
                reason: "debug-settings-mutation-disabled",
                settings: AppSettingsDebugSnapshot(settings: appSettings)
            ).jsonString()
        }

        let mutation: DebugSettingsMutation
        do {
            mutation = try JSONDecoder().decode(DebugSettingsMutation.self, from: body)
        } catch {
            return DebugSettingsApplyResponse(
                ok: false,
                reason: "invalid-json",
                settings: AppSettingsDebugSnapshot(settings: appSettings)
            ).jsonString()
        }

        if let presetID = mutation.aiProviderPresetID {
            selectAIProviderPreset(presetID)
        }
        if let baseURL = mutation.aiProviderBaseURL {
            updateAIProviderBaseURL(baseURL)
        }
        if let model = mutation.aiProviderModel {
            updateAIProviderModel(model)
        }
        if let selectedSkinID = mutation.selectedSkinID {
            selectSkin(selectedSkinID, cat: catWindow)
        }
        if let hasCompletedFirstLaunch = mutation.hasCompletedFirstLaunch {
            setFirstLaunchCompleted(hasCompletedFirstLaunch)
        }
        if let disabledSkillIDs = mutation.disabledSkillIDs {
            setDisabledSkillIDs(disabledSkillIDs)
        }
        if let agentProcessDetectionEnabled = mutation.agentProcessDetectionEnabled {
            setAgentProcessDetection(agentProcessDetectionEnabled)
        }
        if let languageCode = mutation.languageCode {
            setLanguageCode(languageCode == "system" ? nil : languageCode)
        }
        if let soundEffectsEnabled = mutation.soundEffectsEnabled {
            setSoundEffects(soundEffectsEnabled)
        }
        if let webSearchEnabled = mutation.webSearchEnabled {
            setWebSearch(webSearchEnabled)
        }
        if let catName = mutation.catName {
            setCatName(catName)
        }
        if let userProfile = mutation.userProfile {
            setUserProfile(userProfile)
        }
        if let neighborEnabled = mutation.neighborEnabled {
            setNeighborEnabled(neighborEnabled)
        }
        if let neighborDisplayName = mutation.neighborDisplayName {
            setNeighborDisplayName(neighborDisplayName)
        }

        menuBar?.refresh()
        settingsWindow?.refresh()
        return DebugSettingsApplyResponse(
            ok: true,
            reason: nil,
            settings: AppSettingsDebugSnapshot(settings: appSettings)
        ).jsonString()
    }

    private func handleBridgeEvent(_ event: StateBridgeEvent, cat: CatWindow?) {
        noteUserInteraction(showWakeBubble: false)
        bridgeIdleTimer?.invalidate()
        autonomousStateTimer?.invalidate()
        cat?.applyBridgeState(event.state)
        neighborNetwork?.setPresence(NeighborPresence.coarse(for: event.state))
        if let text = StateBubbleText.text(for: event, languageCode: currentLanguageCode()) {
            cat?.showBubble(text)
        }

        guard event.state != .idle, !bridgeOneShotStates.contains(event.state) else { return }
        bridgeIdleTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self, weak cat] _ in
            cat?.applyBridgeState(.idle)
            self?.neighborNetwork?.setPresence(.idle)
        }
    }

    private var bridgeOneShotStates: Set<CatState> {
        [.click, .yawn, .success, .error, .jump]
    }

    private func cancelActiveChatRequest() {
        chatGeneration += 1
        activeChatTask?.cancel()
        activeChatTask = nil
    }

    private func showChatHistory() {
        let controller = chatHistoryWindowController ?? ChatHistoryWindowController()
        chatHistoryWindowController = controller
        controller.show(state: chatHistoryWindowState())
    }

    private func refreshChatHistoryWindow() {
        chatHistoryWindowController?.refresh(state: chatHistoryWindowState())
    }

    private func chatHistoryWindowState() -> ChatHistoryWindowController.State {
        ChatHistoryWindowController.State(
            messages: chatTranscript,
            languageCode: currentLanguageCode()
        )
    }

    private func appendChatTranscript(_ message: ChatMessage) {
        chatTranscript.append(message)
        if chatTranscript.count > 160 {
            chatTranscript = Array(chatTranscript.suffix(160))
        }
        refreshChatHistoryWindow()
    }

    private func removeFailedTranscriptTurn(_ message: String) {
        if let last = chatTranscript.last, last.role == .user, last.text == message {
            chatTranscript.removeLast()
            refreshChatHistoryWindow()
        }
    }

    private func resetChatTranscript() {
        chatTranscript = []
        refreshChatHistoryWindow()
    }

    private func showCopyableReplyBubble(_ reply: String) {
        catWindow?.showBubble(
            reply,
            onClick: { [weak self] in
                self?.copyReplyToClipboard(reply)
            },
            helpText: NekoBubbleCopy.copyReplyHelp(languageCode: currentLanguageCode())
        )
    }

    private func copyReplyToClipboard(_ reply: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reply, forType: .string)
        catWindow?.showBubble(NekoBubbleCopy.replyCopied(languageCode: currentLanguageCode()))
    }

    private func handleSlashCommand(_ message: String, cat: CatWindow?) -> Bool {
        guard let slash = SlashCommandParser.parse(message) else { return false }
        let command = slash.command
        let argument = slash.arguments

        switch command {
        case "help":
            let skillNames = enabledSkills().prefix(3).map { "/\($0.id)" }.joined(separator: " ")
            let suffix = skillNames.isEmpty ? "" : "\n\(skillNames)"
            cat?.showBubble(NekoBubbleCopy.slashHelp(suffix: suffix, languageCode: currentLanguageCode()))
            return true
        case "reset":
            cancelActiveChatRequest()
            chatHistory = []
            resetChatTranscript()
            pendingPromptSkill = nil
            activeSkillSelection.clear()
            cat?.applyBridgeState(.success)
            cat?.showBubble(NekoBubbleCopy.chatReset(languageCode: currentLanguageCode()))
            return true
        case "skin":
            if argument.isEmpty {
                let ids = skinManager?.availableSkinIDs().joined(separator: ", ") ?? SkinManager.defaultID
                cat?.showBubble(NekoBubbleCopy.skinList(ids, languageCode: currentLanguageCode()))
                return true
            }
            guard skinManager?.availableSkinIDs().contains(argument) == true else {
                cat?.applyBridgeState(.error)
                cat?.showBubble(NekoBubbleCopy.skinMissing(languageCode: currentLanguageCode()))
                return true
            }
            selectSkin(argument, cat: cat)
            cat?.applyBridgeState(.success)
            cat?.showBubble(NekoBubbleCopy.skinChanged(skinLabel(argument), languageCode: currentLanguageCode()))
            return true
        case "lang":
            if argument.isEmpty {
                cat?.showBubble(NekoBubbleCopy.currentLanguage(AppLanguage.displayName(for: currentLanguageCode()), languageCode: currentLanguageCode()))
                return true
            }
            let code = argument.lowercased()
            if code == "system" || code == "auto" || code == "default" {
                setLanguageCode(nil)
                cat?.showBubble(NekoBubbleCopy.systemLanguage(languageCode: currentLanguageCode()))
                return true
            }
            guard AppLanguage.normalized(code) != nil else {
                cat?.applyBridgeState(.error)
                cat?.showBubble(NekoBubbleCopy.supportedLanguages(languageCode: currentLanguageCode()))
                return true
            }
            setLanguageCode(code)
            cat?.showBubble(NekoBubbleCopy.currentLanguage(AppLanguage.displayName(for: code), languageCode: currentLanguageCode()))
            return true
        case "sound":
            let enabled: Bool
            switch argument.lowercased() {
            case "on", "true", "1", "켜기":
                enabled = true
            case "off", "false", "0", "끄기":
                enabled = false
            case "":
                enabled = !appSettings.soundEffectsEnabled
            default:
                cat?.applyBridgeState(.error)
                cat?.showBubble(NekoBubbleCopy.soundUsage(languageCode: currentLanguageCode()))
                return true
            }
            setSoundEffects(enabled)
            cat?.showBubble(NekoBubbleCopy.soundEnabled(enabled, languageCode: currentLanguageCode()))
            return true
        default:
            reloadSkills()
            guard let rawSkill = skillCatalog.skill(id: command) else {
                cat?.applyBridgeState(.error)
                cat?.showBubble(NekoBubbleCopy.unknownCommand(languageCode: currentLanguageCode()))
                return true
            }
            let skill = localizedSkill(rawSkill)
            guard !appSettings.disabledSkillIDs.contains(skill.id) else {
                cat?.showBubble(NekoBubbleCopy.skillDisabled(languageCode: currentLanguageCode()))
                return true
            }
            runSkill(skill: skill, inputOverride: argument.isEmpty ? nil : argument)
            return true
        }
    }

    private func slashCommandCatalog() -> [SlashCommandDescriptor] {
        let languageCode = currentLanguageCode()
        let appCommands = [
            SlashCommandDescriptor(
                name: "help",
                kind: .builtin,
                description: slashDescription(.help, languageCode: languageCode)
            ),
            SlashCommandDescriptor(
                name: "reset",
                kind: .builtin,
                description: slashDescription(.reset, languageCode: languageCode)
            ),
            SlashCommandDescriptor(
                name: "skin",
                kind: .app,
                description: slashDescription(.skin, languageCode: languageCode)
            ),
            SlashCommandDescriptor(
                name: "lang",
                kind: .app,
                description: slashDescription(.lang, languageCode: languageCode)
            ),
            SlashCommandDescriptor(
                name: "sound",
                kind: .app,
                description: slashDescription(.sound, languageCode: languageCode)
            ),
        ]
        let skillCommands = enabledSkills().map {
            SlashCommandDescriptor(
                name: $0.id,
                kind: .skill,
                description: $0.description.isEmpty ? $0.name : $0.description
            )
        }
        return appCommands + skillCommands
    }

    private enum SlashDescriptionKey {
        case help, reset, skin, lang, sound
    }

    private func slashDescription(_ key: SlashDescriptionKey, languageCode: String) -> String {
        switch (AppLanguage.normalized(languageCode) ?? "ko", key) {
        case ("en", .help): "Show commands"
        case ("en", .reset): "Reset chat"
        case ("en", .skin): "Change skin"
        case ("en", .lang): "Change language"
        case ("en", .sound): "Toggle sound"
        case ("ja", .help): "コマンドを表示"
        case ("ja", .reset): "会話をリセット"
        case ("ja", .skin): "スキンを変更"
        case ("ja", .lang): "言語を変更"
        case ("ja", .sound): "効果音を切替"
        case ("zh", .help): "显示命令"
        case ("zh", .reset): "重置对话"
        case ("zh", .skin): "切换皮肤"
        case ("zh", .lang): "切换语言"
        case ("zh", .sound): "切换音效"
        case (_, .help): "명령 보기"
        case (_, .reset): "대화 초기화"
        case (_, .skin): "스킨 변경"
        case (_, .lang): "언어 변경"
        case (_, .sound): "효과음 전환"
        }
    }

    private func sendChat(_ text: String, cat: CatWindow?) {
        noteUserInteraction()
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        if let skill = pendingPromptSkill {
            pendingPromptSkill = nil
            sendSkillChat(skill: skill, input: message)
            return
        }

        if handleSlashCommand(text, cat: cat) {
            return
        }

        cancelActiveChatRequest()
        let generation = chatGeneration
        let storedMessage = String(message.prefix(2_000))
        chatHistory.append(ChatMessage(role: .user, text: storedMessage))
        appendChatTranscript(ChatMessage(role: .user, text: storedMessage))
        if chatHistory.count > 12 {
            chatHistory = Array(chatHistory.suffix(12))
        }

        let providerConfig = appSettings.aiProvider
        let apiKey = resolvedAPIKey(for: providerConfig)
        let history = chatHistory
        let activeSkill = activeSkillForCurrentLanguage()
        let system = currentSystemPrompt(skill: activeSkill)
        cat?.applyBridgeState(.thinking)
        cat?.showBubble(NekoBubbleCopy.thinking(skillName: activeSkill?.name, languageCode: currentLanguageCode()))

        activeChatTask = Task { [weak self] in
            do {
                let reply = try await self?.chatReply(
                    providerConfig: providerConfig,
                    apiKey: apiKey,
                    history: history,
                    system: system,
                    onPartial: { [weak self] partial in
                        Task { @MainActor [weak self] in
                            self?.updateStreamingChat(generation: generation, text: partial)
                        }
                    }
                ) ?? ""
                await self?.finishChat(generation: generation, reply: reply)
            } catch is CancellationError {
                return
            } catch {
                await self?.failChat(generation: generation, message: storedMessage, error: error)
            }
        }
    }

    private func resolvedAPIKey(for provider: AIProviderConfig) -> String? {
        AIProviderPreset.resolveAPIKey(
            presetID: provider.presetID,
            savedKey: apiKeyStore.apiKey(for: provider.presetID),
            environment: ProcessInfo.processInfo.environment
        )
    }

    private func chatReply(
        providerConfig: AIProviderConfig,
        apiKey: String?,
        history: [ChatMessage],
        system: String? = nil,
        onPartial: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let languageCode = currentLanguageCode()
        let system = system ?? currentSystemPrompt(skill: nil)
        switch providerConfig.type {
        case .codexCLI:
            return try await CodexChatProvider(
                model: providerConfig.model,
                languageCode: languageCode
            ).chat(history: history, system: system)
        case .claudeCLI:
            return try await AgentCLIChatProvider(
                kind: .claude,
                model: providerConfig.model,
                languageCode: languageCode
            ).chat(history: history, system: system)
        case .geminiCLI:
            return try await AgentCLIChatProvider(
                kind: .gemini,
                model: providerConfig.model,
                languageCode: languageCode
            ).chat(history: history, system: system)
        case .openAICompatible, .gemini, .anthropic:
            return try await HTTPChatProvider(
                config: providerConfig,
                apiKey: apiKey,
                languageCode: languageCode
            ).chat(history: history, system: system, onPartial: onPartial)
        }
    }

    private func sendSkillChat(skill: NekoSkill, input: String) {
        let storedInput = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(6_000))
        guard !storedInput.isEmpty else { return }

        cancelActiveChatRequest()
        let generation = chatGeneration
        let providerConfig = appSettings.aiProvider
        let apiKey = resolvedAPIKey(for: providerConfig)
        let system = currentSystemPrompt(skill: skill)
        let history = [ChatMessage(role: .user, text: storedInput)]
        appendChatTranscript(ChatMessage(role: .user, text: storedInput))

        catWindow?.applyBridgeState(.thinking)
        catWindow?.showBubble(NekoBubbleCopy.skillRunning(skill.name, languageCode: currentLanguageCode()))

        activeChatTask = Task { [weak self] in
            do {
                let reply = try await self?.chatReply(
                    providerConfig: providerConfig,
                    apiKey: apiKey,
                    history: history,
                    system: system
                ) ?? ""
                await self?.finishSkillChat(generation: generation, reply: reply)
            } catch is CancellationError {
                return
            } catch {
                await self?.failSkillChat(generation: generation, message: storedInput, error: error)
            }
        }
    }

    private func testAIProviderConnection() {
        guard !aiConnectionTestStatus.isRunning else { return }

        let provider = appSettings.aiProvider
        let apiKey = resolvedAPIKey(for: provider)
        let readiness = aiProviderReadiness(for: provider, resolvedAPIKey: apiKey)
        guard readiness.severity != .needsAction else {
            aiConnectionTestStatus = .failure(message: readiness.detail, languageCode: currentLanguageCode())
            settingsWindow?.refresh()
            return
        }

        let preset = AIProviderPreset.preset(for: provider.presetID)
            ?? AIProviderPreset.preset(for: AIProviderPreset.defaultID)!
        let providerID = provider.presetID
        aiConnectionTestGeneration += 1
        let generation = aiConnectionTestGeneration
        aiConnectionTestStatus = .running(providerTitle: preset.title(languageCode: currentLanguageCode()), languageCode: currentLanguageCode())
        settingsWindow?.refresh()

        let history = [
            ChatMessage(role: .user, text: "openNeko 연결 테스트입니다. '준비됨'이라고 짧게 답해주세요.")
        ]
        aiConnectionTestTask = Task { [weak self] in
            do {
                let reply = try await self?.chatReply(
                    providerConfig: provider,
                    apiKey: apiKey,
                    history: history
                ) ?? ""
                await self?.finishAIConnectionTest(
                    providerID: providerID,
                    generation: generation,
                    reply: reply
                )
            } catch {
                await self?.failAIConnectionTest(
                    providerID: providerID,
                    generation: generation,
                    error: error
                )
            }
        }
    }

    @MainActor
    private func finishAIConnectionTest(providerID: String, generation: Int, reply: String) {
        guard appSettings.aiProvider.presetID == providerID, aiConnectionTestGeneration == generation else { return }
        aiConnectionTestTask = nil
        aiConnectionTestStatus = .success(reply: reply, languageCode: currentLanguageCode())
        settingsWindow?.refresh()
    }

    @MainActor
    private func failAIConnectionTest(providerID: String, generation: Int, error: Error) {
        guard appSettings.aiProvider.presetID == providerID, aiConnectionTestGeneration == generation else { return }
        aiConnectionTestTask = nil
        aiConnectionTestStatus = .failure(message: chatErrorMessage(error), languageCode: currentLanguageCode())
        settingsWindow?.refresh()
    }

    @MainActor
    private func finishSkillChat(generation: Int, reply: String) {
        guard chatGeneration == generation else { return }
        activeChatTask = nil
        let displayReply = NekoBubbleCopy.styledChatReply(reply, languageCode: currentLanguageCode())
        appendChatTranscript(ChatMessage(role: .assistant, text: displayReply))
        catWindow?.applyBridgeState(.success)
        showCopyableReplyBubble(displayReply)
    }

    @MainActor
    private func failSkillChat(generation: Int, message: String, error: Error) {
        guard chatGeneration == generation else { return }
        activeChatTask = nil
        removeFailedTranscriptTurn(message)
        catWindow?.applyBridgeState(.error)
        catWindow?.showBubble(chatErrorMessage(error))
    }

    @MainActor
    private func updateStreamingChat(generation: Int, text: String) {
        guard chatGeneration == generation, activeChatTask != nil else { return }
        catWindow?.applyBridgeState(.coding)
        catWindow?.showBubble(text)
    }

    @MainActor
    private func finishChat(generation: Int, reply: String) {
        guard chatGeneration == generation else { return }
        activeChatTask = nil
        let displayReply = NekoBubbleCopy.styledChatReply(reply, languageCode: currentLanguageCode())
        chatHistory.append(ChatMessage(role: .assistant, text: displayReply))
        appendChatTranscript(ChatMessage(role: .assistant, text: displayReply))
        if chatHistory.count > 12 {
            chatHistory = Array(chatHistory.suffix(12))
        }
        catWindow?.applyBridgeState(.success)
        showCopyableReplyBubble(displayReply)
    }

    @MainActor
    private func failChat(generation: Int, message: String, error: Error) {
        guard chatGeneration == generation else { return }
        activeChatTask = nil
        removeFailedChatTurn(message)
        removeFailedTranscriptTurn(message)
        catWindow?.applyBridgeState(.error)
        catWindow?.showBubble(chatErrorMessage(error))
    }

    private func removeFailedChatTurn(_ message: String) {
        if let last = chatHistory.last, last.role == .user, last.text == message {
            chatHistory.removeLast()
        }
    }

    private func chatErrorMessage(_ error: Error) -> String {
        let languageCode = currentLanguageCode()
        if let error = error as? CodexChatError {
            return error.userMessage(languageCode: languageCode)
        }
        if let error = error as? HTTPChatError {
            return error.userMessage(languageCode: languageCode)
        }
        if let error = error as? AgentCLIChatError {
            return error.userMessage(languageCode: languageCode)
        }
        return NekoBubbleCopy.genericChatError(languageCode: languageCode)
    }
}
