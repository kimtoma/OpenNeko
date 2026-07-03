import Foundation

/// Per-state sprite animation timing. Kept UI-free so the timing table is
/// unit tested; `App/CatScene.swift` feeds these values into SpriteKit.
public enum CatAnimationTiming {
    public static func timePerFrame(for state: CatState) -> TimeInterval {
        switch state {
        case .typing, .click, .success, .jump:
            0.125
        case .walk:
            0.12
        case .nap:
            0.4
        case .thinking:
            0.2
        default:
            0.18
        }
    }

    /// The typing animation speed multiplier, clamped to a range that keeps
    /// the paw animation readable.
    public static func clampedTypingSpeed(_ speed: Double) -> Double {
        min(1.8, max(0.8, speed))
    }
}
