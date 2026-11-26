import Foundation

/// A local MCP server (stdio) the person added as a connector. Only the
/// command, arguments and the *names* of environment variables are stored in
/// settings; the values may be secrets and live in the Keychain.
public struct MCPServerConfig: Codable, Equatable, Identifiable, Sendable {
    public var name: String
    public var command: String
    public var args: [String]
    public var envKeys: [String]
    public var enabled: Bool
    public var source: String

    public var id: String { name }

    public static let maxServers = 12

    public init(name: String, command: String, args: [String] = [], envKeys: [String] = [], enabled: Bool = true, source: String = "") {
        self.name = name
        self.command = command
        self.args = args
        self.envKeys = envKeys
        self.enabled = enabled
        self.source = source
    }

    /// Server names are used in prompts and tool calls, so keep them to a
    /// small safe alphabet.
    public static func isValidName(_ name: String) -> Bool {
        guard (1...64).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII || "-_.".unicodeScalars.contains(scalar)
        }
    }

    public func normalized() -> MCPServerConfig {
        var copy = self
        copy.command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.args = Array(args.prefix(32)).map { String($0.prefix(1_000)) }
        copy.envKeys = Array(Set(envKeys.filter { !$0.isEmpty && $0.count <= 128 })).sorted()
        copy.source = String(source.prefix(64))
        return copy
    }

    /// One line for settings and the import confirmation.
    public var commandLine: String {
        ([command] + args).joined(separator: " ")
    }
}

/// A server found in another app's MCP config, before the person accepts it.
public struct ImportedMCPServer: Equatable, Sendable {
    public var config: MCPServerConfig
    public var env: [String: String]

    public init(config: MCPServerConfig, env: [String: String]) {
        self.config = config
        self.env = env
    }
}

/// Reads the common `{"mcpServers": {...}}` format used by Claude Desktop
/// and project `.mcp.json` files. Read only: the source file is never
/// changed. Remote (URL) servers are skipped for now and counted.
public enum MCPConfigImport {
    public struct Result: Equatable, Sendable {
        public var servers: [ImportedMCPServer]
        public var skippedRemote: [String]
        public var skippedInvalid: [String]
    }

    /// Claude Desktop's config, relative to the home folder.
    public static let claudeDesktopRelativePath = "Library/Application Support/Claude/claude_desktop_config.json"

    public static func parse(_ data: Data, source: String) -> Result? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let servers = root["mcpServers"] as? [String: Any]
        else { return nil }
        var result = Result(servers: [], skippedRemote: [], skippedInvalid: [])
        for name in servers.keys.sorted() {
            guard let entry = servers[name] as? [String: Any] else {
                result.skippedInvalid.append(name)
                continue
            }
            if entry["url"] != nil || ["http", "sse", "streamable-http"].contains((entry["type"] as? String)?.lowercased() ?? "") {
                result.skippedRemote.append(name)
                continue
            }
            guard
                MCPServerConfig.isValidName(name),
                let command = (entry["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !command.isEmpty
            else {
                result.skippedInvalid.append(name)
                continue
            }
            let args = (entry["args"] as? [Any] ?? []).compactMap { $0 as? String }
            var env: [String: String] = [:]
            for (key, value) in entry["env"] as? [String: Any] ?? [:] {
                if let string = value as? String { env[key] = string }
            }
            let config = MCPServerConfig(
                name: name,
                command: command,
                args: args,
                envKeys: Array(env.keys),
                enabled: true,
                source: source
            ).normalized()
            result.servers.append(ImportedMCPServer(config: config, env: env))
        }
        return result
    }

    /// Adds imported servers, replacing ones with the same name, up to
    /// `MCPServerConfig.maxServers`.
    public static func merged(_ existing: [MCPServerConfig], adding imported: [MCPServerConfig]) -> [MCPServerConfig] {
        var result = existing.filter { old in !imported.contains { $0.name == old.name } }
        result.append(contentsOf: imported)
        return Array(result.prefix(MCPServerConfig.maxServers))
    }
}
