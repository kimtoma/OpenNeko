import Foundation

public enum ProcessPathEnvironment {
    public static func extraDirectories(
        homeDirectory: String = NSHomeDirectory(),
        platform: String = "darwin"
    ) -> [String] {
        if platform == "win32" {
            return [
                windowsPath(homeDirectory, "AppData", "Roaming", "npm"),
                windowsPath(homeDirectory, "AppData", "Local", "Microsoft", "WindowsApps"),
                windowsPath(homeDirectory, ".local", "bin"),
            ]
        }

        return [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            posixPath(homeDirectory, ".local", "bin"),
            posixPath(homeDirectory, "bin"),
        ]
    }

    public static func augmentPath(
        _ currentPath: String?,
        homeDirectory: String = NSHomeDirectory(),
        platform: String = "darwin"
    ) -> String {
        let separator = platform == "win32" ? ";" : ":"
        let currentEntries = (currentPath ?? "")
            .split(separator: Character(separator))
            .map(String.init)
            .filter { !$0.isEmpty }
        var seen = Set(currentEntries)
        let prepended = extraDirectories(homeDirectory: homeDirectory, platform: platform)
            .filter { seen.insert($0).inserted }
        return (prepended + currentEntries).joined(separator: separator)
    }

    public static func spawnEnvironment(
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory(),
        platform: String = "darwin",
        terminalDefaults: Bool = false
    ) -> [String: String] {
        var environment = baseEnvironment
        environment["PATH"] = augmentPath(
            baseEnvironment["PATH"],
            homeDirectory: homeDirectory,
            platform: platform
        )
        if terminalDefaults {
            environment["NO_COLOR"] = "1"
            environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        }
        return environment
    }

    private static func posixPath(_ homeDirectory: String, _ components: String...) -> String {
        components.reduce(URL(fileURLWithPath: homeDirectory)) { url, component in
            url.appendingPathComponent(component)
        }.path
    }

    private static func windowsPath(_ homeDirectory: String, _ components: String...) -> String {
        ([homeDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "\\/"))] + components)
            .joined(separator: "\\")
    }
}
