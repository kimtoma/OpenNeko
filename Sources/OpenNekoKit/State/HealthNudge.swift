import Foundation

public enum HealthNudgeKind: String, CaseIterable, Equatable, Sendable {
    case stretch
    case eyes
    case water

    /// Animation the cat plays alongside the bubble.
    public var catState: CatState {
        switch self {
        case .stretch: .yawn
        case .eyes: .hover
        case .water: .lunch
        }
    }
}

public struct HealthNudgePolicy: Equatable, Sendable {
    /// Continuous work before the first nudge of a session.
    public var workSession: TimeInterval
    /// A typing gap at least this long counts as a real break and restarts the session.
    public var breakResetsAfter: TimeInterval
    /// Only nudge while the person is actually at the keyboard.
    public var stillWorkingWithin: TimeInterval
    /// Never nudge more often than this.
    public var minimumGap: TimeInterval
    /// Hard cap per calendar day.
    public var dailyLimit: Int

    public init(
        workSession: TimeInterval,
        breakResetsAfter: TimeInterval,
        stillWorkingWithin: TimeInterval,
        minimumGap: TimeInterval,
        dailyLimit: Int
    ) {
        self.workSession = workSession
        self.breakResetsAfter = breakResetsAfter
        self.stillWorkingWithin = stillWorkingWithin
        self.minimumGap = minimumGap
        self.dailyLimit = dailyLimit
    }

    public static let standard = HealthNudgePolicy(
        workSession: 50 * 60,
        breakResetsAfter: 5 * 60,
        stillWorkingWithin: 2 * 60,
        minimumGap: 45 * 60,
        dailyLimit: 6
    )
}

/// Decides when the cat suggests a break, from keydown timestamps only
/// (never key contents). Times are wall-clock seconds so Mac sleep counts as
/// a break.
public struct HealthNudgeTracker: Equatable, Sendable {
    public let policy: HealthNudgePolicy
    public private(set) var sessionStart: TimeInterval?
    public private(set) var lastActivity: TimeInterval?
    public private(set) var lastNudge: TimeInterval?
    public private(set) var nudgesToday = 0
    private var day: Int?
    private var nextKindIndex = 0

    public init(policy: HealthNudgePolicy = .standard) {
        self.policy = policy
    }

    public mutating func recordActivity(at time: TimeInterval) {
        if let lastActivity, time - lastActivity >= policy.breakResetsAfter {
            sessionStart = time
        } else if sessionStart == nil {
            sessionStart = time
        }
        lastActivity = time
    }

    /// Returns the nudge to show now, if any, and records it.
    /// `day` is any value that changes once per calendar day.
    public mutating func nextNudge(at now: TimeInterval, day: Int, enabled: Bool) -> HealthNudgeKind? {
        if self.day != day {
            self.day = day
            nudgesToday = 0
        }
        guard
            enabled,
            let sessionStart,
            let lastActivity,
            now - lastActivity <= policy.stillWorkingWithin,
            now - sessionStart >= policy.workSession,
            nudgesToday < policy.dailyLimit
        else {
            return nil
        }
        if let lastNudge, now - lastNudge < policy.minimumGap {
            return nil
        }

        let kinds = HealthNudgeKind.allCases
        let kind = kinds[nextKindIndex % kinds.count]
        nextKindIndex += 1
        nudgesToday += 1
        lastNudge = now
        self.sessionStart = now
        return kind
    }
}
