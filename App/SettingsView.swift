import AppKit
import CoreText
import SwiftUI
import OpenNekoKit

private let openNekoGitHubURL = URL(string: "https://github.com/kimtoma/openNeko")!
private let openNekoLicenseURL = URL(string: "https://github.com/kimtoma/openNeko/blob/main/LICENSE")!
private let kimtomaURL = URL(string: "https://kimtoma.com")!

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case skin
    case name
    case permissions
    case ai
    case done

    func title(languageCode: String?) -> String {
        switch self {
        case .welcome:
            return SettingsCopy.text(.onboardingWelcomeTitle, languageCode: languageCode)
        case .skin:
            return SettingsCopy.text(.onboardingSkinTitle, languageCode: languageCode)
        case .name:
            return SettingsCopy.text(.onboardingNameTitle, languageCode: languageCode)
        case .permissions:
            return SettingsCopy.text(.onboardingPermissionTitle, languageCode: languageCode)
        case .ai:
            return SettingsCopy.text(.onboardingAITitle, languageCode: languageCode)
        case .done:
            return SettingsCopy.text(.onboardingDoneTitle, languageCode: languageCode)
        }
    }

    func body(languageCode: String?) -> String {
        switch self {
        case .welcome:
            return SettingsCopy.text(.onboardingWelcomeBody, languageCode: languageCode)
        case .skin:
            return SettingsCopy.text(.onboardingSkinBody, languageCode: languageCode)
        case .name:
            return SettingsCopy.text(.onboardingNameBody, languageCode: languageCode)
        case .permissions:
            return SettingsCopy.text(.onboardingPermissionBody, languageCode: languageCode)
        case .ai:
            return SettingsCopy.text(.onboardingAIBody, languageCode: languageCode)
        case .done:
            return SettingsCopy.text(.onboardingDoneBody, languageCode: languageCode)
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: return "pawprint.fill"
        case .skin: return "paintpalette.fill"
        case .name: return "textformat"
        case .permissions: return "hand.raised.fill"
        case .ai: return "sparkles"
        case .done: return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .welcome: return .accentColor
        case .skin: return .purple
        case .name: return .teal
        case .permissions: return .orange
        case .ai: return .accentColor
        case .done: return .green
        }
    }
}

struct SettingsView: View {
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
    let updateStatus: AppUpdateStatus
    let checkForUpdates: () -> Void
    let openAccessibility: () -> Void
    let openInputMonitoring: () -> Void
    let retryKeyboardMonitor: () -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let setAgentProcessDetection: (Bool) -> Void
    let setLanguageCode: (String?) -> Void
    let setSoundEffects: (Bool) -> Void
    let setWebSearch: (Bool) -> Void
    let setCatName: (String) -> Void
    let setUserProfile: (UserProfile) -> Void
    let setNeighborEnabled: (Bool) -> Void
    let setNeighborDisplayName: (String) -> Void
    let sendNeighborWave: () -> Void
    let selectAIProviderPreset: (String) -> Void
    let updateAIProviderBaseURL: (String) -> Void
    let updateAIProviderModel: (String) -> Void
    let saveAIProviderAPIKey: (String) -> Void
    let clearAIProviderAPIKey: () -> Void
    let testAIProviderConnection: () -> Void
    let applyAIProviderDetection: (AIProviderDetection) -> Void
    let refreshAIProviderDetections: () -> Void
    let showOnboarding: () -> Void
    let completeOnboarding: () -> Void
    let runSkill: (String) -> Void
    let setSkillEnabled: (String, Bool) -> Void
    let openSkillsFolder: () -> Void
    let createCustomSkinRequest: () -> Void
    let importCustomSkinPackage: () -> Void
    let openSkinsFolder: () -> Void
    let selectSkin: (String) -> Void
    @State private var selectedPaneRaw = SettingsPane.start.rawValue
    @State private var onboardingStepRaw = OnboardingStep.welcome.rawValue
    @State private var didCopyBridgeCommand = false
    @State private var catNameDraft: String?
    @State private var profileDraft: UserProfile?

    var body: some View {
        ZStack {
            SettingsGlassBackground()
            VStack(spacing: isOnboardingVisible ? 0 : 8) {
                if isOnboardingVisible {
                    onboardingWizard
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        SettingsSidebarSelector(
                            selection: selectedPaneBinding,
                            panes: visibleSettingsPanes,
                            languageCode: resolvedLanguageCode
                        )
                        .frame(width: 166, alignment: .top)
                        .frame(maxHeight: .infinity, alignment: .top)

                        Divider()
                            .opacity(0.55)

                        selectedPaneContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(
            width: CGFloat(SettingsGlassStyle.windowWidth),
            height: CGFloat(SettingsGlassStyle.windowHeight)
        )
        .onChange(of: catName) { _, newValue in
            catNameDraft = SettingsDraftSynchronization.reconciledDraft(
                catNameDraft,
                storedValue: newValue
            )
        }
        .onChange(of: userProfile) { _, newValue in
            profileDraft = SettingsDraftSynchronization.reconciledDraft(
                profileDraft,
                storedValue: newValue
            )
        }
    }

    private var settingsWindowTitle: String {
        if isOnboardingVisible {
            return SettingsCopy.text(.onboardingTitle, languageCode: resolvedLanguageCode)
        }
        return selectedPane.title(languageCode: resolvedLanguageCode)
    }

    private var visibleSettingsPanes: [SettingsPane] {
        [.start, .skins, .profile, .general, .ai, .skills, .about]
    }

    private var profileControlWidth: CGFloat { 260 }

    private var unifiedSettingsPage: some View {
        SettingsGlassPane(
            title: "openNeko",
            subtitle: copy(.startSubtitle)
        ) {
            unifiedSummarySection
            unifiedAISection
            unifiedAppearanceSection
            unifiedProfileSection
            unifiedSkillsSection
            unifiedGeneralSection
            unifiedFooterSection
        }
    }

    private var unifiedSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassHero(
                title: setupTitle,
                subtitle: setupSubtitle,
                systemImage: "pawprint.fill",
                tint: setupTint
            )

            HStack(spacing: 8) {
                SettingsGlassSummaryChip(
                    title: SettingsPane.ai.title(languageCode: resolvedLanguageCode),
                    value: aiProviderSummary,
                    systemImage: "sparkles",
                    tint: .accentColor
                )
                SettingsGlassSummaryChip(
                    title: copy(.catName),
                    value: catSummary,
                    systemImage: "pawprint",
                    tint: .teal
                )
                SettingsGlassSummaryChip(
                    title: copy(.language),
                    value: languageSummary,
                    systemImage: "globe",
                    tint: .blue
                )
            }

            if permissionMenu.needsUserAction {
                SettingsGlassStatusRow(
                    title: copy(.setupTypingPermission),
                    subtitle: copy(.setupTypingPermissionDetail),
                    systemImage: "hand.raised.fill",
                    tint: .orange
                )
            }
        }
    }

    private var unifiedAISection: some View {
        let preset = AIProviderPreset.preset(for: aiProvider.presetID) ?? AIProviderPreset.all[0]

        return VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.ai.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.aiSubtitle),
                systemImage: SettingsPane.ai.systemImage,
                tint: .accentColor
            )

            SettingsGlassStatusRow(
                title: aiProviderSummary,
                subtitle: aiProviderModelSummary,
                systemImage: aiProviderReadiness.systemImage,
                tint: readinessTint(aiProviderReadiness.severity)
            )

            SettingsGlassDetectedProvidersSection(
                detections: aiProviderDetections,
                currentPresetID: aiProvider.presetID,
                languageCode: resolvedLanguageCode,
                apply: applyAIProviderDetection,
                refresh: refreshAIProviderDetections
            )

            SettingsGlassStatusRow(
                title: aiProviderReadiness.title,
                subtitle: aiProviderReadiness.detail,
                systemImage: aiProviderReadiness.systemImage,
                tint: readinessTint(aiProviderReadiness.severity)
            )

            if preset.fields.contains(.baseURL) {
                SettingsGlassTextFieldRow(
                    title: "Base URL",
                    systemImage: "link",
                    text: Binding(
                        get: { aiProvider.baseURL },
                        set: { updateAIProviderBaseURL($0) }
                    )
                )
            }

            if preset.fields.contains(.model) {
                SettingsGlassTextFieldRow(
                    title: copy(.model),
                    systemImage: "cpu",
                    text: Binding(
                        get: { aiProvider.model },
                        set: { updateAIProviderModel($0) }
                    ),
                    prompt: preset.defaultModel.isEmpty ? copy(.autoSelect) : preset.defaultModel
                )
            }

            if preset.fields.contains(.apiKey) {
                SettingsGlassAPIKeyRow(
                    hasKey: aiProviderHasAPIKey,
                    languageCode: resolvedLanguageCode,
                    saveAPIKey: saveAIProviderAPIKey,
                    clearAPIKey: clearAIProviderAPIKey
                )
            }

            if preset.requiresAPIKey {
                SettingsGlassStatusRow(
                    title: copy(.environmentVariables),
                    subtitle: environmentKeyLabel(for: preset),
                    systemImage: "terminal",
                    tint: .secondary
                )
            }

            SettingsGlassToggleRow(
                title: copy(.agentDetection),
                subtitle: copy(.agentDetectionDetail),
                systemImage: "dot.radiowaves.left.and.right",
                isOn: Binding(
                    get: { agentProcessDetectionEnabled },
                    set: { setAgentProcessDetection($0) }
                )
            )

