import Foundation

/// The folders to check for a `.git` checkout, from the app bundle up to
/// the filesystem root. Works on plain path strings so it always ends:
/// walking a bundle URL with `deletingLastPathComponent()` can go past "/"
/// to "/..", "/../.." forever.
public enum RepositoryRootSearch {
    public static let maxDepth = 64

    public static func candidates(startingAt path: String) -> [String] {
        guard path.hasPrefix("/") else { return [] }
        var components: [String] = []
        for part in path.split(separator: "/") {
            switch part {
            case ".": continue
            case "..": if !components.isEmpty { components.removeLast() }
            default: components.append(String(part))
            }
        }
        var result: [String] = []
        while result.count < maxDepth {
            result.append("/" + components.joined(separator: "/"))
            if components.isEmpty { break }
            components.removeLast()
        }
        return result
    }
}
