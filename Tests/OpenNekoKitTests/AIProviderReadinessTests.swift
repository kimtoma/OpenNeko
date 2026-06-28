import XCTest
@testable import OpenNekoKit

final class AIProviderReadinessTests: XCTestCase {
    func testCLIReadinessReportsAvailableExecutable() {
        let readiness = AIProviderReadiness.evaluate(
            config: AIProviderPreset.defaultConfig,
            preset: AIProviderPreset.preset(for: "chatgpt-oauth")!,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: true
        )

        XCTAssertEqual(readiness.severity, .ready)
        XCTAssertEqual(readiness.title, "CLI 준비됨")
        XCTAssertTrue(readiness.detail.contains("codex"))
    }

    func testCLIReadinessReportsMissingExecutable() {
        let config = AIProviderPreset.config(for: "claude-oauth")
        let readiness = AIProviderReadiness.evaluate(
            config: config,
            preset: AIProviderPreset.preset(for: "claude-oauth")!,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: false
        )

        XCTAssertEqual(readiness.severity, .needsAction)
        XCTAssertTrue(readiness.title.contains("Claude"))
        XCTAssertTrue(readiness.detail.contains("claude"))
    }

    func testAPIKeyReadinessUsesResolvedKeys() {
        let config = AIProviderPreset.config(for: "gemini")
        let preset = AIProviderPreset.preset(for: "gemini")!

        XCTAssertEqual(
            AIProviderReadiness.evaluate(
                config: config,
                preset: preset,
                hasResolvedAPIKey: true,
                cliExecutableAvailable: nil
            ).severity,
            .ready
        )

        let missing = AIProviderReadiness.evaluate(
            config: config,
            preset: preset,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: nil
        )
        XCTAssertEqual(missing.severity, .needsAction)
        XCTAssertTrue(missing.detail.contains("GEMINI_API_KEY"))
    }

    func testLocalOpenAICompatibleWarnsWhenModelIsMissing() {
        let config = AIProviderPreset.config(for: "ollama")
        let readiness = AIProviderReadiness.evaluate(
            config: config,
            preset: AIProviderPreset.preset(for: "ollama")!,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: nil
        )

        XCTAssertEqual(readiness.severity, .warning)
        XCTAssertEqual(readiness.title, "모델 이름 필요")
    }

    func testLocalOpenAICompatibleIsReadyWithModel() {
        let config = AIProviderPreset.config(
            for: "ollama",
            overrides: AIProviderConfig(model: "llama3.2")
        )
        let readiness = AIProviderReadiness.evaluate(
            config: config,
            preset: AIProviderPreset.preset(for: "ollama")!,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: nil
        )

        XCTAssertEqual(readiness.severity, .ready)
        XCTAssertEqual(readiness.title, "로컬 연결 준비됨")
    }

    func testReadinessCopyUsesSelectedLanguage() {
        let config = AIProviderPreset.config(for: "ollama")
        let readiness = AIProviderReadiness.evaluate(
            config: config,
            preset: AIProviderPreset.preset(for: "ollama")!,
            hasResolvedAPIKey: false,
            cliExecutableAvailable: nil,
            languageCode: "en"
        )

        XCTAssertEqual(readiness.title, "Model Name Needed")
        XCTAssertTrue(readiness.detail.contains("model name"))
    }
}
