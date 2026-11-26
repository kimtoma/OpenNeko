import XCTest
@testable import OpenNekoKit

final class OnDeviceModelAvailabilityTests: XCTestCase {
    private let config = AIProviderPreset.config(for: "apple-intelligence")
    private var preset: AIProviderPreset { AIProviderPreset.preset(for: "apple-intelligence")! }

    func testPresetIsLocalWithNoFields() {
        XCTAssertEqual(config.type, .appleFoundation)
        XCTAssertEqual(config.baseURL, "")
        XCTAssertTrue(preset.isLocal)
        XCTAssertEqual(preset.fields, [])
        XCTAssertFalse(preset.requiresAPIKey)
        XCTAssertNil(AIProviderType.appleFoundation.cliExecutableName)
        XCTAssertEqual(preset.title(languageCode: "en"), "Apple On-Device Model")
        XCTAssertEqual(Set(["ko", "en", "ja", "zh"].map { preset.note(languageCode: $0) }).count, 4)
    }

    func testReadinessFollowsRuntimeAvailability() {
        func severity(_ availability: OnDeviceModelAvailability?) -> AIProviderReadinessSeverity {
            AIProviderReadiness.evaluate(
                config: config,
                preset: preset,
                hasResolvedAPIKey: false,
                cliExecutableAvailable: nil,
                languageCode: "en",
                onDeviceAvailability: availability
            ).severity
        }
        XCTAssertEqual(severity(.available), .ready)
        XCTAssertEqual(severity(.modelNotReady), .warning)
        XCTAssertEqual(severity(.unsupportedOS), .needsAction)
        XCTAssertEqual(severity(.deviceNotEligible), .needsAction)
        XCTAssertEqual(severity(.appleIntelligenceNotEnabled), .needsAction)
        XCTAssertEqual(severity(nil), .needsAction)
    }

    func testCopyIsLocalized() {
        let all: [OnDeviceModelAvailability] = [.available, .unsupportedOS, .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unknown]
        for availability in all {
            let details = ["ko", "en", "ja", "zh"].map { availability.readiness(languageCode: $0).detail }
            XCTAssertEqual(Set(details).count, 4, "\(availability)")
        }
        XCTAssertEqual(OnDeviceModelAvailability.unsupportedOS.readiness(languageCode: "en").detail, "Requires macOS 26 or later.")
    }

    func testDetectionOnlyWhenAvailable() {
        XCTAssertEqual(AIProviderDetection.onDeviceDetection(availability: .available)?.presetID, "apple-intelligence")
        XCTAssertNil(AIProviderDetection.onDeviceDetection(availability: .modelNotReady))
    }

    func testHTTPBuilderRejectsOnDeviceType() {
        XCTAssertThrowsError(try HTTPChatRequestBuilder.request(config: config, apiKey: nil, history: [], system: nil))
    }
}
