import Foundation

/// Keeps slow behavior decisions independent of the cat's animation clock.
public struct CatAutonomousDecisionCadence: Sendable {
    public static let interval: TimeInterval = 0.25
    private var nextDecisionAt = -TimeInterval.infinity

    public init() {}

    public mutating func shouldEvaluate(at now: TimeInterval) -> Bool {
        guard now >= nextDecisionAt else { return false }
        // Do not replay missed decisions after a busy run loop or system sleep.
        nextDecisionAt = now + Self.interval
        return true
    }
}
