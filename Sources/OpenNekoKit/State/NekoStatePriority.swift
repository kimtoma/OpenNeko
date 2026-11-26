import Foundation

public enum NekoStatePriority {
    public static var chatAnsweringState: CatState { .thinking }

    /// States that play once and settle on their own; sticky states instead
    /// get a revert-to-idle timer scheduled by the app.
    public static var oneShotStates: Set<CatState> {
        [.click, .yawn, .success, .error, .jump]
    }

    public static func acceptsBridgeEvent(isChatAnswering: Bool) -> Bool {
        !isChatAnswering
    }

    public static func acceptsAgentCodingState(
        isChatAnswering: Bool,
        currentState: CatState
    ) -> Bool {
        guard !isChatAnswering else { return false }
        return currentState == .idle || currentState == .coding || currentState == .walk
    }

    /// How long a bridge-pushed state stays before the cat drifts back to
    /// idle. Nil means no revert timer (one-shot states and idle itself).
    /// Attention requests stay up much longer so the user does not miss them.
    public static func bridgeRevertDelay(for event: StateBridgeEvent) -> TimeInterval? {
        if event.state == .idle || oneShotStates.contains(event.state) {
            return nil
        }
        return event.isAttentionRequest ? 600 : 90
    }
}
