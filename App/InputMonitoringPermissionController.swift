import AppKit
import ApplicationServices
import Foundation
import OpenNekoKit

enum InputMonitoringPermissionController {
    static var status: InputMonitoringPermissionStatus {
        hasAccessibilityPermission && KeyboardMonitor.hasListenPermission ? .granted : .missing
    }

    static var menu: InputMonitoringPermissionMenu {
        let accessibilityGranted = hasAccessibilityPermission
        let inputMonitoringGranted = KeyboardMonitor.hasListenPermission
        return InputMonitoringPermissionMenu(
            status: accessibilityGranted && inputMonitoringGranted ? .granted : .missing,
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted
        )
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func requestPermission() -> Bool {
        KeyboardMonitor.requestListenPermission()
    }

    static func openAccessibilitySystemSettings() {
        openSystemSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security",
        ])
    }

    static func openInputMonitoringSystemSettings() {
        openSystemSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security",
        ])
    }

    private static func openSystemSettings(urls: [String]) {
        for value in urls {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
