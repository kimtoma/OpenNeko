import Foundation
import OpenNekoKit

enum CodexChatError: Error, Equatable {
    case timeout
    case auth(String)
    case empty
    case cli(String)

    var userMessage: String {
        userMessage(languageCode: "ko")
    }

    func userMessage(languageCode: String?) -> String {
        switch self {
        case .timeout:
            Self.localized(languageCode, ko: "응답 시간이 초과됐다냥", en: "The response timed out, nya.", ja: "返事がタイムアウトしたにゃ", zh: "响应超时了喵")
        case .auth:
            Self.localized(languageCode, ko: "Codex 로그인이 필요하다냥", en: "Codex login is needed, nya.", ja: "Codexログインが必要にゃ", zh: "需要 Codex 登录喵")
        case .empty:
            Self.localized(languageCode, ko: "빈 응답이 왔다냥", en: "The response was empty, nya.", ja: "空の返事だったにゃ", zh: "返回了空响应喵")
        case .cli:
            Self.localized(languageCode, ko: "답변을 만들지 못했다냥", en: "I could not make an answer, nya.", ja: "返事を作れなかったにゃ", zh: "没能生成回答喵")
        }
    }

    private static func localized(
        _ languageCode: String?,
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}

final class CodexChatProvider {
    private let executableName: String
    private let model: String
    private let languageCode: String
    private let workingDirectory: String
    private let timeout: TimeInterval
    private let fileManager: FileManager

    init(
        executableName: String = "codex",
        model: String = "",
        languageCode: String = "ko",
        workingDirectory: String = NSHomeDirectory(),
        timeout: TimeInterval = 120,
        fileManager: FileManager = .default
    ) {
        self.executableName = executableName
        self.model = model
        self.languageCode = languageCode
        self.workingDirectory = workingDirectory
        self.timeout = timeout
        self.fileManager = fileManager
    }

    func chat(history: [ChatMessage], system: String? = nil) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try self.run(history: history, system: system)
        }.value
    }

    private func run(history: [ChatMessage], system: String?) throws -> String {
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("openneko-codex-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let outFile = tempRoot.appendingPathComponent("last-message.txt")
        let prompt = ChatPromptBuilder.codexPrompt(history: history, system: system, languageCode: languageCode)
        let args = ChatPromptBuilder.codexExecArguments(
            model: model,
            workingDirectory: workingDirectory,
            outputFile: outFile.path,
            prompt: prompt
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executableName] + args
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        process.environment = processEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdout = Data()
        var stderr = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        var didTimeout = false
        let timeoutItem = DispatchWorkItem {
            didTimeout = true
            if process.isRunning {
                process.terminate()
            }
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        try process.run()
        process.waitUntilExit()
        timeoutItem.cancel()
        group.wait()

        if didTimeout {
            throw CodexChatError.timeout
        }

        if process.terminationStatus != 0 {
            let output = limitedOutput(stderr, stdout)
            throw classifyFailure(output: output)
        }

        let text = (try? String(contentsOf: outFile, encoding: .utf8))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard !text.isEmpty else {
            throw CodexChatError.empty
        }
        return text
    }

    private func processEnvironment() -> [String: String] {
        ProcessPathEnvironment.spawnEnvironment(terminalDefaults: true)
    }

    private func limitedOutput(_ stderr: Data, _ stdout: Data) -> String {
        let data = stderr.isEmpty ? stdout : stderr
        let text = String(decoding: data, as: UTF8.self)
        return String(text.suffix(12_000))
    }

    private func classifyFailure(output: String) -> CodexChatError {
        let redacted = redactSecrets(output)
        if redacted.range(of: "not logged in|login|auth|unauthorized|forbidden|ChatGPT", options: [.regularExpression, .caseInsensitive]) != nil {
            return .auth(redacted)
        }
        return .cli(String(redacted.prefix(600)))
    }

    private func redactSecrets(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"Bearer\s+\S+"#,
                with: "Bearer ...",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"sk-[A-Za-z0-9_-]{6,}"#,
                with: "sk-...",
                options: [.regularExpression]
            )
            .replacingOccurrences(
                of: #"AIza[A-Za-z0-9_-]{6,}"#,
                with: "AIza...",
                options: [.regularExpression]
            )
    }
}
