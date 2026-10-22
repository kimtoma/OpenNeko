import Foundation

/// Motion timing stays constant when original poses gain in-between frames.
public enum CatAnimationTiming {
    public static let previewCycleDuration: TimeInterval = 0.48

    public static func cycleDuration(for state: CatState) -> TimeInterval {
        switch state {
        case .typing, .click, .success, .jump:
            0.5
        case .walk:
            0.48
        case .nap:
            1.6
        case .thinking:
            0.8
        default:
            0.72
        }
    }

    public static func frameDuration(for state: CatState, frameCount: Int) -> TimeInterval {
        guard frameCount > 0 else { return 0 }
        // Short legacy animations keep their original per-frame cadence.
        // Added in-betweens divide the established four-pose cycle instead.
        return frameDuration(cycleDuration: cycleDuration(for: state), frameCount: max(4, frameCount))
    }

    public static func frameDuration(cycleDuration: TimeInterval, frameCount: Int) -> TimeInterval {
        guard frameCount > 0, cycleDuration.isFinite, cycleDuration > 0 else { return 0 }
        return cycleDuration / Double(frameCount)
    }

    public static func frameIndex(
        at elapsed: TimeInterval,
        cycleDuration: TimeInterval,
        frameCount: Int
    ) -> Int {
        guard frameCount > 1, elapsed.isFinite, cycleDuration.isFinite, cycleDuration > 0 else { return 0 }
        let remainder = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        let phase = (remainder < 0 ? remainder + cycleDuration : remainder) / cycleDuration
        return min(frameCount - 1, Int(phase * Double(frameCount)))
    }
}