            SettingsGlassToggleRow(
                title: copy(.webSearch),
                subtitle: webSearchEnabled ? copy(.webSearchOn) : copy(.webSearchOff),
                systemImage: "magnifyingglass.circle",
                isOn: Binding(
                    get: { webSearchEnabled },
                    set: { setWebSearch($0) }
                )
            )
        }
    }

    private var unifiedAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.skins.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.skinsSubtitle),
                systemImage: SettingsPane.skins.systemImage,
                tint: .purple
            )

            SettingsGlassTextFieldRow(
                title: copy(.catName),
                systemImage: "pawprint",
                text: Binding(
                    get: { editableCatName },
                    set: { updateCatName($0) }
                ),
                prompt: copy(.catNamePrompt)
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                ForEach(skinIDs, id: \.self) { id in
                    Button {
                        selectSkin(id)
                    } label: {
                        SettingsGlassSkinTile(
                            title: skinLabel(id),
                            systemImage: id == SkinManager.defaultID ? "sparkles" : "paintpalette",
                            frameURLs: skinPreviewFrameURLs[id] ?? [],
                            isSelected: id == selectedSkinID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsGlassDisclosureSection(
                title: copy(.customSkin),
                subtitle: copy(.customSkinDetail),
                systemImage: "camera.aperture",
                tint: .accentColor
            ) {
                SettingsGlassStatusRow(
                    title: copy(.skinFolder),
                    subtitle: "~/Library/Application Support/openNeko/skins/<id>",
                    systemImage: "folder",
                    tint: .accentColor
                )

                ViewThatFits(in: .horizontal) {
                    customSkinButtons(axis: .horizontal)
                    customSkinButtons(axis: .vertical)
                }
                .controlSize(.regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            SettingsGlassToggleRow(
                title: copy(.neighborDiscovery),
                subtitle: neighborSettings.enabled ? copy(.neighborDiscoveryOn) : copy(.neighborDiscoveryOff),
                systemImage: neighborSettings.enabled ? "dot.radiowaves.left.and.right" : "wifi.slash",
                isOn: Binding(
                    get: { neighborSettings.enabled },
                    set: { setNeighborEnabled($0) }
                )
            )
        }
    }

    private var unifiedProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.profile.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.profileSubtitle),
                systemImage: SettingsPane.profile.systemImage,
                tint: .teal
            )

            SettingsGlassStatusRow(
                title: copy(.promptContext),
                subtitle: copy(.promptContextDetail),
                systemImage: "text.bubble",
                tint: .accentColor
            )

            profileInputRows
        }
    }

    private var unifiedSkillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.skills.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.skillsSubtitle),
                systemImage: SettingsPane.skills.systemImage,
                tint: .purple
            )

            SettingsGlassStatusRow(
                title: copy(.skillsFolder),
                subtitle: "~/.openneko/skills/<id>/SKILL.md",
                systemImage: "folder",
                tint: .accentColor
            )

            Button(action: openSkillsFolder) {
                Label(copy(.openSkillsFolder), systemImage: "folder")
            }
            .buttonStyle(.bordered)

            if skills.isEmpty {
                SettingsGlassStatusRow(
                    title: copy(.noSkills),
                    subtitle: copy(.noSkillsDetail),
                    systemImage: "tray",
                    tint: .secondary
                )
            } else {
                ForEach(skills) { skill in
                    SettingsGlassSkillRow(
                        skill: skill,
                        isEnabled: !disabledSkillIDs.contains(skill.id),
                        languageCode: resolvedLanguageCode,
                        run: { runSkill(skill.id) },
                        setEnabled: { enabled in setSkillEnabled(skill.id, enabled) }
                    )
                }
            }
        }
    }

    private var unifiedGeneralSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.general.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.generalSubtitle),
                systemImage: SettingsPane.general.systemImage,
                tint: .blue
            )

            HStack(spacing: 10) {
                Button(action: showOnboarding) {
                    Label(SettingsCopy.text(.onboardingRestart, languageCode: resolvedLanguageCode), systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(.bordered)

                Button(action: retryKeyboardMonitor) {
                    Label(
                        permissionMenu.retryTitle(languageCode: resolvedLanguageCode),
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.regular)

            SettingsGlassCheckboxRow(
                title: launchAtLogin.title(languageCode: resolvedLanguageCode),
                subtitle: launchAtLogin.detail(languageCode: resolvedLanguageCode),
                systemImage: "power.circle",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { setLaunchAtLogin($0) }
                )
            )

            SettingsGlassCheckboxRow(
                title: copy(.soundEffects),
                subtitle: soundEffectsEnabled ? copy(.soundEffectsOn) : copy(.soundEffectsOff),
                systemImage: soundEffectsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isOn: Binding(
                    get: { soundEffectsEnabled },
                    set: { setSoundEffects($0) }
                )
            )

            SettingsGlassRow(systemImage: "globe") {
                Text(copy(.language))
                    .font(.body.weight(.medium))
            } trailing: {
                Picker(copy(.language), selection: Binding(
                    get: { languageCode ?? "system" },
                    set: { setLanguageCode($0 == "system" ? nil : $0) }
                )) {
                    Text(SettingsCopy.systemDefaultLanguage(
                        resolvedName: AppLanguage.displayName(for: resolvedLanguageCode),
                        languageCode: resolvedLanguageCode
                    )).tag("system")
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("简体中文").tag("zh")
                }
                .labelsHidden()
                .frame(width: 220, alignment: .trailing)
            }

            SettingsGlassToggleRow(
                title: copy(.agentDetection),
                subtitle: copy(.agentDetectionDetail),
                systemImage: "dot.radiowaves.left.and.right",
                isOn: Binding(
                    get: { agentProcessDetectionEnabled },
                    set: { setAgentProcessDetection($0) }
                )
            )
        }
    }

    private var unifiedFooterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.about.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.aboutSubtitle),
                systemImage: SettingsPane.about.systemImage,
                tint: .secondary
            )

            SettingsGlassStatusRow(
                title: copy(.version),
                subtitle: version,
                systemImage: "info.circle",
                tint: .secondary
            )

            SettingsGlassStatusRow(
                title: "State Bridge",
                subtitle: StateBridgeExample.endpoint(port: stateBridgePort),
                systemImage: "point.3.connected.trianglepath.dotted",
                tint: .blue
            )
        }
    }

    @ViewBuilder
    private var selectedPaneContent: some View {
        switch selectedPane {
        case .start:
            startPane
        case .ai:
            aiPane
        case .skins:
            skinsPane
        case .skills:
            skillsPane
        case .profile:
            profilePane
        case .general:
            generalPane
        case .neighbors:
            neighborsPane
        case .permissions, .bridge:
            generalPane
        case .about:
            aboutPane
        }
    }

    private var compactNeighborsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.neighbors.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.neighborsSubtitle),
                systemImage: SettingsPane.neighbors.systemImage,
                tint: .green
            )

            SettingsGlassStatusRow(
                title: copy(.discoveredNeighbors),
                subtitle: neighborStatusText,
                systemImage: neighborPeerCount > 0 ? "person.2.fill" : "person.2",
                tint: neighborPeerCount > 0 ? .green : .secondary
            )

            SettingsGlassStatusRow(
                title: copy(.peerID),
                subtitle: peerID.isEmpty ? copy(.peerIDPending) : peerID,
                systemImage: "number",
                tint: .secondary
            )

            Button(action: sendNeighborWave) {
                Label(copy(.sendWave), systemImage: "hand.wave")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!neighborSettings.enabled || neighborPeerCount == 0)
        }
    }

    private var compactPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.permissions.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.permissionsSubtitle),
                systemImage: SettingsPane.permissions.systemImage,
                tint: permissionMenu.needsUserAction ? .orange : .green
            )

            permissionDetailSection
        }
    }

    private var compactBridgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSectionHeader(
                title: SettingsPane.bridge.title(languageCode: resolvedLanguageCode),
                subtitle: copy(.bridgeSubtitle),
                systemImage: SettingsPane.bridge.systemImage,
                tint: .blue
            )

            SettingsGlassStatusRow(
                title: "State Bridge",
                subtitle: StateBridgeExample.endpoint(port: stateBridgePort),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

            SettingsGlassStatusRow(
                title: copy(.state),
                subtitle: StateBridgeExample.commonStateLabels,
                systemImage: "slider.horizontal.3",
                tint: .accentColor
            )

            SettingsGlassCommandRow(
                title: copy(.exampleCommand),
                command: StateBridgeExample.curlCommand(port: stateBridgePort),
                didCopy: didCopyBridgeCommand,
                languageCode: resolvedLanguageCode,
                copy: copyStateBridgeCommand
            )
        }
    }

    private var onboardingWizard: some View {
        OpenNekoGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                SettingsOnboardingHeader(
                    currentIndex: onboardingStepIndex,
                    totalCount: OnboardingStep.allCases.count,
                    tint: onboardingStep.tint
                )

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: onboardingStep.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(onboardingStep.tint)
                            .frame(width: 28, height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(onboardingStep.tint.opacity(0.12))
                            }

                        Text(onboardingStep.title(languageCode: resolvedLanguageCode))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    onboardingStepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .openNekoGlass(cornerRadius: 16)

                onboardingControls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var onboardingStepContent: some View {
        switch onboardingStep {
        case .welcome:
            SettingsOnboardingFeatureGrid(
                languageCode: resolvedLanguageCode
            )
        case .skin:
            SettingsOnboardingSkinPicker(
                skinIDs: skinIDs,
                selectedSkinID: selectedSkinID,
                label: skinLabel,
                frameURLs: { skinPreviewFrameURLs[$0] ?? [] },
                select: selectSkin
            )
        case .name:
            SettingsOnboardingNameStep(
                frameURLs: skinPreviewFrameURLs[selectedSkinID] ?? [],
                tint: onboardingStep.tint,
                nameField: SettingsOnboardingNameField(
                    title: copy(.catName),
                    systemImage: "pawprint",
                    text: Binding(
                        get: { editableCatName },
                        set: { updateCatName($0) }
                    ),
                    prompt: copy(.catNamePrompt)
                )
            )
        case .permissions:
                SettingsOnboardingPermissionStep(
                    frameURLs: selectedTypingFrameURLs,
                    permissionMenu: permissionMenu,
                    languageCode: resolvedLanguageCode,
                    openAccessibility: openAccessibility,
                    openInputMonitoring: openInputMonitoring
                )
        case .ai:
            SettingsOnboardingAISection(
                readiness: aiProviderReadiness,
                detections: aiProviderDetections,
                currentPresetID: aiProvider.presetID,
                languageCode: resolvedLanguageCode,
                apply: applyAIProviderDetection,
                refresh: refreshAIProviderDetections,
                selectPreset: selectAIProviderPreset,
                autoApplyDetected: true
            )
        case .done:
            SettingsOnboardingDoneStep(
                frameURLs: selectedSuccessFrameURLs,
                launchAtLogin: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { setLaunchAtLogin($0) }
                ),
                title: launchAtLogin.title(languageCode: resolvedLanguageCode),
                subtitle: launchAtLogin.detail(languageCode: resolvedLanguageCode)
            )
            .onAppear {
                if !launchAtLogin.isEnabled {
                    setLaunchAtLogin(true)
                }
            }
        }
    }

    private var onboardingControls: some View {
        HStack(spacing: 10) {
            if onboardingStep != .welcome {
                Button {
                    moveOnboarding(by: -1)
                } label: {
                    Label(SettingsCopy.text(.onboardingBack, languageCode: resolvedLanguageCode), systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            if onboardingStep == .permissions || onboardingStep == .ai {
                Button {
                    moveOnboarding(by: 1)
                } label: {
                    Label(SettingsCopy.text(.onboardingSkip, languageCode: resolvedLanguageCode), systemImage: "forward")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                advanceOnboarding()
            } label: {
                HStack(spacing: 6) {
                    Text(onboardingPrimaryTitle)
                    Image(systemName: onboardingPrimaryImage)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.regular)
    }

    private var startPane: some View {
        SettingsGlassPane(
            title: SettingsPane.start.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.startSubtitle)
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                SettingsGlassSetupTile(
                    title: copy(.skin),
                    subtitle: skinLabel(selectedSkinID),
                    systemImage: "paintpalette.fill",
                    tint: .accentColor
                ) {
                    selectPane(.skins)
                }

                SettingsGlassSetupTile(
                    title: copy(.profile),
                    subtitle: profileSummary,
                    systemImage: profileNeedsSetup ? "exclamationmark.triangle.fill" : "person.crop.circle.fill",
                    tint: profileNeedsSetup ? .orange : .teal
                ) {
                    selectPane(.profile)
                }

                if permissionMenu.needsUserAction {
                    SettingsGlassSetupTile(
                        title: copy(.typing),
                        subtitle: permissionMenu.statusTitle(languageCode: resolvedLanguageCode),
                        systemImage: "hand.raised.fill",
                        tint: .orange
                    ) {
                        selectPane(.general)
                    }
                }

                SettingsGlassSetupTile(
                    title: "AI",
                    subtitle: aiProviderConnectionSummary,
                    systemImage: aiProviderReadiness.systemImage,
                    tint: readinessTint(aiProviderReadiness.severity)
                ) {
                    selectPane(.ai)
                }

                SettingsGlassSetupTile(
                    title: copy(.skills),
                    subtitle: enabledSkillsCountText,
                    systemImage: "wand.and.stars",
                    tint: .purple
                ) {
                    selectPane(.skills)
                }
            }

            Button(action: showOnboarding) {
                Label(SettingsCopy.text(.onboardingRestart, languageCode: resolvedLanguageCode), systemImage: "list.bullet.clipboard")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var generalPane: some View {
        SettingsGlassPane(
            title: SettingsPane.general.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.generalSubtitle)
        ) {
            SettingsGlassRow(systemImage: "globe") {
                Text(copy(.language))
                    .font(.body.weight(.medium))
            } trailing: {
                Picker(copy(.language), selection: Binding(
                    get: { languageCode ?? "system" },
                    set: { setLanguageCode($0 == "system" ? nil : $0) }
                )) {
                    Text(SettingsCopy.systemDefaultLanguage(
                        resolvedName: AppLanguage.displayName(for: resolvedLanguageCode),
                        languageCode: resolvedLanguageCode
                    )).tag("system")
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("简体中文").tag("zh")
                }
                .labelsHidden()
                .frame(width: 220, alignment: .trailing)
            }

            SettingsGlassCheckboxRow(
                title: launchAtLogin.title(languageCode: resolvedLanguageCode),
                subtitle: launchAtLogin.detail(languageCode: resolvedLanguageCode),
                systemImage: "power.circle",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { setLaunchAtLogin($0) }
                )
            )

            SettingsGlassCheckboxRow(
                title: copy(.soundEffects),
                subtitle: soundEffectsEnabled ? copy(.soundEffectsOn) : copy(.soundEffectsOff),
                systemImage: soundEffectsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isOn: Binding(
                    get: { soundEffectsEnabled },
                    set: { setSoundEffects($0) }
                )
            )

            if permissionMenu.needsUserAction {
                compactPermissionsSection
            }
        }
    }

    private var neighborsPane: some View {
        SettingsGlassPane(
            title: SettingsPane.neighbors.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.neighborsSubtitle)
        ) {
            SettingsGlassToggleRow(
                title: copy(.neighborDiscovery),
                subtitle: neighborSettings.enabled ? copy(.neighborDiscoveryOn) : copy(.neighborDiscoveryOff),
                systemImage: neighborSettings.enabled ? "dot.radiowaves.left.and.right" : "wifi.slash",
                isOn: Binding(
                    get: { neighborSettings.enabled },
                    set: { setNeighborEnabled($0) }
                )
            )

            SettingsGlassStatusRow(
                title: copy(.discoveredNeighbors),
                subtitle: neighborStatusText,
                systemImage: neighborPeerCount > 0 ? "person.2.fill" : "person.2",
                tint: neighborPeerCount > 0 ? .green : .secondary
            )

            Button(action: sendNeighborWave) {
                Label(copy(.sendWave), systemImage: "hand.wave")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!neighborSettings.enabled || neighborPeerCount == 0)

            SettingsGlassDisclosureSection(
                title: copy(.advancedNeighborInfo),
                subtitle: copy(.advancedNeighborInfoDetail),
                systemImage: "number.circle",
                tint: .secondary
            ) {
                SettingsGlassStatusRow(
                    title: copy(.peerID),
                    subtitle: peerID.isEmpty ? copy(.peerIDPending) : peerID,
                    systemImage: "number",
                    tint: .secondary
                )
            }
        }
    }

    private var profilePane: some View {
        SettingsGlassPane(
            title: SettingsPane.profile.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.profileSubtitle)
        ) {
            SettingsGlassStatusRow(
                title: copy(.promptContext),
                subtitle: copy(.promptContextDetail),
                systemImage: "text.bubble",
                tint: .accentColor
            )

            profileInputRows
        }
    }

    private var aiPane: some View {
        let preset = AIProviderPreset.preset(for: aiProvider.presetID) ?? AIProviderPreset.all[0]
        return SettingsGlassPane(
            title: SettingsPane.ai.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.aiSubtitle)
        ) {
            SettingsOnboardingAISection(
                readiness: aiProviderReadiness,
                detections: aiProviderDetections,
                currentPresetID: aiProvider.presetID,
                languageCode: resolvedLanguageCode,
                apply: applyAIProviderDetection,
                refresh: refreshAIProviderDetections,
                selectPreset: selectAIProviderPreset,
                autoApplyDetected: false
            )

            if preset.fields.contains(.apiKey) {
                SettingsGlassAPIKeyRow(
                    hasKey: aiProviderHasAPIKey,
                    languageCode: resolvedLanguageCode,
                    saveAPIKey: saveAIProviderAPIKey,
                    clearAPIKey: clearAIProviderAPIKey
                )
            }

            if preset.fields.contains(.baseURL) {
                SettingsGlassCompactTextFieldRow(
                    title: "Base URL",
                    systemImage: "link",
                    text: Binding(
                        get: { aiProvider.baseURL },
                        set: { updateAIProviderBaseURL($0) }
                    ),
                    prompt: preset.defaultBaseURL,
                    width: 280
                )
            }

            if preset.fields.contains(.model) {
                SettingsGlassCompactTextFieldRow(
                    title: copy(.model),
                    systemImage: "cpu",
                    text: Binding(
                        get: { aiProvider.model },
                        set: { updateAIProviderModel($0) }
                    ),
                    prompt: preset.defaultModel.isEmpty ? copy(.autoSelect) : preset.defaultModel,
                    width: 220,
                    monospaced: true
                )
            }

            SettingsGlassToggleRow(
                title: copy(.agentDetection),
                subtitle: copy(.agentDetectionDetail),
                systemImage: "dot.radiowaves.left.and.right",
                isOn: Binding(
                    get: { agentProcessDetectionEnabled },
                    set: { setAgentProcessDetection($0) }
                )
            )

            SettingsGlassToggleRow(
                title: copy(.webSearch),
                subtitle: webSearchEnabled ? copy(.webSearchOn) : copy(.webSearchOff),
                systemImage: "magnifyingglass.circle",
                isOn: Binding(
                    get: { webSearchEnabled },
                    set: { setWebSearch($0) }
                )
            )
        }
    }

    private var skillsPane: some View {
        SettingsGlassPane(
            title: SettingsPane.skills.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.skillsSubtitle)
        ) {
            if skills.isEmpty {
                SettingsGlassStatusRow(
                    title: copy(.noSkills),
                    subtitle: copy(.noSkillsDetail),
                    systemImage: "tray",
                    tint: .secondary
                )
            } else {
                ForEach(skills) { skill in
                    SettingsGlassSkillRow(
                        skill: skill,
                        isEnabled: !disabledSkillIDs.contains(skill.id),
                        languageCode: resolvedLanguageCode,
                        run: { runSkill(skill.id) },
                        setEnabled: { enabled in setSkillEnabled(skill.id, enabled) }
                    )
                }
            }

            HStack(spacing: 10) {
                Button(action: openSkillsFolder) {
                    Label(copy(.openSkillsFolder), systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var permissionDetailSection: some View {
            SettingsGlassPermissionRow(
                title: permissionMenu.accessibilityTitle(languageCode: resolvedLanguageCode),
                subtitle: "",
                systemImage: "accessibility",
                tint: permissionMenu.accessibilityGranted ? .green : .orange,
                buttonTitle: permissionMenu.openAccessibilityTitle(languageCode: resolvedLanguageCode),
                buttonImage: "gearshape",
                action: openAccessibility
            )

            SettingsGlassPermissionRow(
                title: permissionMenu.inputMonitoringTitle(languageCode: resolvedLanguageCode),
                subtitle: "",
                systemImage: permissionMenu.inputMonitoringGranted ? "checkmark.circle.fill" : "keyboard.badge.eye.fill",
                tint: permissionMenu.inputMonitoringGranted ? .green : .orange,
                buttonTitle: permissionMenu.openSettingsTitle(languageCode: resolvedLanguageCode),
                buttonImage: "keyboard",
                action: openInputMonitoring
            )
    }

    private var skinsPane: some View {
        SettingsGlassPane(
            title: SettingsPane.skins.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.skinsSubtitle)
        ) {
            SettingsGlassTextFieldRow(
                title: copy(.catName),
                systemImage: "pawprint",
                text: Binding(
                    get: { editableCatName },
                    set: { updateCatName($0) }
                ),
                prompt: copy(.catNamePrompt)
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                ForEach(skinIDs, id: \.self) { id in
                    Button {
                        selectSkin(id)
                    } label: {
                        SettingsGlassSkinTile(
                            title: skinLabel(id),
                            systemImage: id == SkinManager.defaultID ? "sparkles" : "paintpalette",
                            frameURLs: skinPreviewFrameURLs[id] ?? [],
                            isSelected: id == selectedSkinID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        }
    }

    @ViewBuilder
    private func customSkinButtons(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))

        layout {
            Button(action: createCustomSkinRequest) {
                Label(copy(.makeSkinRequest), systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)

            Button(action: importCustomSkinPackage) {
                Label(copy(.importSkinPackage), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)

            Button(action: openSkinsFolder) {
                Label(copy(.openFolder), systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
    }

    private var aboutPane: some View {
        SettingsGlassPane(
            title: SettingsPane.about.title(languageCode: resolvedLanguageCode),
            subtitle: copy(.aboutSubtitle)
        ) {
            HStack(alignment: .center, spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenNeko")
                        .font(.title.weight(.semibold))
                    Text("\(copy(.version)) \(version)")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button(action: checkForUpdates) {
                            Label(updateStatus.menuTitle(languageCode: resolvedLanguageCode), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!updateStatus.menuIsEnabled)

                        Link(destination: openNekoGitHubURL) {
                            Label("GitHub", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)

                    if !updateStatus.bubbleText(languageCode: resolvedLanguageCode).isEmpty {
                        Text(updateStatus.bubbleText(languageCode: resolvedLanguageCode))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }

            HStack(spacing: 4) {
                Text("OpenNeko is released under the")
                    .foregroundStyle(.secondary)
                Link("MIT License", destination: openNekoLicenseURL)
                Text(".")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            HStack(spacing: 4) {
                Text("made by")
                    .foregroundStyle(.secondary)
                Link("kimtoma", destination: kimtomaURL)
                Text("with ❤️")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func skinLabel(_ id: String) -> String {
        if id == "pink" { return copy(.creamSkin) }
        return id == SkinManager.defaultID ? copy(.defaultSkin) : id
    }

    private var aiProviderSummary: String {
        (AIProviderPreset.preset(for: aiProvider.presetID) ?? AIProviderPreset.all[0])
            .title(languageCode: resolvedLanguageCode)
    }

    private var aiProviderModelSummary: String {
        let preset = AIProviderPreset.preset(for: aiProvider.presetID) ?? AIProviderPreset.all[0]
        let detectedModel = aiProviderDetections
            .first { $0.presetID == aiProvider.presetID }?
            .model ?? ""
        let model = [aiProvider.model, detectedModel, preset.defaultModel]
            .first { !$0.isEmpty } ?? ""
        let value = model.isEmpty ? copy(.autoSelect) : model
        return "\(copy(.model)): \(value)"
    }

    private var aiProviderConnectionSummary: String {
        "\(aiProviderSummary) · \(aiProviderModelSummary)"
    }

    private var catSummary: String {
        if editableCatName.isEmpty {
            return skinLabel(selectedSkinID)
        }
        return "\(editableCatName) · \(skinLabel(selectedSkinID))"
    }

    private var languageSummary: String {
        if languageCode == nil {
            return SettingsCopy.systemDefaultLanguage(
                resolvedName: AppLanguage.displayName(for: resolvedLanguageCode),
                languageCode: resolvedLanguageCode
            )
        }
        return AppLanguage.displayName(for: resolvedLanguageCode)
    }

    private var enabledSkillsCountText: String {
        let enabled = skills.filter { !disabledSkillIDs.contains($0.id) }.count
        return SettingsCopy.enabledSkillsCount(
            enabled: enabled,
            total: skills.count,
            languageCode: resolvedLanguageCode
        )
    }

    private var profileSummary: String {
        if !editableUserProfile.name.isEmpty {
            return editableUserProfile.name
        }
        if !editableUserProfile.birthDate.isEmpty {
            return editableUserProfile.birthDate
        }
        return copy(.noProfile)
    }

    private var profileNeedsSetup: Bool {
        editableUserProfile.isEmpty
    }

    @ViewBuilder
    private var profileInputRows: some View {
        SettingsGlassCompactTextFieldRow(
            title: copy(.name),
            systemImage: "person",
            text: Binding(
                get: { editableUserProfile.name },
                set: { updateUserProfile(name: $0) }
            ),
            prompt: copy(.name),
            width: profileControlWidth
        )

        SettingsGlassDatePickerRow(
            title: copy(.birthDate),
            systemImage: "calendar",
            selection: profileBirthDateSelection,
            components: .date,
            width: profileControlWidth
        )

        SettingsGlassDatePickerRow(
            title: copy(.birthTime),
            systemImage: "clock",
            selection: profileBirthTimeSelection,
            components: .hourAndMinute,
            width: profileControlWidth
        )

        SettingsGlassRadioRow(
            title: copy(.calendar),
            systemImage: "moonphase.waxing.crescent",
            options: [
                SettingsRadioOption(id: "solar", title: copy(.solar)),
                SettingsRadioOption(id: "lunar", title: copy(.lunar)),
                SettingsRadioOption(id: "unknown", title: copy(.unknown))
            ],
            selection: Binding(
                get: { editableUserProfile.calendar },
                set: { updateUserProfile(calendar: $0) }
            ),
            width: profileControlWidth
        )
    }

    private var profileBirthDateSelection: Binding<Date> {
        Binding(
            get: { parseProfileDate(editableUserProfile.birthDate) ?? Date() },
            set: { updateUserProfile(birthDate: formatProfileDate($0)) }
        )
    }

    private var profileBirthTimeSelection: Binding<Date> {
        Binding(
            get: { parseProfileTime(editableUserProfile.birthTime) ?? defaultProfileTimeDate },
            set: { updateUserProfile(birthTime: formatProfileTime($0)) }
        )
    }

    private var defaultProfileTimeDate: Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12, minute: 0)) ?? Date()
    }

    private var editableCatName: String {
        catNameDraft ?? catName
    }

    private var editableUserProfile: UserProfile {
        profileDraft ?? userProfile
    }

    private var neighborStatusText: String {
        SettingsCopy.neighborStatus(
            enabled: neighborSettings.enabled,
            peerCount: neighborPeerCount,
            languageCode: resolvedLanguageCode
        )
    }

    private var selectedPaneBinding: Binding<SettingsPane> {
        Binding(
            get: { selectedPane },
            set: { selectPane($0) }
        )
    }

    private var selectedPane: SettingsPane {
        guard let pane = SettingsPane(rawValue: selectedPaneRaw) else {
            return .start
        }
        return visibleSettingsPanes.contains(pane) ? pane : .general
    }

    private var onboardingStep: OnboardingStep {
        OnboardingStep(rawValue: onboardingStepRaw) ?? .welcome
    }

    private var onboardingStepIndex: Int {
        (OnboardingStep.allCases.firstIndex(of: onboardingStep) ?? 0) + 1
    }

    private var selectedTypingFrameURLs: [URL] {
        selectedStateFrameURLs("typing")
    }

    private var selectedSuccessFrameURLs: [URL] {
        selectedStateFrameURLs("success")
    }

    private func selectedStateFrameURLs(_ state: String) -> [URL] {
        skinStateFrameURLs(skinID: selectedSkinID, state: state)
    }

    private func skinStateFrameURLs(skinID: String, state: String) -> [URL] {
        let fallback = skinPreviewFrameURLs[skinID] ?? []
        guard let firstFrame = fallback.first else { return [] }
        let directory = firstFrame.deletingLastPathComponent()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return fallback
        }
        let frames = urls
            .filter { $0.lastPathComponent.hasPrefix("\(state)_") && $0.pathExtension == "png" }
            .sorted { lhs, rhs in
                frameIndex(lhs, state: state) < frameIndex(rhs, state: state)
            }
        return frames.isEmpty ? fallback : frames
    }

    private func frameIndex(_ url: URL, state: String) -> Int {
        let stem = url.deletingPathExtension().lastPathComponent
        let prefix = "\(state)_"
        guard stem.hasPrefix(prefix),
              let index = Int(stem.dropFirst(prefix.count))
        else {
            return .max
        }
        return index
    }

    private var onboardingProgressText: String {
        let index = (OnboardingStep.allCases.firstIndex(of: onboardingStep) ?? 0) + 1
        return "\(index)/\(OnboardingStep.allCases.count) · \(SettingsCopy.text(.onboardingSubtitle, languageCode: resolvedLanguageCode))"
    }

    private var onboardingPrimaryTitle: String {
        switch onboardingStep {
        case .welcome:
            return SettingsCopy.text(.onboardingStart, languageCode: resolvedLanguageCode)
        case .done:
            return SettingsCopy.text(.onboardingFinish, languageCode: resolvedLanguageCode)
        default:
            return SettingsCopy.text(.onboardingNext, languageCode: resolvedLanguageCode)
        }
    }

    private var onboardingPrimaryImage: String {
        onboardingStep == .done ? "checkmark.circle" : "chevron.right"
    }

    private func selectPane(_ pane: SettingsPane) {
        selectedPaneRaw = visibleSettingsPanes.contains(pane) ? pane.rawValue : SettingsPane.general.rawValue
    }

    private func moveOnboarding(by offset: Int) {
        let steps = OnboardingStep.allCases
        let current = steps.firstIndex(of: onboardingStep) ?? 0
        let next = min(max(current + offset, 0), steps.count - 1)
        onboardingStepRaw = steps[next].rawValue
    }

    private func advanceOnboarding() {
        if onboardingStep == .done {
            onboardingStepRaw = OnboardingStep.welcome.rawValue
            completeOnboarding()
        } else {
            moveOnboarding(by: 1)
        }
    }

    private func copyStateBridgeCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(StateBridgeExample.curlCommand(port: stateBridgePort), forType: .string)
        didCopyBridgeCommand = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyBridgeCommand = false
        }
    }

    private var setupTitle: String {
        if permissionMenu.needsUserAction {
            return copy(.setupTypingPermission)
        }
        if aiProviderReadiness.severity == .needsAction {
            return copy(.setupAIConnection)
        }
        return copy(.setupReady)
    }

    private var setupSubtitle: String {
        if permissionMenu.needsUserAction {
            return copy(.setupTypingPermissionDetail)
        }
        if aiProviderReadiness.severity == .needsAction {
            return aiProviderReadiness.detail
        }
        if aiProviderReadiness.severity == .warning {
            return aiProviderReadiness.detail
        }
        return copy(.setupReadyDetail)
    }

    private var setupTint: Color {
        if permissionMenu.needsUserAction {
            return .orange
        }
        return readinessTint(aiProviderReadiness.severity)
    }

    private var primarySetupActionTitle: String {
        permissionMenu.needsUserAction ? copy(.permissionSetup) : copy(.aiSettings)
    }

    private var primarySetupActionImage: String {
        permissionMenu.needsUserAction ? "hand.raised" : "sparkles"
    }

    private func environmentKeyLabel(for preset: AIProviderPreset) -> String {
        let separator: String
        switch AppLanguage.normalized(resolvedLanguageCode) ?? "ko" {
        case "en": separator = " or "
        case "ja": separator = " または "
        case "zh": separator = " 或 "
        default: separator = " 또는 "
        }
        return [preset.environmentKey, preset.alternateEnvironmentKey]
            .compactMap { $0 }
            .joined(separator: separator)
    }

    private func copy(_ key: SettingsCopyKey) -> String {
        SettingsCopy.text(key, languageCode: resolvedLanguageCode)
    }

    private func readinessTint(_ severity: AIProviderReadinessSeverity) -> Color {
        switch severity {
        case .ready:
            .green
        case .warning:
            .orange
        case .needsAction:
            .red
        }
    }

    private func parseProfileDate(_ value: String) -> Date? {
        profileDateFormatter.date(from: value)
    }

    private func formatProfileDate(_ date: Date) -> String {
        profileDateFormatter.string(from: date)
    }

    private func parseProfileTime(_ value: String) -> Date? {
        profileTimeFormatter.date(from: value)
    }

    private func formatProfileTime(_ date: Date) -> String {
        profileTimeFormatter.string(from: date)
    }

    private var profileDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var profileTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func updateUserProfile(
        name: String? = nil,
        birthDate: String? = nil,
        birthTime: String? = nil,
        calendar: String? = nil
    ) {
        var profile = editableUserProfile
        if let name {
            profile.name = name
        }
        if let birthDate {
            profile.birthDate = birthDate
        }
        if let birthTime {
            profile.birthTime = birthTime
        }
        if let calendar {
            profile.calendar = calendar
        }
        let normalized = profile.normalized()
        profileDraft = normalized
        setUserProfile(normalized)
    }

    private func updateCatName(_ name: String) {
        catNameDraft = name
        setCatName(name)
    }
}

private struct SettingsSidebarSelector: View {
    @Binding var selection: SettingsPane
    let panes: [SettingsPane]
    let languageCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(panes) { pane in
                Button {
                    selection = pane
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                        Text(pane.title(languageCode: languageCode))
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
                    }
                    .foregroundStyle(selection == pane ? Color.primary : Color.secondary)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .background {
                        if selection == pane {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(pane.title(languageCode: languageCode))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.45), lineWidth: 1)
        }
    }
}

private enum SettingsPixelPalette {
    static let cyan = Color(red: 0.00, green: 0.66, blue: 0.78)
    static let coral = Color(red: 1.00, green: 0.42, blue: 0.34)
    static let yellow = Color(red: 1.00, green: 0.84, blue: 0.36)
    static let green = Color(red: 0.26, green: 0.72, blue: 0.50)
    static let softCyan = Color(red: 0.93, green: 0.98, blue: 1.00)
    static let softCoral = Color(red: 1.00, green: 0.95, blue: 0.94)
    static let softYellow = Color(red: 1.00, green: 0.98, blue: 0.84)
}

private enum SettingsProviderVisual {
    static func assetName(for presetID: String) -> String? {
        switch presetID {
        case "chatgpt-oauth":
            return "ProviderChatGPT"
        case "claude-oauth", "claude":
            return "ProviderClaude"
        case "gemini-oauth", "gemini":
            return "ProviderGemini"
        case "ollama":
            return "ProviderOllama"
        case "local-openai":
            return "ProviderLMStudio"
        default:
            return nil
        }
    }

    static func fallbackSystemImage(for presetID: String) -> String {
        switch presetID {
        case "custom":
            return "slider.horizontal.3"
        default:
            return "sparkles"
        }
    }

    static func accent(for presetID: String) -> Color {
        switch presetID {
        case "chatgpt-oauth":
            return Color(red: 0.08, green: 0.58, blue: 0.48)
        case "claude-oauth", "claude":
            return Color(red: 0.79, green: 0.42, blue: 0.25)
        case "gemini-oauth", "gemini":
            return Color(red: 0.20, green: 0.44, blue: 0.90)
        case "ollama":
            return Color.primary
        case "local-openai":
            return Color(red: 0.42, green: 0.48, blue: 0.58)
        default:
            return .accentColor
        }
    }

    static func modeLabel(for preset: AIProviderPreset, languageCode: String) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        if preset.isLocal {
            return localized(language, ko: "로컬", en: "Local", ja: "ローカル", zh: "本地")
        }
        if preset.requiresAPIKey {
            return "API Key"
        }
        return localized(language, ko: "로그인", en: "Login", ja: "ログイン", zh: "登录")
    }

    private static func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en":
            return en
        case "ja":
            return ja
        case "zh":
            return zh
        default:
            return ko
        }
    }
}

private struct SettingsProviderIcon: View {
    let presetID: String
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let assetName = SettingsProviderVisual.assetName(for: presetID) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(SettingsProviderVisual.accent(for: presetID).opacity(0.14))
                    Image(systemName: SettingsProviderVisual.fallbackSystemImage(for: presetID))
                        .font(.system(size: size * 0.43, weight: .semibold))
                        .foregroundStyle(SettingsProviderVisual.accent(for: presetID))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

private struct SettingsAIProviderPicker: View {
    let selectedPresetID: String
    let languageCode: String
    let select: (String) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 154), spacing: 10)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(AIProviderPreset.all) { preset in
                SettingsAIProviderCard(
                    preset: preset,
                    isSelected: preset.id == selectedPresetID,
                    languageCode: languageCode,
                    select: { select(preset.id) }
                )
            }
        }
    }
}

private struct SettingsAIProviderCard: View {
    let preset: AIProviderPreset
    let isSelected: Bool
    let languageCode: String
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    SettingsProviderIcon(presetID: preset.id, size: 36)

                    Spacer(minLength: 6)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.green)
                    } else if preset.isRecommended {
                        Text(SettingsCopy.text(.recommended, languageCode: languageCode))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .modifier(SettingsNativeBadge())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title(languageCode: languageCode))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(preset.note(languageCode: languageCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Text(SettingsProviderVisual.modeLabel(for: preset, languageCode: languageCode))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SettingsProviderVisual.accent(for: preset.id))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(SettingsProviderVisual.accent(for: preset.id).opacity(0.10))
                        }

                    if preset.fields.contains(.model) {
                        Image(systemName: "cpu")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
        .help(preset.title(languageCode: languageCode))
    }

    private var cardFill: Color {
        if isSelected {
            return SettingsProviderVisual.accent(for: preset.id).opacity(0.10)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return SettingsProviderVisual.accent(for: preset.id).opacity(0.72)
        }
        return Color(nsColor: .separatorColor).opacity(0.42)
    }
}

private struct SettingsPixelOnboardingHero: View {
    let title: String
    let step: OnboardingStep
    let systemImage: String
    let tint: Color
    let frameURLs: [URL]

    var body: some View {
        HStack(spacing: 18) {
            visual
                .frame(width: 152, height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(tint.opacity(0.13))
                    }

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch step {
        case .permissions:
            SettingsOnboardingTypingPreview(frameURLs: frameURLs, tint: tint)
        case .done:
            SettingsOnboardingCatSpotlight(frameURLs: frameURLs, tint: tint)
        default:
            SettingsPixelDesktopScene(frameURLs: frameURLs, tint: tint)
        }
    }
}

private enum SettingsOnboardingBrandFont {
    private static let fontName = "Geist Pixel Square"

    private static let registerFont: Void = {
        let url = Bundle.main.url(forResource: "GeistPixel-Square", withExtension: "ttf")
            ?? Bundle.main.url(
                forResource: "GeistPixel-Square",
                withExtension: "ttf",
                subdirectory: "fonts"
            )
        guard let url else {
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func font(size: CGFloat) -> Font {
        _ = registerFont
        if NSFont(name: fontName, size: size) != nil {
            return .custom(fontName, size: size).weight(.black)
        }
        return .system(size: size, weight: .black, design: .monospaced)
    }
}

private struct SettingsOnboardingHeader: View {
    let currentIndex: Int
    let totalCount: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("OpenNeko")
                .font(SettingsOnboardingBrandFont.font(size: 36))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            SettingsOnboardingProgressPaws(
                currentIndex: currentIndex,
                totalCount: totalCount,
                tint: tint
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

private struct SettingsOnboardingProgressPaws: View {
    let currentIndex: Int
    let totalCount: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(1...totalCount, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: index == currentIndex ? 15 : 12, weight: .bold))
                    .foregroundStyle(index <= currentIndex ? tint : Color.secondary.opacity(0.28))
                    .frame(width: 18, height: 18)
                    .scaleEffect(index == currentIndex ? 1.08 : 1)
                    .animation(.snappy(duration: 0.22), value: currentIndex)
            }
        }
        .accessibilityLabel("\(currentIndex) of \(totalCount)")
    }
}

private struct SettingsPixelDesktopScene: View {
    let frameURLs: [URL]
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            SettingsOnboardingSceneBackdrop(tint: tint)

            SettingsPixelMiniCat(frameURLs: frameURLs, size: 54)
                .offset(x: -8, y: -13)

            Text("냥")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.82))
                }
                .offset(x: 37, y: -58)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct SettingsOnboardingTypingPreview: View {
    let frameURLs: [URL]
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))

            SettingsPixelMiniCat(frameURLs: frameURLs, size: 158)
        }
        .padding(.vertical, 6)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct SettingsOnboardingCatPortrait: View {
    let frameURLs: [URL]
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))

            SettingsPixelMiniCat(frameURLs: frameURLs, size: size)
                .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.32), lineWidth: 1)
        }
    }
}

