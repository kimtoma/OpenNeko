import AppKit

enum DockSupportFrameProvider {
    static func dockFrame(for screen: NSScreen) -> NSRect? {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let bottomGap = visibleFrame.minY - screenFrame.minY
        guard bottomGap > 2, dockOrientation() == "bottom" else {
            return nil
        }

        let width = estimatedBottomDockWidth(screenWidth: screenFrame.width)
        return NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY,
            width: width,
            height: bottomGap
        )
    }

    private static func dockOrientation() -> String {
        preference("orientation") as? String ?? "bottom"
    }

    private static func estimatedBottomDockWidth(screenWidth: CGFloat) -> CGFloat {
        let tileSize = numberPreference("tilesize") ?? 54
        let appCount = arrayPreference("persistent-apps")?.count ?? 8
        let otherCount = arrayPreference("persistent-others")?.count ?? 0
        let showRecents = boolPreference("show-recents") ?? true
        let recentSlots = showRecents ? 3 : 0
        let itemCount = max(4, appCount + otherCount + recentSlots)
        let separatorAllowance = otherCount > 0 ? tileSize * 0.35 : 0
        let rawWidth = CGFloat(itemCount) * (tileSize * 0.82) + separatorAllowance + 56
        return min(screenWidth - 40, max(tileSize * 5, rawWidth))
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
