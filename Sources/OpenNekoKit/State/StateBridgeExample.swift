public enum StateBridgeExample {
    public static func endpoint(port: UInt16) -> String {
        "http://127.0.0.1:\(port)"
    }

    public static func stateURL(port: UInt16) -> String {
        "\(endpoint(port: port))/state"
    }

    public static func curlCommand(port: UInt16) -> String {
        """
        curl -X POST \(stateURL(port: port)) \\
          -H 'Content-Type: application/json' \\
          -d '{"state":"coding","source":"manual","message":"Working"}'
        """
    }

    public static let commonStates: [CatState] = [
        .idle,
        .typing,
        .coding,
        .thinking,
        .success,
        .error,
    ]

    public static var commonStateLabels: String {
        commonStates.map(\.rawValue).joined(separator: ", ")
    }

    public static let debugEndpointLabels = "/health, /anim, /pos, /debug/position, /capture, /debug/settings, /debug/settings/apply, /debug/agent, /debug/drag, /debug/typing"
}