private struct SettingsOnboardingSceneBackdrop: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SettingsPixelPalette.softCyan)

            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(SettingsPixelPalette.coral).frame(width: 6, height: 6)
                    Circle().fill(SettingsPixelPalette.yellow).frame(width: 6, height: 6)
                    Circle().fill(SettingsPixelPalette.green).frame(width: 6, height: 6)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Spacer()
            }

            HStack(spacing: 6) {
                PixelBlock(color: tint.opacity(0.22), width: 28, height: 18)
                PixelBlock(color: SettingsPixelPalette.coral.opacity(0.22), width: 18, height: 28)
                PixelBlock(color: SettingsPixelPalette.yellow.opacity(0.34), width: 34, height: 13)
            }
            .offset(y: -47)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.16))
                .frame(height: 5)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }
}

private struct PixelBlock: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .overlay {
                Rectangle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
    }
}

private enum SettingsOnboardingFeatureKind: CaseIterable, Hashable {
    case desktop
    case chat
    case skills

    var tint: Color {
        switch self {
        case .desktop:
            return SettingsPixelPalette.cyan
        case .chat:
            return SettingsPixelPalette.coral
        case .skills:
            return SettingsPixelPalette.green
        }
    }

    var softFill: Color {
        switch self {
        case .desktop:
            return SettingsPixelPalette.softCyan
        case .chat:
            return SettingsPixelPalette.softCoral
        case .skills:
            return SettingsPixelPalette.softYellow
        }
    }

