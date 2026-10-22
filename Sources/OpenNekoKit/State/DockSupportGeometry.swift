import CoreGraphics
import Foundation

/// The small subset of Dock preferences needed to estimate its support surface.
public struct DockSupportPreferences: Equatable, Sendable {
    public let orientation: String
    public let tileSize: CGFloat
    public let appCount: Int
    public let otherCount: Int
    public let showRecents: Bool

    public init(
        orientation: String = "bottom",
        tileSize: CGFloat = 54,
        appCount: Int = 8,
        otherCount: Int = 0,
        showRecents: Bool = true
    ) {
        self.orientation = orientation
        self.tileSize = tileSize
        self.appCount = appCount
        self.otherCount = otherCount
        self.showRecents = showRecents
    }

    public func frame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect? {
        let bottomGap = visibleFrame.minY - screenFrame.minY
        guard bottomGap > 2, orientation == "bottom" else { return nil }

        let recentSlots = showRecents ? 3 : 0
        let itemCount = max(4, appCount + otherCount + recentSlots)
        let separatorAllowance = otherCount > 0 ? tileSize * 0.35 : 0
        let rawWidth = CGFloat(itemCount) * (tileSize * 0.82) + separatorAllowance + 56
        let width = min(screenFrame.width - 40, max(tileSize * 5, rawWidth))
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY,
            width: width,
            height: bottomGap
        )
    }
}

/// Caches preferences only: screen and visible-frame geometry remain live.
public struct DockSupportPreferenceCache: Sendable {
    public static let refreshInterval: TimeInterval = 1
    private var cachedPreferences: DockSupportPreferences?
    private var cachedAt: TimeInterval = 0

    public init() {}

    public mutating func preferences(
        at now: TimeInterval,
        load: () -> DockSupportPreferences
    ) -> DockSupportPreferences {
        if let cachedPreferences,
           now >= cachedAt,
           now - cachedAt < Self.refreshInterval {
            return cachedPreferences
        }
        let preferences = load()
        cachedPreferences = preferences
        cachedAt = now
        return preferences
    }
}
