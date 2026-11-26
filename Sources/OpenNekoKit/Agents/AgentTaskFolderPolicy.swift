import Foundation

public enum AgentTaskFolderRejection: Equatable, Sendable {
    case notAbsolute
    case filesystemRoot
    case homeDirectory
    case systemLocation
}

/// Decides whether a folder the user picked may be handed to a CLI agent
/// with tools enabled. Whole-disk, home and system folders are refused so a
/// delegated task stays scoped to one project.
public enum AgentTaskFolderPolicy {
    static let systemPrefixes = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/etc", "/var",
        "/private", "/Applications", "/opt", "/cores", "/dev",
    ]

    public static func validate(
        _ path: String,
        homeDirectory: String
    ) -> Result<String, AgentTaskFolderRejectionError> {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .failure(.init(.notAbsolute))
        }
        let normalized = normalize(trimmed)
        let home = normalize(homeDirectory)

        if normalized == "/" {
            return .failure(.init(.filesystemRoot))
        }
        if normalized == home || normalized == "/Users" {
            return .failure(.init(.homeDirectory))
        }
        // A folder inside the user's home is fine even if home itself lives
        // under a "system" prefix on unusual setups.
        if !normalized.hasPrefix(home + "/") {
            for prefix in systemPrefixes where normalized == prefix || normalized.hasPrefix(prefix + "/") {
                return .failure(.init(.systemLocation))
            }
        }
        return .success(normalized)
    }

    static func normalize(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        if standardized.count > 1, standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized.isEmpty ? "/" : standardized
    }
}

public struct AgentTaskFolderRejectionError: Error, Equatable, Sendable {
    public let reason: AgentTaskFolderRejection
    public init(_ reason: AgentTaskFolderRejection) {
        self.reason = reason
    }
}