    func title(languageCode: String) -> String {
        switch self {
        case .desktop:
            return SettingsCopy.text(.onboardingFeatureDesktopTitle, languageCode: languageCode)
        case .chat:
            return SettingsCopy.text(.onboardingFeatureChatTitle, languageCode: languageCode)
        case .skills:
            return SettingsCopy.text(.onboardingFeatureSkillsTitle, languageCode: languageCode)
        }
    }

    func body(languageCode: String) -> String {
        switch self {
        case .desktop:
            return SettingsCopy.text(.onboardingFeatureDesktopBody, languageCode: languageCode)
        case .chat:
            return SettingsCopy.text(.onboardingFeatureChatBody, languageCode: languageCode)
        case .skills:
            return SettingsCopy.text(.onboardingFeatureSkillsBody, languageCode: languageCode)
        }
    }
}

private struct SettingsOnboardingFeatureGrid: View {
    let languageCode: String

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(SettingsOnboardingFeatureKind.allCases, id: \.self) { kind in
                SettingsPixelFeatureCard(
                    kind: kind,
                    languageCode: languageCode
                )
            }
        }
    }
}

private struct SettingsOnboardingSkinPicker: View {
    let skinIDs: [String]
    let selectedSkinID: String
    let label: (String) -> String
    let frameURLs: (String) -> [URL]
    let select: (String) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 128), spacing: 10)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(skinIDs, id: \.self) { id in
                Button {
                    select(id)
                } label: {
                    SettingsOnboardingSkinTile(
                        title: label(id),
                        systemImage: id == SkinManager.defaultID ? "sparkles" : "paintpalette",
                        frameURLs: frameURLs(id),
                        isSelected: id == selectedSkinID
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsOnboardingSkinTile: View {
    let title: String
    let systemImage: String
    let frameURLs: [URL]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsSkinWalkPreview(
                frameURLs: frameURLs,
                placeholderSystemImage: systemImage,
                catSize: 82,
                previewHeight: 108
            )

            HStack(spacing: 6) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.34))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.72) : Color(nsColor: .separatorColor).opacity(0.42),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }
}

