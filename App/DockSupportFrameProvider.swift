import AppKit
import OpenNekoKit

@MainActor
enum DockSupportFrameProvider {
    private static var preferenceCache = DockSupportPreferenceCache()

    static func dockFrame(for screen: NSScreen) -> NSRect? {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        guard visibleFrame.minY - screenFrame.minY > 2 else { return nil }

        let preferences = preferenceCache.preferences(at: ProcessInfo.processInfo.systemUptime) {
            DockSupportPreferences(
                orientation: preference("orientation") as? String ?? "bottom",
                tileSize: numberPreference("tilesize") ?? 54,
                appCount: arrayPreference("persistent-apps")?.count ?? 8,
                otherCount: arrayPreference("persistent-others")?.count ?? 0,
                showRecents: boolPreference("show-recents") ?? true
            )
        }
        return preferences.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
    }

    private static func preference(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }

    private static func numberPreference(_ key: String) -> CGFloat? {
        guard let value = preference(key) as? NSNumber else { return nil }
        return CGFloat(truncating: value)
    }

    private static func boolPreference(_ key: String) -> Bool? {
        guard let value = preference(key) as? NSNumber else { return nil }
        return value.boolValue
    }

    private static func arrayPreference(_ key: String) -> [Any]? {
        preference(key) as? [Any]
    }
}
