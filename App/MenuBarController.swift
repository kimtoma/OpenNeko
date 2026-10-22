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
    private let enabledSkills: () -> [NekoSkill]
    private let updateStatus: () -> AppUpdateStatus
    private let languageCode: () -> String
    private let onToggleAlwaysOnTop: () -> Void
    private let onToggleSoundEffects: () -> Void
    private let onRunSkill: (String) -> Void
    private let onCheckForUpdates: () -> Void
    private let onApplyUpdate: () -> Void
    private let menu = NSMenu()

    init(
        onToggleCat: @escaping () -> Void,
        onOpenChatHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        isCatVisible: @escaping () -> Bool,
        isAlwaysOnTopEnabled: @escaping () -> Bool,
        soundEffectsEnabled: @escaping () -> Bool,
        enabledSkills: @escaping () -> [NekoSkill],
        updateStatus: @escaping () -> AppUpdateStatus,
        languageCode: @escaping () -> String,
        onToggleAlwaysOnTop: @escaping () -> Void,
        onToggleSoundEffects: @escaping () -> Void,
        onRunSkill: @escaping (String) -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onApplyUpdate: @escaping () -> Void
    ) {
        self.onToggleCat = onToggleCat
        self.onOpenChatHistory = onOpenChatHistory
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.isCatVisible = isCatVisible
        self.isAlwaysOnTopEnabled = isAlwaysOnTopEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.enabledSkills = enabledSkills
        self.updateStatus = updateStatus
        self.languageCode = languageCode
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.onToggleSoundEffects = onToggleSoundEffects
        self.onRunSkill = onRunSkill
        self.onCheckForUpdates = onCheckForUpdates
        self.onApplyUpdate = onApplyUpdate
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

        if !enabledSkills().isEmpty {
            menu.addItem(.separator())
            menu.addItem(skillsMenuItem())
        }

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

        for skill in enabledSkills() {
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
    @objc private func alwaysOnTopTapped() { onToggleAlwaysOnTop() }
    @objc private func soundTapped() { onToggleSoundEffects() }
    @objc private func checkForUpdatesTapped() { onCheckForUpdates() }
    @objc private func applyUpdateTapped() { onApplyUpdate() }
    @objc private func skillTapped(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onRunSkill(id)
    }
    @objc private func quitTapped() { onQuit() }

    private enum MenuCopy {
        case alwaysOnTop
        case sound
        case chatHistory
        case settings
        case quit
        case skills
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
            }
        case "ja":
            switch key {
            case .alwaysOnTop: "常に手前に表示"
            case .sound: "効果音"
            case .chatHistory: "会話履歴..."
            case .settings: "設定..."
            case .quit: "終了"
            case .skills: "スキル"
            }
        case "zh":
            switch key {
            case .alwaysOnTop: "始终置顶"
            case .sound: "音效"
            case .chatHistory: "对话历史..."
            case .settings: "设置..."
            case .quit: "退出"
            case .skills: "技能"
            }
        default:
            switch key {
            case .alwaysOnTop: "항상 위에 표시"
            case .sound: "효과음"
            case .chatHistory: "대화 내역..."
            case .settings: "설정..."
            case .quit: "종료"
            case .skills: "스킬"
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