private struct SettingsOnboardingNameStep<NameField: View>: View {
    let frameURLs: [URL]
    let tint: Color
    let nameField: NameField

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            SettingsOnboardingCatPortrait(frameURLs: frameURLs, tint: tint, size: 138)
                .frame(width: 230, height: 218)

            VStack(alignment: .leading, spacing: 12) {
                nameField

                Text("말풍선과 인사말에서 이 이름으로 부른다냥.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsOnboardingPermissionStep: View {
    let frameURLs: [URL]
    let permissionMenu: InputMonitoringPermissionMenu
    let languageCode: String
    let openAccessibility: () -> Void
    let openInputMonitoring: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            SettingsOnboardingTypingPreview(frameURLs: frameURLs, tint: .orange)
                .frame(width: 230, height: 218)

            VStack(alignment: .leading, spacing: 0) {
                SettingsOnboardingPermissionStatusRow(
                    title: permissionMenu.accessibilityTitle(languageCode: languageCode),
                    isGranted: permissionMenu.accessibilityGranted,
                    systemImage: "accessibility",
                    buttonTitle: permissionMenu.openAccessibilityTitle(languageCode: languageCode),
                    buttonImage: "gearshape",
                    completionTitle: completionTitle,
                    action: openAccessibility
                )

                SettingsOnboardingPermissionStatusRow(
                    title: permissionMenu.inputMonitoringTitle(languageCode: languageCode),
                    isGranted: permissionMenu.inputMonitoringGranted,
                    systemImage: "keyboard.badge.eye.fill",
                    buttonTitle: permissionMenu.openSettingsTitle(languageCode: languageCode),
                    buttonImage: "keyboard",
                    completionTitle: completionTitle,
                    action: openInputMonitoring
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completionTitle: String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Done"
        case "ja": return "完了"
        case "zh": return "完成"
        default: return "완료"
        }
    }
}

private struct SettingsOnboardingPermissionStatusRow: View {
    let title: String
    let isGranted: Bool
    let systemImage: String
    let buttonTitle: String
    let buttonImage: String
    let completionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(.medium))

            Spacer(minLength: 12)

            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(completionTitle)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .modifier(SettingsNativeBadge())
            } else {
                Button(action: action) {
                    Label(buttonTitle, systemImage: buttonImage)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 40)
        }
    }
}

