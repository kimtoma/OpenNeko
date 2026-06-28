import Foundation
import OpenNekoKit

enum AgentCLIKind: Equatable {
    case claude
    case gemini

    var executableName: String {
        switch self {
        case .claude: "claude"
        case .gemini: "gemini"
        }
    }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .gemini: "Gemini"
        }
    }

    var serviceName: String {
        switch self {
        case .claude: "Claude Code CLI"
        case .gemini: "Gemini CLI"
        }
    }
}

enum AgentCLIChatError: Error, Equatable {
    case timeout(AgentCLIKind)
    case missing(AgentCLIKind)
    case auth(AgentCLIKind)
    case empty(AgentCLIKind)
    case cli(AgentCLIKind, String)

    var userMessage: String {
        userMessage(languageCode: "ko")
    }

    func userMessage(languageCode: String?) -> String {
        switch self {
        case .timeout:
            Self.localized(languageCode, ko: "응답 시간이 초과됐다냥", en: "The response timed out, nya.", ja: "返事がタイムアウトしたにゃ", zh: "响应超时了喵")
        case .missing(let kind):
            Self.localized(
                languageCode,
                ko: "\(kind.displayName) CLI 설치가 필요하다냥",
                en: "\(kind.displayName) CLI is needed, nya.",
                ja: "\(kind.displayName) CLI が必要にゃ",
                zh: "需要 \(kind.displayName) CLI 喵"
            )
        case .auth(let kind):
            Self.localized(
                languageCode,
                ko: "\(kind.displayName) 로그인이 필요하다냥",
                en: "\(kind.displayName) login is needed, nya.",
                ja: "\(kind.displayName) ログインが必要にゃ",
                zh: "需要 \(kind.displayName) 登录喵"
            )
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

final class AgentCLIChatProvider {
    private let kind: AgentCLIKind
    private let executableName: String
    private let model: String
    private let languageCode: String
    private let workingDirectory: String
    private let timeout: TimeInterval

    init(
        kind: AgentCLIKind,
        executableName: String? = nil,
        model: String = "",
        languageCode: String = "ko",
        workingDirectory: String = NSHomeDirectory(),
        timeout: TimeInterval = 120
    ) {
        self.kind = kind
        self.executableName = executableName ?? kind.executableName
        self.model = model
        self.languageCode = languageCode
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    func chat(history: [ChatMessage], system: String? = nil) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try self.run(history: history, system: system)
        }.value
    }

    private func run(history: [ChatMessage], system: String?) throws -> String {
        let args = arguments(history: history, system: system)
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
            throw AgentCLIChatError.timeout(kind)
        }

        if process.terminationStatus != 0 {
            let output = limitedOutput(stderr, stdout)
            throw classifyFailure(output: output)
        }

        let text = String(decoding: stdout, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AgentCLIChatError.empty(kind)
        }
        return text
    }

    private func arguments(history: [ChatMessage], system: String?) -> [String] {
        switch kind {
        case .claude:
            let prompt = ChatPromptBuilder.formatPrompt(history, languageCode: languageCode)
            let system = ChatPromptBuilder.claudeSystemPrompt(system: system, languageCode: languageCode)
            return ChatPromptBuilder.claudePrintArguments(model: model, prompt: prompt, system: system)
        case .gemini:
            let prompt = ChatPromptBuilder.geminiInlinePrompt(history: history, system: system, languageCode: languageCode)
            return ChatPromptBuilder.geminiPromptArguments(model: model, prompt: prompt)
        }
    }

    private func processEnvironment() -> [String: String] {
        ProcessPathEnvironment.spawnEnvironment(terminalDefaults: true)
    }

    private func limitedOutput(_ stderr: Data, _ stdout: Data) -> String {
        let data = stderr.isEmpty ? stdout : stderr
        let text = String(decoding: data, as: UTF8.self)
        return String(text.suffix(12_000))
    }

    private func classifyFailure(output: String) -> AgentCLIChatError {
        let redacted = redactSecrets(output)
        if redacted.range(of: #"No such file or directory|not found|env: .*: No such"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .missing(kind)
        }
        if redacted.range(of: #"not logged in|login|auth|unauthorized|forbidden|api key|oauth|credentials"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .auth(kind)
        }
        return .cli(kind, String(redacted.prefix(600)))
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
