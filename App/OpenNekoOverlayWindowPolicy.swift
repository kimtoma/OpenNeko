import AppKit

extension NSWindow {
    func applyOpenNekoOverlayWindowPolicy() {
        sharingType = .none
        isExcludedFromWindowsMenu = true
    }
}
