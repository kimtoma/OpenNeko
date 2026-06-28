import AppKit
import SwiftUI
import OpenNekoKit

final class SettingsWindowController {
    struct State {
        let permissionMenu: InputMonitoringPermissionMenu
        let launchAtLogin: LaunchAtLoginSetting
        let aiProvider: AIProviderConfig
        let aiProviderHasAPIKey: Bool
        let aiProviderReadiness: AIProviderReadiness
        let aiProviderConnectionTest: AIProviderConnectionTestStatus
        let aiProviderDetections: [AIProviderDetection]
        let isOnboardingVisible: Bool
        let skills: [NekoSkill]
        let disabledSkillIDs: Set<String>
        let agentProcessDetectionEnabled: Bool
        let languageCode: String?
        let resolvedLanguageCode: String
        let soundEffectsEnabled: Bool
        let webSearchEnabled: Bool
        let catName: String
        let userProfile: UserProfile
        let neighborSettings: NeighborSettings
        let neighborPeerCount: Int
        let peerID: String
        let stateBridgePort: UInt16
        let skinIDs: [String]
        let skinPreviewFrameURLs: [String: [URL]]
        let selectedSkinID: String
        let version: String
    }

    private var window: NSWindow?
    private let state: () -> State
    private let openAccessibility: () -> Void
    private let openInputMonitoring: () -> Void
    private let retryKeyboardMonitor: () -> Void
    private let setLaunchAtLogin: (Bool) -> Void
    private let setAgentProcessDetection: (Bool) -> Void
    private let setLanguageCode: (String?) -> Void
    private let setSoundEffects: (Bool) -> Void
    private let setWebSearch: (Bool) -> Void
    private let setCatName: (String) -> Void
    private let setUserProfile: (UserProfile) -> Void
    private let setNeighborEnabled: (Bool) -> Void
    private let setNeighborDisplayName: (String) -> Void
    private let sendNeighborWave: () -> Void
    private let selectAIProviderPreset: (String) -> Void
    private let updateAIProviderBaseURL: (String) -> Void
    private let updateAIProviderModel: (String) -> Void
    private let saveAIProviderAPIKey: (String) -> Void
    private let clearAIProviderAPIKey: () -> Void
    private let testAIProviderConnection: () -> Void
    private let applyAIProviderDetection: (AIProviderDetection) -> Void
    private let refreshAIProviderDetections: () -> Void
    private let showOnboarding: () -> Void
    private let completeOnboarding: () -> Void
    private let runSkill: (String) -> Void
    private let setSkillEnabled: (String, Bool) -> Void
    private let openSkillsFolder: () -> Void
    private let createCustomSkinRequest: () -> Void
    private let importCustomSkinPackage: () -> Void
    private let openSkinsFolder: () -> Void
    private let selectSkin: (String) -> Void

    init(
        state: @escaping () -> State,
        openAccessibility: @escaping () -> Void,
        openInputMonitoring: @escaping () -> Void,
        retryKeyboardMonitor: @escaping () -> Void,
        setLaunchAtLogin: @escaping (Bool) -> Void,
        setAgentProcessDetection: @escaping (Bool) -> Void,
        setLanguageCode: @escaping (String?) -> Void,
        setSoundEffects: @escaping (Bool) -> Void,
        setWebSearch: @escaping (Bool) -> Void,
        setCatName: @escaping (String) -> Void,
        setUserProfile: @escaping (UserProfile) -> Void,
        setNeighborEnabled: @escaping (Bool) -> Void,
        setNeighborDisplayName: @escaping (String) -> Void,
        sendNeighborWave: @escaping () -> Void,
        selectAIProviderPreset: @escaping (String) -> Void,
        updateAIProviderBaseURL: @escaping (String) -> Void,
        updateAIProviderModel: @escaping (String) -> Void,
        saveAIProviderAPIKey: @escaping (String) -> Void,
        clearAIProviderAPIKey: @escaping () -> Void,
        testAIProviderConnection: @escaping () -> Void,
        applyAIProviderDetection: @escaping (AIProviderDetection) -> Void,
        refreshAIProviderDetections: @escaping () -> Void,
        showOnboarding: @escaping () -> Void,
        completeOnboarding: @escaping () -> Void,
        runSkill: @escaping (String) -> Void,
        setSkillEnabled: @escaping (String, Bool) -> Void,
        openSkillsFolder: @escaping () -> Void,
        createCustomSkinRequest: @escaping () -> Void,
        importCustomSkinPackage: @escaping () -> Void,
        openSkinsFolder: @escaping () -> Void,
        selectSkin: @escaping (String) -> Void
    ) {
        self.state = state
        self.openAccessibility = openAccessibility
        self.openInputMonitoring = openInputMonitoring
        self.retryKeyboardMonitor = retryKeyboardMonitor
        self.setLaunchAtLogin = setLaunchAtLogin
        self.setAgentProcessDetection = setAgentProcessDetection
        self.setLanguageCode = setLanguageCode
        self.setSoundEffects = setSoundEffects
        self.setWebSearch = setWebSearch
        self.setCatName = setCatName
        self.setUserProfile = setUserProfile
        self.setNeighborEnabled = setNeighborEnabled
        self.setNeighborDisplayName = setNeighborDisplayName
        self.sendNeighborWave = sendNeighborWave
        self.selectAIProviderPreset = selectAIProviderPreset
        self.updateAIProviderBaseURL = updateAIProviderBaseURL
        self.updateAIProviderModel = updateAIProviderModel
        self.saveAIProviderAPIKey = saveAIProviderAPIKey
        self.clearAIProviderAPIKey = clearAIProviderAPIKey
        self.testAIProviderConnection = testAIProviderConnection
        self.applyAIProviderDetection = applyAIProviderDetection
        self.refreshAIProviderDetections = refreshAIProviderDetections
        self.showOnboarding = showOnboarding
        self.completeOnboarding = completeOnboarding
        self.runSkill = runSkill
        self.setSkillEnabled = setSkillEnabled
        self.openSkillsFolder = openSkillsFolder
        self.createCustomSkinRequest = createCustomSkinRequest
        self.importCustomSkinPackage = importCustomSkinPackage
        self.openSkinsFolder = openSkinsFolder
        self.selectSkin = selectSkin
    }

