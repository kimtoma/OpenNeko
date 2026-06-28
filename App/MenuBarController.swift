import AppKit
import OpenNekoKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onToggleCat: () -> Void
    private let onOpenChatHistory: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private let isCatVisible: () -> Bool
    private let isAlwaysOnTopEnabled: () -> Bool
    private let soundEffectsEnabled: () -> Bool
    private let permissionMenu: () -> InputMonitoringPermissionMenu
    private let enabledSkills: () -> [NekoSkill]
    private let neighborPeerCount: () -> Int
    private let updateStatus: () -> AppUpdateStatus
    private let languageCode: () -> String
    private let onToggleAlwaysOnTop: () -> Void
    private let onToggleSoundEffects: () -> Void
    private let onPreviewState: (CatState) -> Void
    private let onRunSkill: (String) -> Void
    private let onSendNeighborWave: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onApplyUpdate: () -> Void
    private let onOpenAccessibility: () -> Void
    private let onOpenInputMonitoring: () -> Void
    private let onRetryKeyboardMonitor: () -> Void
    private let menu = NSMenu()

    init(
        onToggleCat: @escaping () -> Void,
        onOpenChatHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        isCatVisible: @escaping () -> Bool,
        isAlwaysOnTopEnabled: @escaping () -> Bool,
        soundEffectsEnabled: @escaping () -> Bool,
        permissionMenu: @escaping () -> InputMonitoringPermissionMenu,
        enabledSkills: @escaping () -> [NekoSkill],
        neighborPeerCount: @escaping () -> Int,
        updateStatus: @escaping () -> AppUpdateStatus,
        languageCode: @escaping () -> String,
        onToggleAlwaysOnTop: @escaping () -> Void,
        onToggleSoundEffects: @escaping () -> Void,
        onPreviewState: @escaping (CatState) -> Void,
        onRunSkill: @escaping (String) -> Void,
        onSendNeighborWave: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onApplyUpdate: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onOpenInputMonitoring: @escaping () -> Void,
        onRetryKeyboardMonitor: @escaping () -> Void
    ) {
        self.onToggleCat = onToggleCat
        self.onOpenChatHistory = onOpenChatHistory
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.isCatVisible = isCatVisible
        self.isAlwaysOnTopEnabled = isAlwaysOnTopEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.permissionMenu = permissionMenu
        self.enabledSkills = enabledSkills
        self.neighborPeerCount = neighborPeerCount
        self.updateStatus = updateStatus
        self.languageCode = languageCode
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.onToggleSoundEffects = onToggleSoundEffects
        self.onPreviewState = onPreviewState
        self.onRunSkill = onRunSkill
        self.onSendNeighborWave = onSendNeighborWave
        self.onCheckForUpdates = onCheckForUpdates
        self.onApplyUpdate = onApplyUpdate
        self.onOpenAccessibility = onOpenAccessibility
        self.onOpenInputMonitoring = onOpenInputMonitoring
        self.onRetryKeyboardMonitor = onRetryKeyboardMonitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "openNeko")
                ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "openNeko")
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
        }

        menu.delegate = self
        rebuildMenu()
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func refresh() {
        rebuildMenu()
    }

    func popUpContextMenu(anchorView: NSView) {
        let contextMenu = NSMenu()
        populateContextMenu(contextMenu)
        let screenPoint = NSEvent.mouseLocation
        let windowPoint = anchorView.window?.convertPoint(fromScreen: screenPoint) ?? .zero
        let localPoint = anchorView.convert(windowPoint, from: nil)
        contextMenu.popUp(positioning: nil, at: localPoint, in: anchorView)
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        let language = languageCode()
        let toggle = NSMenuItem(
            title: CatStateMenu.catVisibilityTitle(isVisible: isCatVisible(), languageCode: language),
            action: #selector(toggleTapped),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let alwaysOnTop = NSMenuItem(title: localized(.alwaysOnTop, language: language), action: #selector(alwaysOnTopTapped), keyEquivalent: "")
        alwaysOnTop.target = self
        alwaysOnTop.state = isAlwaysOnTopEnabled() ? .on : .off
        menu.addItem(alwaysOnTop)

        let sound = NSMenuItem(title: localized(.sound, language: language), action: #selector(soundTapped), keyEquivalent: "")
        sound.target = self
        sound.state = soundEffectsEnabled() ? .on : .off
        menu.addItem(sound)

        let permission = permissionMenu()
        menu.addItem(.separator())
        let status = NSMenuItem(title: permission.statusTitle(languageCode: language), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let openAccessibility = NSMenuItem(title: permission.openAccessibilityTitle(languageCode: language), action: #selector(openAccessibilityTapped), keyEquivalent: "")
        openAccessibility.target = self
        menu.addItem(openAccessibility)

        let openSettings = NSMenuItem(title: permission.openSettingsTitle(languageCode: language), action: #selector(openInputMonitoringTapped), keyEquivalent: "")
        openSettings.target = self
        menu.addItem(openSettings)

        let retry = NSMenuItem(title: permission.retryTitle(languageCode: language), action: #selector(retryKeyboardMonitorTapped), keyEquivalent: "")
        retry.target = self
        menu.addItem(retry)

        menu.addItem(.separator())
        menu.addItem(skillsMenuItem())
        menu.addItem(previewMenuItem())
        menu.addItem(neighborMenuItem())

        menu.addItem(.separator())
        menu.addItem(updateMenuItem())

        menu.addItem(.separator())
        let chatHistory = NSMenuItem(title: localized(.chatHistory, language: language), action: #selector(chatHistoryTapped), keyEquivalent: "")
        chatHistory.target = self
        menu.addItem(chatHistory)

        let settings = NSMenuItem(title: localized(.settings, language: language), action: #selector(settingsTapped), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: localized(.quit, language: language), action: #selector(quitTapped), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func populateContextMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let language = languageCode()
        let toggle = iconMenuItem(
            title: CatStateMenu.catVisibilityTitle(isVisible: isCatVisible(), languageCode: language),
            action: #selector(toggleTapped),
            systemImage: isCatVisible() ? "eye.slash" : "eye"
        )
        menu.addItem(toggle)

        let alwaysOnTop = iconMenuItem(
            title: localized(.alwaysOnTop, language: language),
            action: #selector(alwaysOnTopTapped),
            systemImage: "pin"
        )
        alwaysOnTop.state = isAlwaysOnTopEnabled() ? .on : .off
        menu.addItem(alwaysOnTop)

        let sound = iconMenuItem(
            title: localized(.sound, language: language),
            action: #selector(soundTapped),
            systemImage: soundEffectsEnabled() ? "speaker.wave.2" : "speaker.slash"
        )
        sound.state = soundEffectsEnabled() ? .on : .off
        menu.addItem(sound)

        menu.addItem(.separator())
        if !enabledSkills().isEmpty {
            menu.addItem(skillsMenuItem())
        }

        if neighborPeerCount() > 0 {
            menu.addItem(neighborMenuItem())
        }

        let chatHistory = iconMenuItem(
            title: localized(.chatHistory, language: language),
            action: #selector(chatHistoryTapped),
            systemImage: "bubble.left.and.bubble.right"
        )
        menu.addItem(chatHistory)

        menu.addItem(.separator())
        menu.addItem(iconMenuItem(
            title: localized(.settings, language: language),
            action: #selector(settingsTapped),
            keyEquivalent: ",",
            systemImage: "gearshape"
        ))
        menu.addItem(iconMenuItem(
            title: localized(.quit, language: language),
            action: #selector(quitTapped),
            keyEquivalent: "q",
            systemImage: "power"
        ))
    }

    private func skillsMenuItem() -> NSMenuItem {
        let language = languageCode()
        let root = iconMenuItem(title: localized(.skills, language: language), action: nil, systemImage: "wand.and.stars")
        let submenu = NSMenu()
        let skills = enabledSkills()

        guard !skills.isEmpty else {
            let empty = NSMenuItem(title: localized(.noSkills, language: language), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            root.submenu = submenu
            return root
        }

        for skill in skills {
            let item = NSMenuItem(
                title: "\(skill.name) · \(skill.input.title)",
                action: #selector(skillTapped(_:)),
                keyEquivalent: ""
            )
            item.representedObject = skill.id
            item.target = self
            item.image = menuIcon(skill.input.menuSystemImage, title: skill.name)
            submenu.addItem(item)
        }
        root.submenu = submenu
        return root
    }

    private func neighborMenuItem() -> NSMenuItem {
        let language = languageCode()
        let count = neighborPeerCount()
        let title = count > 0
            ? localized(.waveNeighbor, language: language, count: count)
            : localized(.findingNeighbors, language: language)
        let item = NSMenuItem(title: title, action: #selector(neighborWaveTapped), keyEquivalent: "")
        item.target = self
        item.image = menuIcon("hand.wave", title: title)
        item.isEnabled = count > 0
        return item
    }

    private func previewMenuItem() -> NSMenuItem {
        let language = languageCode()
        let root = iconMenuItem(title: localized(.previewState, language: language), action: nil, systemImage: "play.rectangle")
        let submenu = NSMenu()
        for state in CatStateMenu.previewStates {
            let item = NSMenuItem(
                title: CatStateMenu.title(for: state, languageCode: language),
                action: #selector(previewStateTapped(_:)),
                keyEquivalent: ""
            )
            item.representedObject = state.rawValue
            item.target = self
            item.image = menuIcon(state.menuSystemImage, title: item.title)
            submenu.addItem(item)
        }
        root.submenu = submenu
        return root
    }

    private func updateMenuItem() -> NSMenuItem {
        let status = updateStatus()
        let isAvailable: Bool
        if case .available = status {
            isAvailable = true
        } else {
            isAvailable = false
        }
        let item = NSMenuItem(
            title: status.menuTitle(languageCode: languageCode()),
            action: isAvailable ? #selector(applyUpdateTapped) : #selector(checkForUpdatesTapped),
            keyEquivalent: ""
        )
        item.target = self
        item.image = menuIcon(isAvailable ? "arrow.down.circle" : "arrow.clockwise", title: item.title)
        item.isEnabled = status.menuIsEnabled
        return item
    }

    private func iconMenuItem(
        title: String,
        action: Selector?,
        keyEquivalent: String = "",
        systemImage: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = action == nil ? nil : self
        item.image = menuIcon(systemImage, title: title)
        return item
    }

    private func menuIcon(_ systemImage: String, title: String) -> NSImage? {
        let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func toggleTapped() { onToggleCat() }
    @objc private func chatHistoryTapped() { onOpenChatHistory() }
    @objc private func settingsTapped() { onOpenSettings() }
    @objc private func neighborWaveTapped() { onSendNeighborWave() }
    @objc private func alwaysOnTopTapped() { onToggleAlwaysOnTop() }
    @objc private func soundTapped() { onToggleSoundEffects() }
    @objc private func checkForUpdatesTapped() { onCheckForUpdates() }
    @objc private func applyUpdateTapped() { onApplyUpdate() }
    @objc private func previewStateTapped(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let state = CatState(rawValue: rawValue)
        else {
            return
        }
        onPreviewState(state)
    }
    @objc private func skillTapped(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onRunSkill(id)
    }
    @objc private func openInputMonitoringTapped() { onOpenInputMonitoring() }
    @objc private func openAccessibilityTapped() { onOpenAccessibility() }
    @objc private func retryKeyboardMonitorTapped() { onRetryKeyboardMonitor() }
    @objc private func quitTapped() { onQuit() }

    private enum MenuCopy {
        case alwaysOnTop
        case sound
        case chatHistory
        case settings
        case quit
        case skills
        case noSkills
        case waveNeighbor
        case findingNeighbors
        case previewState
    }

    private func localized(_ key: MenuCopy, language: String, count: Int = 0) -> String {
        switch AppLanguage.normalized(language) ?? "ko" {
        case "en":
            switch key {
            case .alwaysOnTop: "Always on Top"
            case .sound: "Sound Effects"
            case .chatHistory: "Chat History..."
            case .settings: "Settings..."
            case .quit: "Quit"
            case .skills: "Skills"
            case .noSkills: "No Active Skills"
            case .waveNeighbor: "Wave to Neighbor (\(count))"
            case .findingNeighbors: "Finding Neighbors"
            case .previewState: "Preview State"
            }
        case "ja":
            switch key {
            case .alwaysOnTop: "常に手前に表示"
            case .sound: "効果音"
            case .chatHistory: "会話履歴..."
            case .settings: "設定..."
            case .quit: "終了"
            case .skills: "スキル"
            case .noSkills: "有効なスキルなし"
            case .waveNeighbor: "近くのねこに挨拶 (\(count))"
            case .findingNeighbors: "近くのねこを検索中"
            case .previewState: "状態プレビュー"
            }
        case "zh":
            switch key {
            case .alwaysOnTop: "始终置顶"
            case .sound: "音效"
            case .chatHistory: "对话历史..."
            case .settings: "设置..."
            case .quit: "退出"
            case .skills: "技能"
            case .noSkills: "没有启用的技能"
            case .waveNeighbor: "向邻居打招呼 (\(count))"
            case .findingNeighbors: "正在寻找邻居"
            case .previewState: "预览状态"
            }
        default:
            switch key {
            case .alwaysOnTop: "항상 위에 표시"
            case .sound: "효과음"
            case .chatHistory: "대화 내역..."
            case .settings: "설정..."
            case .quit: "종료"
            case .skills: "스킬"
            case .noSkills: "활성 스킬 없음"
            case .waveNeighbor: "이웃 고양이에게 인사 (\(count))"
            case .findingNeighbors: "이웃 고양이 찾는 중"
            case .previewState: "상태 미리보기"
            }
        }
    }
}

private extension NekoSkillInput {
    var menuSystemImage: String {
        switch self {
        case .prompt: "text.cursor"
        case .clipboard: "doc.on.clipboard"
        case .none: "play.circle"
        }
    }
}

private extension CatState {
    var menuSystemImage: String {
        switch self {
        case .idle: "circle"
        case .hover: "eye"
        case .click: "cursorarrow.click"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .typing: "keyboard"
        case .thinking: "brain"
        case .lunch: "fork.knife"
        case .yawn: "moon"
        case .nap: "bed.double"
        case .success: "checkmark.circle"
        case .error: "exclamationmark.triangle"
        case .dragging: "hand.draw"
        case .walk: "figure.walk"
        case .jump: "arrow.up"
        }
    }
}
