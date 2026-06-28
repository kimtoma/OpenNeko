import XCTest
@testable import OpenNekoKit

final class AppSettingsDebugSnapshotTests: XCTestCase {
    func testSnapshotKeepsSettingsStateWithoutProfileValues() throws {
        let settings = AppSettings(
            selectedSkinID: "tabby",
            launchAtLoginEnabled: true,
            hasCompletedFirstLaunch: true,
            aiProvider: AIProviderConfig(
                presetID: "custom",
                type: .openAICompatible,
                baseURL: "http://127.0.0.1:1234/v1",
                model: "local-model"
            ),
            disabledSkillIDs: ["tarot", "coach"],
            agentProcessDetectionEnabled: false,
            languageCode: "en",
            soundEffectsEnabled: false,
            webSearchEnabled: true,
            catName: "Mochi",
            userProfile: UserProfile(
                name: "Private Name",
                birthDate: "1999-01-02",
                birthTime: "03:04",
                calendar: "lunar"
            ),
            neighborSettings: NeighborSettings(enabled: true, displayName: "Desk Cat"),
            peerID: "peer-1"
        )

        let snapshot = AppSettingsDebugSnapshot(settings: settings)

        XCTAssertEqual(snapshot.selectedSkinID, "tabby")
        XCTAssertEqual(snapshot.aiProviderPresetID, "custom")
        XCTAssertEqual(snapshot.aiProviderBaseURL, "http://127.0.0.1:1234/v1")
        XCTAssertEqual(snapshot.disabledSkillIDs, ["coach", "tarot"])
        XCTAssertFalse(snapshot.agentProcessDetectionEnabled)
        XCTAssertEqual(snapshot.languageCode, "en")
        XCTAssertFalse(snapshot.soundEffectsEnabled)
        XCTAssertTrue(snapshot.webSearchEnabled)
        XCTAssertEqual(snapshot.catName, "Mochi")
        XCTAssertTrue(snapshot.userProfileConfigured)
        XCTAssertEqual(snapshot.userProfileFields, ["name", "birthDate", "birthTime", "calendar"])
        XCTAssertEqual(snapshot.neighborDisplayName, "Desk Cat")
        XCTAssertTrue(snapshot.peerIDConfigured)

        let json = try XCTUnwrap(AppSettingsDebugSnapshot.jsonString(settings: settings))
        XCTAssertFalse(json.contains("Private Name"))
        XCTAssertFalse(json.contains("1999-01-02"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("apiKey"))
    }
}
