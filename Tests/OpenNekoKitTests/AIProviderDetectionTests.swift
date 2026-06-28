import XCTest
@testable import OpenNekoKit

final class AIProviderDetectionTests: XCTestCase {
    func testEnvironmentDetectionsUseKnownProviderKeys() {
        let detections = AIProviderDetection.environmentDetections(
            environment: [
                "GEMINI_API_KEY": "gemini",
                "ANTHROPIC_API_KEY": "claude",
                "CUSTOM_API_KEY": "ignored",
            ]
        )

        XCTAssertEqual(detections.map(\.presetID), ["gemini", "claude"])
        XCTAssertEqual(detections[0].source, .environment)
        XCTAssertEqual(detections[0].detail, "GEMINI_API_KEY")
    }

    func testCodexDetectionRequiresLoginStatus() {
        XCTAssertNil(
            AIProviderDetection.cliDetection(
                presetID: "chatgpt-oauth",
                executable: "codex",
                executableAvailable: true,
                codexLoginStatusOutput: "Not logged in"
            )
        )

        let detection = AIProviderDetection.cliDetection(
            presetID: "chatgpt-oauth",
            executable: "codex",
            executableAvailable: true,
            codexLoginStatusOutput: "Logged in using ChatGPT"
        )

        XCTAssertEqual(detection?.presetID, "chatgpt-oauth")
        XCTAssertEqual(detection?.source, .oauth)
    }

    func testNonCodexCLIDetectionUsesExecutableAvailability() {
        XCTAssertNil(
            AIProviderDetection.cliDetection(
                presetID: "claude-oauth",
                executable: "claude",
                executableAvailable: false
            )
        )

        XCTAssertEqual(
            AIProviderDetection.cliDetection(
                presetID: "gemini-oauth",
                executable: "gemini",
                executableAvailable: true
            )?.detail,
            "gemini"
        )
    }

    func testOllamaModelsParseNameAndModelFields() {
        let data = Data(#"{"models":[{"name":"gemma4:e2b"},{"model":"llama3.2"},{"name":"   "}]}"#.utf8)

        XCTAssertEqual(AIProviderDetection.ollamaModels(from: data), ["gemma4:e2b", "llama3.2"])
    }

    func testOllamaDetectionAppliesFirstDetectedModel() {
        let detection = AIProviderDetection.ollamaDetection(models: ["gemma4:e2b", "llama3.2"])

        XCTAssertEqual(detection?.presetID, "ollama")
        XCTAssertEqual(detection?.model, "gemma4:e2b")
        XCTAssertEqual(detection?.config().model, "gemma4:e2b")
        XCTAssertEqual(detection?.config().baseURL, "http://localhost:11434/v1")
    }

    func testUniqueReadyDropsUnknownAndDuplicatePresets() {
        let detections = AIProviderDetection.uniqueReady([
            AIProviderDetection(presetID: "gemini", source: .environment, detail: "GEMINI_API_KEY"),
            AIProviderDetection(presetID: "gemini", source: .environment, detail: "GOOGLE_API_KEY"),
            AIProviderDetection(presetID: "missing", source: .local),
            AIProviderDetection(presetID: "ollama", source: .local, models: ["llama3.2"], model: "llama3.2"),
        ])

        XCTAssertEqual(detections.map(\.presetID), ["gemini", "ollama"])
    }

    func testDetectionCopyUsesSelectedLanguage() {
        let detection = AIProviderDetection(presetID: "gemini", source: .environment, detail: "GEMINI_API_KEY")

        XCTAssertEqual(detection.source.label(languageCode: "en"), "Environment")
        XCTAssertTrue(detection.subtitle(languageCode: "ja").contains("GEMINI_API_KEY"))
    }
}
