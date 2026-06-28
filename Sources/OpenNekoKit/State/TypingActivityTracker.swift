import Foundation

public struct TypingActivityTracker: Equatable {
    public let idleDelay: TimeInterval
    public private(set) var isTyping: Bool
    public private(set) var animationSpeed: Double
    private var typingUntil: TimeInterval
    private var previousKeyDownTime: TimeInterval?

    public init(idleDelay: TimeInterval) {
        self.idleDelay = max(0, idleDelay)
        self.isTyping = false
        self.animationSpeed = 1.0
        self.typingUntil = 0
        self.previousKeyDownTime = nil
    }

    @discardableResult
    public mutating func keyDown(at time: TimeInterval) -> Bool {
        let changed = !isTyping
        updateAnimationSpeed(at: time)
        isTyping = true
        typingUntil = time + idleDelay
        previousKeyDownTime = time
        return changed
    }

    @discardableResult
    public mutating func tick(at time: TimeInterval) -> Bool {
        guard isTyping, time >= typingUntil else { return false }
        isTyping = false
        animationSpeed = 1.0
        previousKeyDownTime = nil
        return true
    }

    public func nextIdleCheckDelay(at time: TimeInterval) -> TimeInterval {
        guard isTyping else { return 0 }
        return max(0, typingUntil - time)
    }

    private mutating func updateAnimationSpeed(at time: TimeInterval) {
        guard let previousKeyDownTime, time > previousKeyDownTime else {
            animationSpeed = 1.0
            return
        }

        let interval = time - previousKeyDownTime
        guard interval <= max(0.05, idleDelay) else {
            animationSpeed = 1.0
            return
        }

        let target = Self.animationSpeed(forKeyInterval: interval)
        let blend = target > animationSpeed ? 0.7 : 0.45
        animationSpeed += (target - animationSpeed) * blend
        animationSpeed = min(Self.maximumAnimationSpeed, max(Self.minimumAnimationSpeed, animationSpeed))
    }

    private static let minimumAnimationSpeed = 0.8
    private static let maximumAnimationSpeed = 1.8

    private static func animationSpeed(forKeyInterval interval: TimeInterval) -> Double {
        let keysPerSecond = 1.0 / max(0.08, interval)
        let normalized = (keysPerSecond - 1.5) / (8.0 - 1.5)
        let clamped = min(1.0, max(0.0, normalized))
        return minimumAnimationSpeed + clamped * (maximumAnimationSpeed - minimumAnimationSpeed)
    }
}
