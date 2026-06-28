import Foundation

public enum StateBridgeRequestError: Error, Equatable {
    case invalidPayload
    case invalidState
}

public struct StateBridgeEvent: Equatable, Sendable {
    public let state: CatState
    public let source: String
    public let message: String?

    public init(state: CatState, source: String, message: String?) {
        self.state = state
        self.source = source
        self.message = message
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
            message: payload.message.map { String($0.prefix(120)) }.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private static func mappedState(_ rawState: String) -> CatState? {
        switch rawState {
        case "waiting": .hover
        case "clicked": .click
        default: CatState(rawValue: rawState)
        }
    }

    private struct Payload: Decodable {
        let state: String?
        let source: String?
        let message: String?
    }
}
