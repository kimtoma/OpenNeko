import AppKit

extension NSWindow {
    func applyOpenNekoOverlayWindowPolicy() {
        sharingType = .readOnly
        isExcludedFromWindowsMenu = true
    }
}
