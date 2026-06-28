import Foundation

public struct CatAutonomousContext: Equatable, Sendable {
    public var uptime: TimeInterval
    public var hour: Int
    public var lastInteraction: TimeInterval
    public var lastStretch: TimeInterval
    public var nextAutoEffect: TimeInterval
    public var lunchAlreadyShown: Bool
    public var leaveWorkAlreadyShown: Bool
    public var isAvailable: Bool

    public init(
        uptime: TimeInterval,
        hour: Int,
        lastInteraction: TimeInterval,
        lastStretch: TimeInterval,
        nextAutoEffect: TimeInterval,
        lunchAlreadyShown: Bool,
        leaveWorkAlreadyShown: Bool,
        isAvailable: Bool
    ) {
        self.uptime = uptime
        self.hour = hour
        self.lastInteraction = lastInteraction
        self.lastStretch = lastStretch
        self.nextAutoEffect = nextAutoEffect
        self.lunchAlreadyShown = lunchAlreadyShown
        self.leaveWorkAlreadyShown = leaveWorkAlreadyShown
        self.isAvailable = isAvailable
    }
}

public enum CatAutonomousAction: Equatable, Sendable {
    case none
    case stretch
    case lunch
    case leaveWork
    case nap
    case yawn
    case jump
}

public enum CatAutonomousBehavior {
    public static let stretchInterval: TimeInterval = 50 * 60
    public static let napAfter: TimeInterval = 2 * 60
    public static let lunchHour = 12
    public static let leaveWorkHour = 18

    public static func action(
        for context: CatAutonomousContext,
        randomValue: Double
    ) -> CatAutonomousAction {
        guard context.isAvailable else { return .none }

        if context.uptime - context.lastStretch > stretchInterval {
            return .stretch
        }
        if context.hour == lunchHour, !context.lunchAlreadyShown {
            return .lunch
        }
        if context.hour == leaveWorkHour, !context.leaveWorkAlreadyShown {
            return .leaveWork
        }
        if context.uptime - context.lastInteraction > napAfter {
            return .nap
        }
        if context.uptime > context.nextAutoEffect {
            return randomValue < 0.5 ? .yawn : .jump
        }

        return .none
    }
}
