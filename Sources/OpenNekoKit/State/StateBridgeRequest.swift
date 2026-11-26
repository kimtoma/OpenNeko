import Foundation

public enum StateBridgeRequestError: Error, Equatable {
    case invalidPayload
    case invalidState
}

public struct StateBridgeEvent: Equatable, Sendable {
    public let state: CatState
    public let source: String
    public let message: String?
    /// True when the sender asked for the user's attention (e.g. an agent
    /// waiting for approval), as opposed to plain status updates.
    public let isAttentionRequest: Bool

    public init(state: CatState, source: String, message: String?, isAttentionRequest: Bool = false) {
        self.state = state
        self.source = source
        self.message = message
        self.isAttentionRequest = isAttentionRequest
    }
}

public enum StateBridgeRequest {
    public static let maxBodyBytes = 4096

    public static func parse(_ data: Data) throws -> StateBridgeEvent {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw StateBridgeRequestError.invalidPayload
        }

        guard let rawState = payload.state, let state = mappedState(rawState) else {
            throw StateBridgeRequestError.invalidState
        }

        return StateBridgeEvent(
            state: state,
            source: String((payload.source ?? "agent").prefix(40)),
            message: payload.message.map { String($0.prefix(120)) }.flatMap { $0.isEmpty ? nil : $0 },
            isAttentionRequest: attentionStates.contains(rawState)
        )
    }

    /// Bridge-only aliases that ask for the user's attention. They animate as
    /// `hover` until dedicated sprites exist.
    public static let attentionStates: Set<String> = ["waiting", "needs_input", "attention"]

    /// Bridge-only aliases for "the agent finished".
    public static let doneStates: Set<String> = ["done", "finished", "complete"]

    private static func mappedState(_ rawState: String) -> CatState? {
        if attentionStates.contains(rawState) { return .hover }
        if doneStates.contains(rawState) { return .success }
        switch rawState {
        case "clicked": return .click
        default: return CatState(rawValue: rawState)
        }
    }

    private struct Payload: Decodable {
        let state: String?
        let source: String?
        let message: String?
    }
}
