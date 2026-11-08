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
}
