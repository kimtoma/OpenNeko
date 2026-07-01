public enum NekoStatePriority {
    public static var chatAnsweringState: CatState { .thinking }

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
