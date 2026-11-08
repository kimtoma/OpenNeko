import XCTest
@testable import OpenNekoKit

final class AIProviderPresetTests: XCTestCase {
    func testDefaultPresetUsesCodexOAuth() {
        XCTAssertEqual(AIProviderPreset.defaultID, "chatgpt-oauth")
        XCTAssertEqual(AIProviderPreset.defaultConfig.presetID, "chatgpt-oauth")
        XCTAssertEqual(AIProviderPreset.defaultConfig.type, .codexCLI)
    }

    func testCLIProviderTypesMapToExecutableNames() {
        XCTAssertEqual(AIProviderType.codexCLI.cliExecutableName, "codex")
        XCTAssertEqual(AIProviderType.claudeCLI.cliExecutableName, "claude")
        XCTAssertEqual(AIProviderType.geminiCLI.cliExecutableName, "gemini")
    }

    func testHTTPProviderTypesHaveNoCLIExecutable() {
        XCTAssertNil(AIProviderType.openAICompatible.cliExecutableName)
        XCTAssertNil(AIProviderType.gemini.cliExecutableName)
        XCTAssertNil(AIProviderType.anthropic.cliExecutableName)
    }

    func testPresetListKeepsUserFriendlyOrder() {
        XCTAssertEqual(AIProviderPreset.all.map(\.id), [
            "chatgpt-oauth",
            "claude-oauth",
            "gemini-oauth",
            "ollama",
            "local-openai",
            "gemini",
            "claude",
            "custom",
        ])
        XCTAssertTrue(AIProviderPreset.all[0].isRecommended)
    }

    func testPresetConfigAppliesDefaultsAndOverrides() {
        let config = AIProviderPreset.config(
            for: "ollama",
            overrides: AIProviderConfig(baseURL: nil, model: "llama3.2")
        )

        XCTAssertEqual(config.presetID, "ollama")
        XCTAssertEqual(config.type, .openAICompatible)
        XCTAssertEqual(config.baseURL, "http://localhost:11434/v1")
        XCTAssertEqual(config.model, "llama3.2")
    }

    func testUnknownPresetFallsBackToDefault() {
        let config = AIProviderPreset.config(for: "missing")

        XCTAssertEqual(config, AIProviderPreset.defaultConfig)
    }

    func testPresetCopyUsesSelectedLanguage() {
        let codex = AIProviderPreset.preset(for: "chatgpt-oauth")!
        let local = AIProviderPreset.preset(for: "local-openai")!

        XCTAssertEqual(codex.title(languageCode: "en"), "OpenAI Login (Codex)")
        XCTAssertEqual(local.title(languageCode: "ja"), "ローカルOpenAI互換")
        XCTAssertTrue(codex.note(languageCode: "zh").contains("Codex CLI"))
    }

    func testResolveApiKeyUsesSavedValueFirstThenEnvironment() {
        XCTAssertEqual(
            AIProviderPreset.resolveAPIKey(
                presetID: "gemini",
                savedKey: "saved",
                environment: ["GEMINI_API_KEY": "env"]
            ),
            "saved"
        )
        XCTAssertEqual(
            AIProviderPreset.resolveAPIKey(
                presetID: "gemini",
                savedKey: "",
                environment: ["GOOGLE_API_KEY": "google"]
            ),
            "google"
        )
        XCTAssertEqual(
            AIProviderPreset.resolveAPIKey(
                presetID: "claude",
                savedKey: nil,
                environment: ["ANTHROPIC_API_KEY": "anthropic"]
            ),
            "anthropic"
        )
    }
}