private struct SettingsPixelFeatureCard: View {
    let kind: SettingsOnboardingFeatureKind
    let languageCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            featureVisual
                .frame(height: 108)

            Text(kind.title(languageCode: languageCode))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(kind.body(languageCode: languageCode))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 226, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(kind.tint.opacity(0.42), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var featureVisual: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))

            switch kind {
            case .desktop:
                SettingsHomepageFeatureScene(
                    frameURLs: homepageFrames(state: "walk"),
                    accessory: .none,
                    accent: kind.tint,
                    catSize: 86
                )
            case .chat:
                SettingsHomepageFeatureScene(
                    frameURLs: homepageFrames(state: "idle"),
                    accessory: .chatInput,
                    accent: kind.tint,
                    catSize: 84
                )
            case .skills:
                SettingsHomepageFeatureScene(
                    frameURLs: homepageFrames(state: "thinking"),
                    accessory: .slashCommands(["/fortune", "/summarize", "/translate", "/today"]),
                    accent: kind.tint,
                    catSize: 84
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func homepageFrames(state: String) -> [URL] {
        SettingsBundledSpriteFrames.frames(skinID: "black", state: state)
    }
}

private enum SettingsHomepageFeatureAccessory: Equatable {
    case none
    case chatInput
    case slashCommands([String])
}

private struct SettingsHomepageFeatureScene: View {
    let frameURLs: [URL]
    let accessory: SettingsHomepageFeatureAccessory
    let accent: Color
    let catSize: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: 3)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }

            accessoryView
                .zIndex(2)

            SettingsPixelMiniCat(frameURLs: frameURLs, size: catSize)
                .padding(.bottom, 18)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chatInput:
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("무엇을 물어볼까냥?")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.72))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 130, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
            }
            .offset(x: 10, y: -71)
        case .slashCommands(let commands):
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                let safeCommands = commands.isEmpty ? ["/fortune"] : commands
                let command = safeCommands[
                    Int(context.date.timeIntervalSinceReferenceDate / 1.35) % safeCommands.count
                ]

                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                    Text(command)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                }
                .frame(width: 128, alignment: .leading)
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.32), lineWidth: 1)
                }
                .offset(x: 3, y: -85)
            }
        }
    }
}

private enum SettingsBundledSpriteFrames {
    static func frames(skinID: String, state: String) -> [URL] {
        let skinFrames = indexedFrames(subdirectory: "sprites/\(skinID)", state: state)
        if !skinFrames.isEmpty {
            return skinFrames
        }
        return indexedFrames(subdirectory: "sprites", state: state)
    }

    private static func indexedFrames(subdirectory: String, state: String) -> [URL] {
        (0..<4).compactMap { index in
            Bundle.main.url(
                forResource: "\(state)_\(index)",
                withExtension: "png",
                subdirectory: subdirectory
            )
        }
    }
}

private struct SettingsPixelMiniCat: View {
    let frameURLs: [URL]
    let size: CGFloat
    @State private var images: [NSImage] = []
    @State private var imageInterpolation: Image.Interpolation = .none

    private let cycleDuration = CatAnimationTiming.previewCycleDuration

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let frameIndex = CatAnimationTiming.frameIndex(
                at: context.date.timeIntervalSinceReferenceDate,
                cycleDuration: cycleDuration,
                frameCount: images.count
            )

