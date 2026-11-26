import Foundation

public struct CatAutonomousContext: Equatable, Sendable {
    public var uptime: TimeInterval
    public var hour: Int
    public var lastInteraction: TimeInterval
    public var nextAutoEffect: TimeInterval
    public var lunchAlreadyShown: Bool
    public var leaveWorkAlreadyShown: Bool
    public var isAvailable: Bool
    /// A break suggestion that is due now (from `HealthNudgeTracker`).
    public var healthNudge: HealthNudgeKind?

    public init(
        uptime: TimeInterval,
        hour: Int,
        lastInteraction: TimeInterval,
        nextAutoEffect: TimeInterval,
        lunchAlreadyShown: Bool,
        leaveWorkAlreadyShown: Bool,
        isAvailable: Bool,
        healthNudge: HealthNudgeKind? = nil
    ) {
        self.uptime = uptime
        self.hour = hour
        self.lastInteraction = lastInteraction
        self.nextAutoEffect = nextAutoEffect
        self.lunchAlreadyShown = lunchAlreadyShown
        self.leaveWorkAlreadyShown = leaveWorkAlreadyShown
        self.isAvailable = isAvailable
        self.healthNudge = healthNudge
    }
}

public enum CatAutonomousAction: Equatable, Sendable {
    case none
    case healthNudge(HealthNudgeKind)
    case lunch
    case leaveWork
    case nap
    case yawn
    case jump
}

public enum CatAutonomousBehavior {
    public static let napAfter: TimeInterval = 2 * 60
    public static let lunchHour = 12
    public static let leaveWorkHour = 18

    public static func action(
        for context: CatAutonomousContext,
        randomValue: Double
    ) -> CatAutonomousAction {
        guard context.isAvailable else { return .none }

        if let nudge = context.healthNudge {
            return .healthNudge(nudge)
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
