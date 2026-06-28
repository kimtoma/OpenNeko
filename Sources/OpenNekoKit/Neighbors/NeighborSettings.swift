import Foundation

public struct NeighborSettings: Codable, Equatable, Sendable {
    public static let defaults = NeighborSettings()

    public var enabled: Bool
    public var displayName: String

    public init(enabled: Bool = true, displayName: String = "") {
        self.enabled = enabled
        self.displayName = UserProfile.sanitized(displayName, limit: 64)
    }

    public func normalized() -> NeighborSettings {
        NeighborSettings(enabled: enabled, displayName: displayName)
    }
}