            Group {
                if images.isEmpty {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Image(nsImage: images[frameIndex])
                        .interpolation(imageInterpolation)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: size, height: size)
        }
        .onAppear(perform: loadImages)
        .onChange(of: frameURLs) { _, _ in
            loadImages()
        }
    }

    private func loadImages() {
        imageInterpolation = skinPreviewInterpolation(for: frameURLs)
        images = frameURLs.compactMap { url in
            NSImage(contentsOf: url)
        }
    }
}

private struct SettingsOnboardingCatSpotlight: View {
    let frameURLs: [URL]
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))

            VStack(spacing: 12) {
                SettingsPixelMiniCat(frameURLs: frameURLs, size: 112)
                    .padding(.top, 8)

                HStack(spacing: 5) {
                    Image(systemName: "pawprint.fill")
                    Text("OpenNeko")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.38), lineWidth: 1)
        }
    }
}

private struct SettingsOnboardingDoneStep: View {
    let frameURLs: [URL]
    @Binding var launchAtLogin: Bool
    let title: String
    let subtitle: String

    var body: some View {
        let cardWidth: CGFloat = 288

        VStack(alignment: .leading, spacing: 12) {
            SettingsOnboardingCatPortrait(frameURLs: frameURLs, tint: .green, size: 158)
                .frame(width: cardWidth, height: 208)

            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .frame(width: cardWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsGlassHero: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsGlassSetupTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                    .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsGlassSummaryChip: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        }
    }
}

private struct SettingsGlassSectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)
        }
        .padding(.top, 8)
    }
}

private struct SettingsNativeBadge: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.secondary.opacity(0.09))
            }
    }
}

private struct SettingsOnboardingAISection: View {
    let readiness: AIProviderReadiness
    let detections: [AIProviderDetection]
    let currentPresetID: String
    let languageCode: String
    let apply: (AIProviderDetection) -> Void
    let refresh: () -> Void
    let selectPreset: (String) -> Void
    let autoApplyDetected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: selectedDetection == nil ? "magnifyingglass" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selectedDetection == nil ? Color.secondary : Color.green)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(aiSummaryTitle)
                        .font(.body.weight(.medium))
                    Text(aiSummaryBody)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Button(action: refresh) {
                    Label(SettingsCopy.text(.refreshDetection, languageCode: languageCode), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(AIProviderPreset.all) { preset in
                    let detection = providerDetection(for: preset.id)

                    Button {
                        if let detection {
                            apply(detection)
                        } else {
                            selectPreset(preset.id)
                        }
                    } label: {
                        SettingsOnboardingAIProviderCard(
                            preset: preset,
                            languageCode: languageCode,
                            isDetected: detection != nil,
                            isSelected: preset.id == selectedPresetID,
                            isRecommended: preset.isRecommended
                        )
                    }
                    .buttonStyle(.plain)
                    .help(selectProviderHelp)
                }
            }
        }
        .onAppear {
            guard autoApplyDetected,
                  let detection = selectedDetection,
                  detection.presetID != currentPresetID
            else {
                return
            }
            apply(detection)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 122), spacing: 10)]
    }

    private var selectedDetection: AIProviderDetection? {
        detections.first { $0.presetID == currentPresetID } ?? detections.first
    }

    private var selectedPresetID: String {
        currentPresetID
    }

    private func providerDetection(for presetID: String) -> AIProviderDetection? {
        detections.first { $0.presetID == presetID }
    }

    private var aiSummaryTitle: String {
        guard let detection = selectedDetection else {
            return laterTitle
        }
        return defaultConnectionTitle(detection)
    }

    private var aiSummaryBody: String {
        guard let detection = selectedDetection else {
            return laterBody
        }
        return defaultConnectionBody(detection)
    }

    private var statusTitle: String {
        if readiness.severity == .needsAction, !detections.isEmpty {
            return autoFoundTitle
        }
        if readiness.severity == .needsAction {
            return SettingsCopy.text(.onboardingAITitle, languageCode: languageCode)
        }
        return readiness.title
    }

    private var statusSubtitle: String {
        if readiness.severity == .needsAction, !detections.isEmpty {
            return autoFoundBody
        }
        if readiness.severity == .needsAction {
            return SettingsCopy.text(.onboardingAIBody, languageCode: languageCode)
        }
        return readiness.detail
    }

    private var statusImage: String {
        readiness.severity == .needsAction && !detections.isEmpty
            ? "sparkles"
            : readiness.systemImage
    }

    private var statusTint: Color {
        if readiness.severity == .needsAction, !detections.isEmpty {
            return .green
        }
        switch readiness.severity {
        case .ready:
            return .green
        case .warning:
            return .orange
        case .needsAction:
            return .secondary
        }
    }

    private var autoFoundTitle: String {
        localized(
            ko: "자동으로 찾은 연결",
            en: "Auto-detected connection",
            ja: "自動で見つけた接続",
            zh: "自动检测到的连接"
        )
    }

    private var autoFoundBody: String {
        localized(
            ko: "바로 쓸 수 있는 연결을 찾아 기본값으로 보여준다냥.",
            en: "I found a ready connection and show it as the default, nya.",
            ja: "すぐ使える接続を見つけて、標準として表示するにゃ。",
            zh: "已找到可用连接，并作为默认连接显示喵。"
        )
    }

    private var defaultBadge: String {
        localized(ko: "기본값", en: "Default", ja: "標準", zh: "默认")
    }

    private func defaultConnectionTitle(_ detection: AIProviderDetection) -> String {
        localized(
            ko: "\(detection.title(languageCode: languageCode)) 준비됨",
            en: "\(detection.title(languageCode: languageCode)) is ready",
            ja: "\(detection.title(languageCode: languageCode)) 準備完了",
            zh: "\(detection.title(languageCode: languageCode)) 已就绪"
        )
    }

    private func defaultConnectionBody(_ detection: AIProviderDetection) -> String {
        localized(
            ko: "\(detection.source.label(languageCode: languageCode))에서 자동으로 인식했다냥. 기본 연결로 써둔다냥.",
            en: "Auto-detected from \(detection.source.label(languageCode: languageCode)), nya. It will be used as the default connection.",
            ja: "\(detection.source.label(languageCode: languageCode))から自動で認識したにゃ。標準接続として使うにゃ。",
            zh: "已从\(detection.source.label(languageCode: languageCode))自动识别喵。将作为默认连接使用喵。"
        )
    }

    private var laterTitle: String {
        localized(
            ko: "나중에 해도 된다냥",
            en: "You can do this later, nya",
            ja: "後からでも大丈夫にゃ",
            zh: "之后再设置也可以喵"
        )
    }

    private var laterBody: String {
        localized(
            ko: "대화가 안 되면 메뉴바의 AI 설정에서 연결만 골라주면 된다냥.",
            en: "If chat is not ready, choose a connection later in AI Settings, nya.",
            ja: "話せないときはメニューバーのAI設定で接続を選べばいいにゃ。",
            zh: "如果还不能聊天，之后在菜单栏的 AI 设置里选择连接即可喵。"
        )
    }

    private var selectProviderHelp: String {
        localized(
            ko: "이 연결을 기본값으로 고른다냥.",
            en: "Choose this connection as the default, nya.",
            ja: "この接続を標準にするにゃ。",
            zh: "将此连接设为默认喵。"
        )
    }

    private var notDetectedHelp: String {
        localized(
            ko: "아직 자동으로 감지되지 않았다냥.",
            en: "This connection was not auto-detected yet, nya.",
            ja: "まだ自動検出されていないにゃ。",
            zh: "尚未自动检测到此连接喵。"
        )
    }

    private func localized(ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}

