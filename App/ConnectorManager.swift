import Foundation
import OpenNekoKit

/// One local MCP server, spoken to over stdio (one JSON-RPC message per
/// line). All state is touched on the main queue.
final class MCPClient {
    enum State: Equatable {
        case stopped
        case starting
        case ready
        case failed
    }

    enum CallError: Error {
        case notReady
        case timedOut
        case server(String)
    }

    let config: MCPServerConfig
    private(set) var state: State = .stopped
    private(set) var tools: [MCPTool] = []
    var onChange: (() -> Void)?

    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: (MCPProtocol.Reply?) -> Void] = [:]

    init(config: MCPServerConfig) {
        self.config = config
    }

    func start(env: [String: String]) {
        guard state == .stopped || state == .failed else { return }
        // A server that exits while we write must not take the app down.
        signal(SIGPIPE, SIG_IGN)
        setState(.starting)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [config.command] + config.args
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = Self.searchPath(environment["PATH"])
        for (key, value) in env where config.envKeys.contains(key) {
            environment[key] = value
        }
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async {
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    self?.receive(data)
                }
            }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.didTerminate() }
        }

        do {
            try process.run()
        } catch {
            setState(.failed)
            return
        }
        self.process = process
        input = stdinPipe.fileHandleForWriting

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        send({ MCPProtocol.initialize(id: $0, clientVersion: version) }, timeout: 30) { [weak self] reply in
            guard let self else { return }
            guard case .result = reply else {
                self.stop(failed: true)
                return
            }
            self.write(MCPProtocol.initialized())
            self.send({ MCPProtocol.listTools(id: $0) }, timeout: 30) { [weak self] reply in
                guard let self else { return }
                guard case let .result(_, json) = reply else {
                    self.stop(failed: true)
                    return
                }
                self.tools = MCPProtocol.tools(fromListResult: json, server: self.config.name)
                self.setState(.ready)
            }
        }
    }

    func stop(failed: Bool = false) {
        let process = self.process
        self.process = nil
        input = nil
        process?.terminationHandler = nil
        (process?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        let waiting = pending
        pending = [:]
        waiting.values.forEach { $0(nil) }
        tools = []
        buffer = Data()
        setState(failed ? .failed : .stopped)
    }

    func call(tool: String, argumentsJSON: String, completion: @escaping (Result<(text: String, isError: Bool), CallError>) -> Void) {
        guard state == .ready else {
            completion(.failure(.notReady))
            return
        }
        send({ MCPProtocol.callTool(id: $0, name: tool, argumentsJSON: argumentsJSON) }, timeout: 60) { reply in
            switch reply {
            case let .result(_, json)?:
                completion(.success(MCPProtocol.text(fromCallResult: json)))
            case let .error(_, message)?:
                completion(.failure(.server(message)))
            default:
                completion(.failure(.timedOut))
            }
        }
    }

    private func send(_ make: (Int) -> Data, timeout: TimeInterval, completion: @escaping (MCPProtocol.Reply?) -> Void) {
        let id = nextID
        nextID += 1
        pending[id] = completion
        write(make(id))
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.pending.removeValue(forKey: id)?(nil)
        }
    }

    private func write(_ data: Data) {
        guard let input else { return }
        do {
            try input.write(contentsOf: data)
        } catch {
            stop(failed: true)
        }
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty, let reply = MCPProtocol.parseLine(Data(line)) else { continue }
            switch reply {
            case let .result(id, _), let .error(id, _):
                pending.removeValue(forKey: id)?(reply)
            case .other:
                break
            }
        }
        // A server that never sends a newline should not grow memory forever.
        if buffer.count > 4_000_000 {
            buffer = Data()
        }
    }

    private func didTerminate() {
        guard process != nil else { return }
        stop(failed: state != .stopped)
    }

    private func setState(_ newState: State) {
        guard state != newState else { return }
        state = newState
        onChange?()
    }

    /// GUI apps start with a short PATH; MCP servers are usually launched
    /// with npx, uvx or docker from Homebrew or the user's local bin.
    static func searchPath(_ current: String?) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.cargo/bin", "\(home)/.bun/bin"]
        var parts = (current ?? "/usr/bin:/bin:/usr/sbin:/sbin").split(separator: ":").map(String.init)
        for path in extra where !parts.contains(path) {
            parts.append(path)
        }
        return parts.joined(separator: ":")
    }
}

/// Keeps one `MCPClient` per enabled connector and offers their tools to
/// chat. Env values for each server are read from the Keychain.
final class ConnectorManager {
    private var clients: [String: MCPClient] = [:]
    private var order: [String] = []
    private let keyStore = APIKeyStore()
    var onChange: (() -> Void)?

    /// Starts enabled servers, stops removed or disabled ones, and restarts
    /// a server whose command changed.
    func sync(_ configs: [MCPServerConfig]) {
        order = configs.map(\.name)
        let wanted = Dictionary(uniqueKeysWithValues: configs.filter(\.enabled).map { ($0.name, $0) })
        for (name, client) in clients where wanted[name] != client.config {
            client.stop()
            clients[name] = nil
        }
        for (name, config) in wanted where clients[name] == nil {
            let client = MCPClient(config: config)
            client.onChange = { [weak self] in self?.onChange?() }
            clients[name] = client
            client.start(env: env(for: name))
        }
        onChange?()
    }

    func stopAll() {
        clients.values.forEach { $0.stop() }
        clients = [:]
    }

    /// Tools from ready servers, in the order the person listed them.
    var tools: [MCPTool] {
        order.compactMap { clients[$0] }.filter { $0.state == .ready }.flatMap(\.tools)
    }

    func state(of name: String) -> MCPClient.State {
        clients[name]?.state ?? .stopped
    }

    func toolCount(of name: String) -> Int {
        clients[name]?.tools.count ?? 0
    }

    func call(
        server: String,
        tool: String,
        argumentsJSON: String,
        completion: @escaping (Result<(text: String, isError: Bool), MCPClient.CallError>) -> Void
    ) {
        guard let client = clients[server] else {
            completion(.failure(.notReady))
            return
        }
        client.call(tool: tool, argumentsJSON: argumentsJSON, completion: completion)
    }

    // MARK: - Env values (Keychain)

    func saveEnv(_ env: [String: String], for name: String) {
        let account = Self.account(name)
        guard !env.isEmpty, let data = try? JSONSerialization.data(withJSONObject: env), let json = String(data: data, encoding: .utf8) else {
            try? keyStore.delete(for: account)
            return
        }
        try? keyStore.save(json, for: account)
    }

    func deleteEnv(for name: String) {
        try? keyStore.delete(for: Self.account(name))
    }

    private func env(for name: String) -> [String: String] {
        guard
            let json = keyStore.apiKey(for: Self.account(name)),
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return object
    }

    private static func account(_ name: String) -> String {
        "mcp-env:\(name)"
    }
}
