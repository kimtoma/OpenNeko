import Foundation
import OpenNekoKit

struct GitUpdateCheckResult: Equatable {
    let decision: AppUpdateDecision
    let branch: String
    let repositoryRoot: URL?
}

enum GitUpdateControllerError: Error {
    case noRepository
    case commandFailed(command: String, output: String)
}

final class GitUpdateController {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let bundleURL: URL

    init(
        bundleURL: URL = Bundle.main.bundleURL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.bundleURL = bundleURL
        self.environment = environment
        self.fileManager = fileManager
    }

    func check() throws -> GitUpdateCheckResult {
        guard let root = repositoryRoot() else {
            return GitUpdateCheckResult(
                decision: AppUpdateDecision.decide(isGit: false, behind: 0, dirty: false),
                branch: "main",
                repositoryRoot: nil
            )
        }

        let branchOutput = try git(["rev-parse", "--abbrev-ref", "HEAD"], in: root, timeout: 20)
        let branch = normalizedBranch(branchOutput)
        _ = try git(["fetch", "--quiet", "origin", branch], in: root, timeout: 20)
        let behind = AppUpdateDecision.parseBehind(
            try git(["rev-list", "--count", "HEAD..origin/\(branch)"], in: root, timeout: 20)
        )
        let dirty = AppUpdateDecision.isDirty(
            try git(["status", "--porcelain", "--untracked-files=no"], in: root, timeout: 20)
        )

        return GitUpdateCheckResult(
            decision: AppUpdateDecision.decide(isGit: true, behind: behind, dirty: dirty),
            branch: branch,
            repositoryRoot: root
        )
    }

    func apply(branch: String) throws -> URL {
        guard let root = repositoryRoot() else {
            throw GitUpdateControllerError.noRepository
        }
        _ = try git(["pull", "--ff-only", "origin", branch], in: root, timeout: 60)
        return root
    }

    func repositoryRoot() -> URL? {
        if let override = environment["OPENNEKO_UPDATE_ROOT"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            return isGitRepository(url) ? url : nil
        }

        var current = bundleURL
        while true {
            if isGitRepository(current) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    private func isGitRepository(_ url: URL) -> Bool {
        let gitURL = url.appendingPathComponent(".git", isDirectory: true)
        return fileManager.fileExists(atPath: gitURL.path)
    }

    private func normalizedBranch(_ output: String) -> String {
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if branch.isEmpty || branch == "HEAD" {
            return "main"
        }
        return branch
    }

    @discardableResult
    private func git(_ arguments: [String], in root: URL, timeout: TimeInterval) throws -> String {
        try run("/usr/bin/git", arguments: arguments, cwd: root, timeout: timeout)
    }

    @discardableResult
    private func run(_ executable: String, arguments: [String], cwd: URL, timeout: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = cwd
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitUpdateControllerError.commandFailed(
                command: ([executable] + arguments).joined(separator: " "),
                output: output
            )
        }
        return output
    }

    private func processEnvironment() -> [String: String] {
        ProcessPathEnvironment.spawnEnvironment(baseEnvironment: environment)
    }
}