private struct SettingsOnboardingAIProviderCard: View {
    let preset: AIProviderPreset
    let languageCode: String
    let isDetected: Bool
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                SettingsProviderIcon(presetID: preset.id, size: 36)

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.34))
            }

            Text(preset.title(languageCode: languageCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Text(SettingsProviderVisual.modeLabel(for: preset, languageCode: languageCode))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SettingsProviderVisual.accent(for: preset.id))
                    .lineLimit(1)

                if isSelected {
                    Text(defaultBadge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                } else if isDetected {
                    Text(detectedBadge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                } else if isRecommended {
                    Text(SettingsCopy.text(.recommended, languageCode: languageCode))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? SettingsProviderVisual.accent(for: preset.id).opacity(0.11) : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return SettingsProviderVisual.accent(for: preset.id).opacity(0.76)
        }
        if isDetected {
            return Color.green.opacity(0.48)
        }
        return Color(nsColor: .separatorColor).opacity(0.38)
    }

    private var defaultBadge: String {
        localized(ko: "기본값", en: "Default", ja: "標準", zh: "默认")
    }

    private var detectedBadge: String {
        localized(ko: "찾음", en: "Found", ja: "検出", zh: "已找到")
    }

    private func localized(ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}

private struct SettingsGlassDetectedProvidersSection: View {
    let detections: [AIProviderDetection]
    let currentPresetID: String
    let languageCode: String
    let apply: (AIProviderDetection) -> Void
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGlassRow(systemImage: "antenna.radiowaves.left.and.right", iconTint: .green) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SettingsCopy.text(.detectedProviders, languageCode: languageCode))
                        .font(.body.weight(.medium))
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } trailing: {
                Button(action: refresh) {
                    Label(SettingsCopy.text(.refreshDetection, languageCode: languageCode), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            ForEach(detections) { detection in
                SettingsGlassDetectedProviderRow(
                    detection: detection,
                    isCurrent: detection.presetID == currentPresetID,
                    languageCode: languageCode,
                    apply: { apply(detection) }
                )
            }
        }
    }

    private var summary: String {
        if detections.isEmpty {
            return SettingsCopy.text(.detectedProvidersEmpty, languageCode: languageCode)
        }
        return detections.map { $0.title(languageCode: languageCode) }.joined(separator: " · ")
    }
}

private struct SettingsGlassDetectedProviderRow: View {
    let detection: AIProviderDetection
    let isCurrent: Bool
    let languageCode: String
    let apply: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsProviderIcon(presetID: detection.presetID, size: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(detection.title(languageCode: languageCode))
                        .font(.body.weight(.medium))
                    Text(detection.source.label(languageCode: languageCode))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .modifier(SettingsNativeBadge())
                    if detection.isRecommended {
                        Text(SettingsCopy.text(.recommended, languageCode: languageCode))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(detection.subtitle(languageCode: languageCode))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if isCurrent {
                Button(action: apply) {
                    Label(
                        SettingsCopy.text(.currentProvider, languageCode: languageCode),
                        systemImage: "checkmark.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            } else {
                Button(action: apply) {
                    Label(
                        SettingsCopy.text(.useProvider, languageCode: languageCode),
                        systemImage: "arrow.right.circle"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 44)
        }
    }
}

private struct SettingsGlassSkillRow: View {
    let skill: NekoSkill
    let isEnabled: Bool
    let languageCode: String
    let run: () -> Void
    let setEnabled: (Bool) -> Void

    var body: some View {
        SettingsGlassRow(systemImage: systemImage, iconTint: iconTint) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                    Text(skill.input.title(languageCode: languageCode))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .modifier(SettingsNativeBadge())
                    if skill.source == .user {
                        Text(SettingsCopy.text(.user, languageCode: languageCode))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(skill.description.isEmpty ? skill.id : skill.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } trailing: {
            HStack(spacing: 8) {
                Button(action: run) {
                    Image(systemName: "play.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled)
                .help(isEnabled
                    ? SettingsCopy.text(skill.input == .prompt ? .activateSkill : .runSkill, languageCode: languageCode)
                    : SettingsCopy.text(.skillDisabled, languageCode: languageCode)
                )

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
    }

    private var systemImage: String {
        switch skill.input {
        case .prompt: "text.cursor"
        case .clipboard: "doc.on.clipboard"
        case .none: "play.circle"
        }
    }

    private var iconTint: Color {
        isEnabled ? .purple : .secondary
    }
}

private struct SettingsGlassPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)

                content
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsGlassDisclosureSection<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }
}

private struct SettingsGlassToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct SettingsGlassCheckboxRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)
        }
    }
}

private struct SettingsGlassStatusRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        SettingsGlassRow(systemImage: systemImage, iconTint: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            EmptyView()
        }
    }
}

private struct SettingsGlassPermissionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let buttonTitle: String
    let buttonImage: String
    let action: () -> Void

    var body: some View {
        SettingsGlassRow(systemImage: systemImage, iconTint: tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Button(action: action) {
                Label(buttonTitle, systemImage: buttonImage)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct SettingsGlassCommandRow: View {
    let title: String
    let command: String
    let didCopy: Bool
    let languageCode: String
    let copy: () -> Void

    var body: some View {
        SettingsGlassRow(systemImage: "terminal", iconTint: .accentColor) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } trailing: {
            Button(action: copy) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .tint(didCopy ? .green : .accentColor)
            .help(SettingsCopy.text(didCopy ? .copied : .copyCommand, languageCode: languageCode))
        }
    }
}

private struct SettingsGlassCompactTextFieldRow: View {
    let title: String
    let systemImage: String
    let prompt: String
    let width: CGFloat
    let monospaced: Bool
    @Binding private var text: String
    @State private var draftText: String

    init(
        title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String = "",
        width: CGFloat,
        monospaced: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prompt = prompt
        self.width = width
        self.monospaced = monospaced
        self._text = text
        self._draftText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            Text(title)
                .font(.body.weight(.medium))
        } trailing: {
            TextField(prompt, text: $draftText)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .body.monospacedDigit() : .body)
                .frame(width: width)
                .onChange(of: draftText) { _, newValue in
                    text = newValue
                }
                .onChange(of: text) { _, newValue in
                    if draftText != newValue {
                        draftText = newValue
                    }
                }
        }
    }
}

private struct SettingsGlassDatePickerRow: View {
    let title: String
    let systemImage: String
    @Binding var selection: Date
    let components: DatePickerComponents
    let width: CGFloat

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            Text(title)
                .font(.body.weight(.medium))
        } trailing: {
            DatePicker("", selection: $selection, displayedComponents: components)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(width: width, alignment: .leading)
        }
    }
}

private struct SettingsRadioOption: Identifiable {
    let id: String
    let title: String
}

private struct SettingsGlassRadioRow: View {
    let title: String
    let systemImage: String
    let options: [SettingsRadioOption]
    @Binding var selection: String
    let width: CGFloat

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            Text(title)
                .font(.body.weight(.medium))
        } trailing: {
            HStack(spacing: 14) {
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        selection == option.id ? Color.accentColor : Color.secondary.opacity(0.7),
                                        lineWidth: 1.3
                                    )
                                if selection == option.id {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(width: 14, height: 14)

                            Text(option.title)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

private struct SettingsGlassTextFieldRow: View {
    let title: String
    let systemImage: String
    let prompt: String
    @Binding private var text: String
    @State private var draftText: String

    init(
        title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String = ""
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prompt = prompt
        self._text = text
        self._draftText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        SettingsGlassRow(systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.body.weight(.medium))
                TextField(prompt, text: $draftText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draftText) { _, newValue in
                        text = newValue
                    }
                    .onChange(of: text) { _, newValue in
                        if draftText != newValue {
                            draftText = newValue
                        }
                    }
            }
        } trailing: {
            EmptyView()
        }
    }
}

private struct SettingsOnboardingNameField: View {
    let title: String
    let systemImage: String
    let prompt: String
    @Binding private var text: String
    @State private var draftText: String

    init(
        title: String,
        systemImage: String,
        text: Binding<String>,
        prompt: String = ""
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prompt = prompt
        self._text = text
        self._draftText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.headline.weight(.semibold))
            }

            TextField(prompt, text: $draftText)
                .textFieldStyle(.roundedBorder)
                .font(.title3.weight(.medium))
                .onChange(of: draftText) { _, newValue in
                    text = newValue
                }
                .onChange(of: text) { _, newValue in
                    if draftText != newValue {
                        draftText = newValue
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 44)
        }
    }
}

private struct SettingsGlassAPIKeyRow: View {
    let hasKey: Bool
    let languageCode: String
    let saveAPIKey: (String) -> Void
    let clearAPIKey: () -> Void
    @State private var apiKey = ""

    var body: some View {
        SettingsGlassRow(systemImage: "key") {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(SettingsCopy.text(.apiKey, languageCode: languageCode))
                        .font(.body.weight(.medium))
                    if hasKey {
                        Text(SettingsCopy.text(.saved, languageCode: languageCode))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                SecureField(
                    SettingsCopy.text(hasKey ? .replaceAPIKey : .enterAPIKey, languageCode: languageCode),
                    text: $apiKey
                )
                    .textFieldStyle(.roundedBorder)
            }
        } trailing: {
            HStack(spacing: 6) {
                Button {
                    saveAPIKey(apiKey)
                    apiKey = ""
                } label: {
                    Image(systemName: "checkmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(SettingsCopy.text(.saveAPIKey, languageCode: languageCode))

                if hasKey {
                    Button {
                        clearAPIKey()
                        apiKey = ""
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .help(SettingsCopy.text(.deleteAPIKey, languageCode: languageCode))
                }
            }
        }
    }
}

private struct SettingsGlassRow<Content: View, Trailing: View>: View {
    let systemImage: String
    var iconTint: Color = .accentColor
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 26, height: 26)

            content

            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 44)
        }
    }
}

private struct SettingsGlassSkinTile: View {
    let title: String
    let systemImage: String
    let frameURLs: [URL]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSkinWalkPreview(frameURLs: frameURLs, placeholderSystemImage: systemImage)

            HStack(spacing: 8) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(SettingsGlassStyle.rowCornerRadius), style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.45),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }
}

private struct SettingsSkinWalkPreview: View {
    let frameURLs: [URL]
    let placeholderSystemImage: String
    var catSize: CGFloat = 58
    var previewHeight: CGFloat = 74
    @State private var images: [NSImage] = []
    @State private var imageInterpolation: Image.Interpolation = .none

    private let cycleDuration = CatAnimationTiming.previewCycleDuration
    private let travelDuration: TimeInterval = 2.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { proxy in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let frameIndex = CatAnimationTiming.frameIndex(
                    at: elapsed,
                    cycleDuration: cycleDuration,
                    frameCount: images.count
                )
                let cyclePosition = elapsed.truncatingRemainder(dividingBy: travelDuration) / travelDuration
                let movingRight = cyclePosition < 0.5
                let progress = movingRight ? cyclePosition * 2 : (1 - cyclePosition) * 2
                let travel = max(proxy.size.width - catSize, 0)
                let xOffset = -travel / 2 + CGFloat(progress) * travel
                // Retain the existing 0.12-second step even with in-between frames.
                let bobPhase = CatAnimationTiming.frameIndex(
                    at: elapsed,
                    cycleDuration: 0.24,
                    frameCount: 2
                )
                let bobOffset: CGFloat = bobPhase == 0 ? 0 : -2

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.62))

                    Rectangle()
                        .fill(Color.primary.opacity(0.16))
                        .frame(height: 2)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 11)

                    if images.isEmpty {
                        Image(systemName: placeholderSystemImage)
                            .font(.system(size: catSize * 0.45, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(nsImage: images[frameIndex])
                            .interpolation(imageInterpolation)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(x: movingRight ? 1 : -1, y: 1)
                            .frame(width: catSize, height: catSize)
                            .offset(x: xOffset, y: bobOffset - 6)
                    }
                }
            }
        }
        .frame(height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 1)
        }
        .onAppear(perform: loadImages)
        .onChange(of: frameURLs) { _, _ in
            loadImages()
        }
    }

    private func loadImages() {
        imageInterpolation = skinPreviewInterpolation(for: frameURLs)
        images = frameURLs.compactMap { url in
            NSImage(contentsOf: url)
        }
    }
}

private func skinPreviewInterpolation(for frameURLs: [URL]) -> Image.Interpolation {
    guard let directory = frameURLs.first?.deletingLastPathComponent(),
          let data = try? Data(contentsOf: directory.appendingPathComponent("render-info.json")),
          let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          info["filtering"] as? String == "linear"
    else { return .none }
    return .high
}

private struct SettingsGlassBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}
