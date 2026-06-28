import Foundation
import Network
import OpenNekoKit

final class StateBridgeServer {
    private let port: UInt16
    private let currentState: () -> CatState
    private let keyDownCount: () -> Int
    private let currentPositionJSON: () -> String?
    private let capturePNG: () -> Data?
    private let settingsJSON: () -> String?
    private let agentProcessJSON: () -> String?
    private let debugDragAndDrop: () -> String?
    private let debugTyping: () -> String?
    private let typingStatusJSON: () -> String?
    private let debugSettingsApply: (Data) -> String?
    private let onEvent: (StateBridgeEvent) -> Void
    private let queue = DispatchQueue(label: "openneko.state-bridge")
    private var listener: NWListener?

    init(
        port: UInt16 = StateBridgeServer.defaultPort(),
        currentState: @escaping () -> CatState,
        keyDownCount: @escaping () -> Int = { 0 },
        currentPositionJSON: @escaping () -> String? = { nil },
        capturePNG: @escaping () -> Data? = { nil },
        settingsJSON: @escaping () -> String? = { nil },
        agentProcessJSON: @escaping () -> String? = { nil },
        debugDragAndDrop: @escaping () -> String? = { nil },
        debugTyping: @escaping () -> String? = { nil },
        typingStatusJSON: @escaping () -> String? = { nil },
        debugSettingsApply: @escaping (Data) -> String? = { _ in nil },
        onEvent: @escaping (StateBridgeEvent) -> Void
    ) {
        self.port = port
        self.currentState = currentState
        self.keyDownCount = keyDownCount
        self.currentPositionJSON = currentPositionJSON
        self.capturePNG = capturePNG
        self.settingsJSON = settingsJSON
        self.agentProcessJSON = agentProcessJSON
        self.debugDragAndDrop = debugDragAndDrop
        self.debugTyping = debugTyping
        self.typingStatusJSON = typingStatusJSON
        self.debugSettingsApply = debugSettingsApply
        self.onEvent = onEvent
    }

    func start() {
        guard listener == nil else { return }
        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(
                host: .ipv4(IPv4Address("127.0.0.1")!),
                port: nwPort
            )
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                if case let .failed(error) = state {
                    NSLog("[openNeko] state bridge failed: \(error)")
                }
            }
            self.listener = listener
            listener.start(queue: queue)
            NSLog("[openNeko] state bridge listening on 127.0.0.1:\(port)")
        } catch {
            NSLog("[openNeko] failed to start state bridge: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    static func defaultPort(environment: [String: String] = ProcessInfo.processInfo.environment) -> UInt16 {
        guard
            let raw = environment["OPENNEKO_PORT"],
            let port = UInt16(raw)
        else {
            return 48800
        }
        return port
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(from: connection, accumulated: Data())
    }

    private func receive(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            guard error == nil else {
                connection.cancel()
                return
            }

            var data = accumulated
            if let content {
                data.append(content)
            }

            if let response = makeResponse(for: data) {
                send(response, on: connection)
                return
            }

            if isComplete || data.count > StateBridgeRequest.maxBodyBytes + 4096 {
                send(.badRequest, on: connection)
                return
            }

            receive(from: connection, accumulated: data)
        }
    }

    private func makeResponse(for data: Data) -> HTTPResponse? {
        guard let request = HTTPRequest(data: data) else { return nil }
        switch (request.method, request.path) {
        case ("POST", "/state"):
            do {
                let event = try StateBridgeRequest.parse(request.body)
                if Thread.isMainThread {
                    onEvent(event)
                } else {
                    DispatchQueue.main.sync { [onEvent] in onEvent(event) }
                }
                return .ok("ok")
            } catch {
                return .badRequest
            }
        case ("GET", "/health"):
            return .ok("openneko")
        case ("GET", "/anim"):
            let payload = #"{"anim":"\#(currentState().rawValue)","keydownCount":\#(keyDownCount())}"#
            return .json(payload)
        case ("GET", "/pos"), ("GET", "/debug/position"):
            guard let payload = currentPositionJSON() else { return .json("{}") }
            return .json(payload)
        case ("GET", "/capture"):
            guard let data = capturePNG() else { return .serviceUnavailable }
            return .png(data)
        case ("GET", "/debug/settings"):
            let payload: String?
            if Thread.isMainThread {
                payload = settingsJSON()
            } else {
                payload = DispatchQueue.main.sync(execute: settingsJSON)
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        case ("POST", "/debug/settings/apply"):
            let payload: String?
            if Thread.isMainThread {
                payload = debugSettingsApply(request.body)
            } else {
                payload = DispatchQueue.main.sync { debugSettingsApply(request.body) }
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        case ("GET", "/debug/agent"):
            let payload: String?
            if Thread.isMainThread {
                payload = agentProcessJSON()
            } else {
                payload = DispatchQueue.main.sync(execute: agentProcessJSON)
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        case ("POST", "/debug/drag"):
            let payload: String?
            if Thread.isMainThread {
                payload = debugDragAndDrop()
            } else {
                payload = DispatchQueue.main.sync(execute: debugDragAndDrop)
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        case ("GET", "/debug/typing"):
            let payload: String?
            if Thread.isMainThread {
                payload = typingStatusJSON()
            } else {
                payload = DispatchQueue.main.sync(execute: typingStatusJSON)
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        case ("POST", "/debug/typing"):
            let payload: String?
            if Thread.isMainThread {
                payload = debugTyping()
            } else {
                payload = DispatchQueue.main.sync(execute: debugTyping)
            }
            guard let payload else { return .serviceUnavailable }
            return .json(payload)
        default:
            return .notFound
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    init?(data: Data) {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else { return nil }
        guard let header = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else { return nil }
        let lines = header.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard contentLength <= StateBridgeRequest.maxBodyBytes else { return nil }
        let bodyStart = headerRange.upperBound
        guard data.count - bodyStart >= contentLength else { return nil }

        method = String(parts[0])
        path = String(parts[1])
        body = Data(data[bodyStart..<bodyStart + contentLength])
    }
}

private struct HTTPResponse {
    let status: String
    let contentType: String
    let body: Data

    static func ok(_ body: String) -> HTTPResponse {
        HTTPResponse(status: "200 OK", contentType: "text/plain", body: Data(body.utf8))
    }

    static func json(_ body: String) -> HTTPResponse {
        HTTPResponse(status: "200 OK", contentType: "application/json", body: Data(body.utf8))
    }

    static func png(_ body: Data) -> HTTPResponse {
        HTTPResponse(status: "200 OK", contentType: "image/png", body: body)
    }

    static let badRequest = HTTPResponse(status: "400 Bad Request", contentType: "text/plain", body: Data("bad request".utf8))
    static let notFound = HTTPResponse(status: "404 Not Found", contentType: "text/plain", body: Data())
    static let serviceUnavailable = HTTPResponse(status: "503 Service Unavailable", contentType: "text/plain", body: Data())

    var data: Data {
        var header = ""
        header += "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"
        return Data(header.utf8) + body
    }
}
