import Foundation

public struct TypingPulseDetector: Equatable {
    public let activeWindow: TimeInterval
    public let minimumPulseInterval: TimeInterval
    private var previousKeyDownAge: TimeInterval?
    private var lastPulseTime: TimeInterval

    public init(
        activeWindow: TimeInterval = 0.16,
        minimumPulseInterval: TimeInterval = 0.035
    ) {
        self.activeWindow = max(0.01, activeWindow)
        self.minimumPulseInterval = max(0, minimumPulseInterval)
        self.previousKeyDownAge = nil
        self.lastPulseTime = -.infinity
    }

    public mutating func prime(keyDownAge: TimeInterval) {
        previousKeyDownAge = keyDownAge.isFinite ? max(0, keyDownAge) : nil
    }

    public mutating func sample(keyDownAge rawAge: TimeInterval, at time: TimeInterval) -> Bool {
        guard rawAge.isFinite else {
            previousKeyDownAge = nil
            return false
        }

        let age = max(0, rawAge)
        defer { previousKeyDownAge = age }
        guard age <= activeWindow else { return false }

        let isNewPulse: Bool
        if let previousKeyDownAge {
            isNewPulse = age + 0.015 < previousKeyDownAge || previousKeyDownAge > activeWindow
        } else {
            isNewPulse = age <= 0.04
        }
        guard isNewPulse, time - lastPulseTime >= minimumPulseInterval else {
            return false
        }

        lastPulseTime = time
        return true
    }
}
