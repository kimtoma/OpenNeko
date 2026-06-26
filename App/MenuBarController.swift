import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let onToggleCat: () -> Void
    private let onQuit: () -> Void

    init(onToggleCat: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggleCat = onToggleCat
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "openNeko")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "고양이 보이기/숨기기", action: #selector(toggleTapped), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quitTapped), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleTapped() { onToggleCat() }
    @objc private func quitTapped() { onQuit() }
}
