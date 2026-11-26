import Foundation
import OpenNekoKit

/// Runs one delegated `/task` through the local Claude Code CLI inside the
/// folder the user picked. Decisions (arguments, approval rounds, phases,
/// log lines) live in OpenNekoKit (`AgentTaskSession`,
/// `ClaudeTaskEventParser`, `AgentActivityEntry`); this class only runs the
/// process and moves its output onto the main queue.
final class AgentTaskController {
    private(set) var session: AgentTaskSession?
    private var process: Process?
    private var lineBuffer = LineBuffer()
    private var stderrTail = ""
    private var model = ""
    var onUpdate: ((AgentTaskSession) -> Void)?

    var isBusy: Bool {
        session?.phase.isActive ?? false
    }

    static var logURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("openNeko/agent-activity.jsonl")
    }

    func start(prompt: String, folder: String, model: String = "", readOnly: Bool = false) {
        guard !isBusy else { return }
        self.model = model
        session = AgentTaskSession(prompt: prompt, folder: folder, readOnly: readOnly)
        log(.started, prompt)
        launch(followUp: nil)
        notify()
    }

    func approve() {
        guard var current = session, case let .awaitingApproval(requests) = current.phase,
              let followUp = current.approve()
        else { return }
        session = current
        for request in requests {
            log(.approved, request.allowRule)
        }
        launch(followUp: followUp)
        notify()
    }

    func deny() {
        guard var current = session, case let .awaitingApproval(requests) = current.phase else { return }
        current.deny()
        session = current
        for request in requests {
            log(.denied, request.allowRule)
        }
        notify()
    }

    func cancel() {
        process?.terminate()
        guard var current = session, current.phase.isActive else { return }
        current.cancel()
        session = current
        log(.denied, "cancelled")
        notify()
    }

    // MARK: - Process

    private func launch(followUp: String?) {
        guard let current = session else { return }
        lineBuffer = LineBuffer()
        stderrTail = ""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude"] + current.claudeArguments(followUp: followUp, model: model)
        process.currentDirectoryURL = URL(fileURLWithPath: current.folder, isDirectory: true)
        process.environment = ProcessPathEnvironment.spawnEnvironment(terminalDefaults: true)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(stdout: data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(stderr: data) }
        }
        process.terminationHandler = { [weak self] finished in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            let restOut = stdout.fileHandleForReading.readDataToEndOfFile()
            let restErr = stderr.fileHandleForReading.readDataToEndOfFile()
            let status = finished.terminationStatus
            DispatchQueue.main.async {
                self?.consume(stdout: restOut)
                self?.consume(stderr: restErr)
                self?.processEnded(status: status)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            self.process = nil
            update { $0.processExited(status: 127, stderr: error.localizedDescription) }
        }
    }

    private func consume(stdout data: Data) {
        guard !data.isEmpty else { return }
        for line in lineBuffer.append(data) {
            handle(line: line)
        }
    }

    private func consume(stderr data: Data) {
        guard !data.isEmpty else { return }
        stderrTail = String((stderrTail + String(decoding: data, as: UTF8.self)).suffix(2_000))
    }

    private func processEnded(status: Int32) {
        if let tail = lineBuffer.flush() {
            handle(line: tail)
        }
        process = nil
        update { $0.processExited(status: status, stderr: stderrTail) }
    }

    private func handle(line: String) {
        for event in ClaudeTaskEventParser.events(fromLine: line) {
            if case let .toolUse(tool) = event {
                log(.tool, tool.detail.isEmpty ? tool.name : "\(tool.name): \(tool.detail)")
            }
            update { $0.apply(event) }
        }
    }

    /// Applies a change and, when the phase moved, logs it and notifies.
    private func update(_ change: (inout AgentTaskSession) -> Void) {
        guard var current = session else { return }
        let before = current.phase
        change(&current)
        session = current
        guard current.phase != before else { return }
        switch current.phase {
        case let .awaitingApproval(requests):
            for request in requests {
                log(.approvalRequested, request.allowRule)
            }
        case let .finished(summary):
            log(.finished, summary)
        case let .failed(message):
            log(.failed, message)
        case .running, .denied:
            break
        }
        notify()
    }

    private func notify() {
        guard let session else { return }
        onUpdate?(session)
    }

    // MARK: - Activity log

    private func log(_ kind: AgentActivityEntry.Kind, _ detail: String) {
        guard let session else { return }
        Self.append(AgentActivityEntry(timestamp: Date(), agent: "claude", folder: session.folder, kind: kind, detail: detail))
    }

    /// Appends one line to the shared activity log (also used by native tools).
    static func append(_ entry: AgentActivityEntry) {
        let line = entry.jsonLine()
        guard !line.isEmpty else { return }
        let url = logURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            NSLog("[openNeko] failed to write agent activity log: \(error)")
        }
    }
}