    func show() {
        let root = makeRootView()
        if let window {
            (window.contentViewController as? NSHostingController<SettingsView>)?.rootView = root
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NSLog("[openNeko] settings window shown frame=\(window.frame)")
            return
        }

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "openNeko 설정"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: SettingsGlassStyle.windowWidth,
            height: SettingsGlassStyle.windowHeight
        )
        window.setContentSize(NSSize(
            width: SettingsGlassStyle.windowWidth,
            height: SettingsGlassStyle.windowHeight
        ))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("[openNeko] settings window shown frame=\(window.frame)")
    }

    func refresh() {
        guard let hosting = window?.contentViewController as? NSHostingController<SettingsView> else { return }
        hosting.rootView = makeRootView()
    }

    func capturePNGData() -> Data? {
        guard let window, let contentView = window.contentView else { return nil }
        if let item = window.openNekoCaptureItem(),
           let data = WindowCapture.pngData(items: [item]) {
            return data
        }
        window.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        let bounds = contentView.bounds
        guard
            bounds.width > 0,
            bounds.height > 0,
            let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds)
        else {
            return nil
        }
        bitmap.size = bounds.size
        contentView.cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    private func makeRootView() -> SettingsView {
        let state = state()
        return SettingsView(
            permissionMenu: state.permissionMenu,
            launchAtLogin: state.launchAtLogin,
            aiProvider: state.aiProvider,
            aiProviderHasAPIKey: state.aiProviderHasAPIKey,
            aiProviderReadiness: state.aiProviderReadiness,
            aiProviderConnectionTest: state.aiProviderConnectionTest,
            aiProviderDetections: state.aiProviderDetections,
            isOnboardingVisible: state.isOnboardingVisible,
            skills: state.skills,
            disabledSkillIDs: state.disabledSkillIDs,
            agentProcessDetectionEnabled: state.agentProcessDetectionEnabled,
            languageCode: state.languageCode,
            resolvedLanguageCode: state.resolvedLanguageCode,
            soundEffectsEnabled: state.soundEffectsEnabled,
            webSearchEnabled: state.webSearchEnabled,
            catName: state.catName,
            userProfile: state.userProfile,
            neighborSettings: state.neighborSettings,
            neighborPeerCount: state.neighborPeerCount,
            peerID: state.peerID,
            stateBridgePort: state.stateBridgePort,
            skinIDs: state.skinIDs,
            skinPreviewFrameURLs: state.skinPreviewFrameURLs,
            selectedSkinID: state.selectedSkinID,
            version: state.version,
            openAccessibility: openAccessibility,
            openInputMonitoring: openInputMonitoring,
            retryKeyboardMonitor: retryKeyboardMonitor,
            setLaunchAtLogin: setLaunchAtLogin,
            setAgentProcessDetection: setAgentProcessDetection,
            setLanguageCode: setLanguageCode,
            setSoundEffects: setSoundEffects,
            setWebSearch: setWebSearch,
            setCatName: setCatName,
            setUserProfile: setUserProfile,
            setNeighborEnabled: setNeighborEnabled,
            setNeighborDisplayName: setNeighborDisplayName,
            sendNeighborWave: sendNeighborWave,
            selectAIProviderPreset: selectAIProviderPreset,
            updateAIProviderBaseURL: updateAIProviderBaseURL,
            updateAIProviderModel: updateAIProviderModel,
            saveAIProviderAPIKey: saveAIProviderAPIKey,
            clearAIProviderAPIKey: clearAIProviderAPIKey,
            testAIProviderConnection: testAIProviderConnection,
            applyAIProviderDetection: applyAIProviderDetection,
            refreshAIProviderDetections: refreshAIProviderDetections,
            showOnboarding: showOnboarding,
            completeOnboarding: completeOnboarding,
            runSkill: runSkill,
            setSkillEnabled: setSkillEnabled,
            openSkillsFolder: openSkillsFolder,
            createCustomSkinRequest: createCustomSkinRequest,
            importCustomSkinPackage: importCustomSkinPackage,
            openSkinsFolder: openSkinsFolder,
            selectSkin: selectSkin
        )
    }
}
