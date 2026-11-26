import Foundation

/// Every kind of thing the cat says without being asked. All of them go
/// through `ProactiveGate`, so the cat follows one set of rules about when
/// to speak instead of each feature deciding on its own.
public enum ProactiveKind: String, CaseIterable, Codable, Sendable {
    /// Claude Code / Codex hook or a delegated task reporting back.
    case agentNotice
    /// A routine the user scheduled.
    case routine
    /// The "what's new" tour after an update.
    case whatsNew
    /// Break / stretch / water reminders.
    case healthBreak
    /// Lunch and end-of-day lines.
    case dailyRitual
    /// "Remember this?" and "noted" bubbles after a chat.
    case memorySuggestion
    /// Neighbor cats coming and going.
    case neighbor

    public var priority: ProactivePriority {
        switch self {
        case .agentNotice: .requested
        case .routine, .whatsNew: .scheduled
        case .healthBreak, .dailyRitual, .memorySuggestion, .neighbor: .suggestion
        }
    }

    /// Kinds the user can switch off with "stop" (requested and scheduled
    /// messages are controlled where the user set them up).
    public var isMutable: Bool { priority == .suggestion }
}

public enum ProactivePriority: Int, Comparable, Sendable {
    case suggestion = 0
    case scheduled = 1
    case requested = 2

    public static func < (lhs: ProactivePriority, rhs: ProactivePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// How often the cat may start talking on its own.
public enum Chattiness: String, CaseIterable, Codable, Sendable {
    case quiet
    case normal
    case chatty

    /// Suggestions per day. Requested and scheduled messages don't count.
    public var dailyBudget: Int {
        switch self {
        case .quiet: 3
        case .normal: 8
        case .chatty: 15
        }
    }
}

/// Why now is a bad time to talk.
public enum QuietReason: String, Equatable, Sendable {
    case meeting
    case presenting
    case watching
}

public enum ProactiveDecision: Equatable, Sendable {
    case speak
    /// Not now; a scheduled message should try again later.
    case hold(QuietReason)
    /// Skip it entirely.
    case drop(DropReason)

    public enum DropReason: Equatable, Sendable {
        case muted
        case budget
        case quiet(QuietReason)
    }

    public var shouldSpeak: Bool { self == .speak }
}

/// Today's count of suggestions, kept per calendar day.
public struct ProactiveLedger: Equatable, Sendable {
    public private(set) var day: String
    public private(set) var spent: Int

    public init(day: String = "", spent: Int = 0) {
        self.day = day
        self.spent = spent
    }

    public func spent(on day: String) -> Int {
        self.day == day ? spent : 0
    }

    public mutating func record(_ kind: ProactiveKind, day: String) {
        guard kind.priority == .suggestion else { return }
        if self.day != day {
            self.day = day
            spent = 0
        }
        spent += 1
    }
}

public enum ProactiveGate {
    public static func decide(
        _ kind: ProactiveKind,
        day: String,
        ledger: ProactiveLedger,
        chattiness: Chattiness,
        muted: Set<ProactiveKind>,
        quiet: QuietReason?
    ) -> ProactiveDecision {
        switch kind.priority {
        case .requested:
            return .speak
        case .scheduled:
            if let quiet { return .hold(quiet) }
            return .speak
        case .suggestion:
            if muted.contains(kind) { return .drop(.muted) }
            if let quiet { return .drop(.quiet(quiet)) }
            if ledger.spent(on: day) >= chattiness.dailyBudget { return .drop(.budget) }
            return .speak
        }
    }
}

/// Works out from what is on screen whether the cat should keep quiet.
/// Uses only the frontmost app's bundle id and whether its window fills the
/// screen: no window titles, no screen contents.
public enum QuietContext {
    public static let meetingApps: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.cisco.webexmeetingsapp",
        "Cisco-Systems.Spark",
        "com.webex.meetingmanager",
    ]

    public static let presentationApps: Set<String> = [
        "com.apple.iWork.Keynote",
        "com.microsoft.Powerpoint",
    ]

    public static let videoApps: Set<String> = [
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        "org.videolan.vlc",
        "com.colliderli.iina",
    ]

    public static func reason(frontmostBundleID: String?, frontWindowFillsScreen: Bool) -> QuietReason? {
        guard let id = frontmostBundleID else { return nil }
        if meetingApps.contains(id) { return .meeting }
        guard frontWindowFillsScreen else { return nil }
        if presentationApps.contains(id) { return .presenting }
        if videoApps.contains(id) { return .watching }
        return nil
    }
}

/// "Stop" said right after a suggestion switches that kind off.
public enum ProactiveMute {
    /// How long after a suggestion a "stop" still refers to it.
    public static let replyWindow: TimeInterval = 120

    private static let phrases: [String] = [
        // ko
        "그만", "그만해", "그만해줘", "이제그만", "그얘기그만", "그런말그만", "말하지마", "그만말해", "조용히해", "알려주지마",
        // en
        "stop", "stopit", "stopthat", "nomore", "dontremindme", "shutup", "bequiet", "quiet",
        // ja
        "やめて", "もういい", "静かに", "うるさい", "言わないで",
        // zh
        "别说了", "停", "不要提醒", "安静",
    ]

    /// True only for a short message that is a stop phrase (optionally with
    /// a polite ending), so ordinary chat is never swallowed.
    public static func isStopRequest(_ text: String) -> Bool {
        let compact = text.lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        guard !compact.isEmpty, compact.count <= 12 else { return false }
        let trimmed = trimmingPoliteEnding(compact)
        return phrases.contains(compact) || phrases.contains(trimmed)
    }

    /// The kind a stop request refers to, or nil when there was no recent
    /// mutable suggestion.
    public static func target(
        lastSuggestion: ProactiveKind?,
        shownAt: TimeInterval?,
        now: TimeInterval
    ) -> ProactiveKind? {
        guard let kind = lastSuggestion, kind.isMutable, let shownAt, now - shownAt <= replyWindow, now >= shownAt else {
            return nil
        }
        return kind
    }

    static func trimmingPoliteEnding(_ text: String) -> String {
        for ending in ["please", "냥", "요", "줘", "ください", "吧"] where text.hasSuffix(ending) && text.count > ending.count {
            return String(text.dropLast(ending.count))
        }
        return text
    }
}
