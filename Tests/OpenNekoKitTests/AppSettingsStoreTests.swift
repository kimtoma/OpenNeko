import XCTest
@testable import OpenNekoKit

final class AppSettingsStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testDefaultSettingsUseDefaultSkinAndNoLoginItem() {
        XCTAssertEqual(AppSettings.defaults.selectedSkinID, SkinManager.defaultID)
        XCTAssertFalse(AppSettings.defaults.launchAtLoginEnabled)
        XCTAssertFalse(AppSettings.defaults.hasCompletedFirstLaunch)
        XCTAssertEqual(AppSettings.defaults.aiProvider, AIProviderPreset.defaultConfig)
        XCTAssertTrue(AppSettings.defaults.disabledSkillIDs.isEmpty)
        XCTAssertTrue(AppSettings.defaults.agentProcessDetectionEnabled)
        XCTAssertNil(AppSettings.defaults.languageCode)
        XCTAssertTrue(AppSettings.defaults.soundEffectsEnabled)
        XCTAssertFalse(AppSettings.defaults.webSearchEnabled)
        XCTAssertEqual(AppSettings.defaults.catName, "")
        XCTAssertEqual(AppSettings.defaults.userProfile, .empty)
        XCTAssertEqual(AppSettings.defaults.neighborSettings, .defaults)
        XCTAssertEqual(AppSettings.defaults.peerID, "")
    }

    func testLoadMissingSettingsReturnsDefaults() {
        let store = AppSettingsStore(fileURL: tmp.appendingPathComponent("settings.json"))

        XCTAssertEqual(store.load(), .defaults)
    }

    func testDefaultFileURLCanUseEnvironmentOverrideForQA() {
        let override = tmp.appendingPathComponent("qa/settings.json").path

        let url = AppSettingsStore.defaultFileURL(environment: [
            "OPENNEKO_SETTINGS_PATH": " \(override) ",
        ])

        XCTAssertEqual(url.path, override)
    }

    func testDefaultFileURLIgnoresBlankEnvironmentOverride() {
        let url = AppSettingsStore.defaultFileURL(environment: [
            "OPENNEKO_SETTINGS_PATH": "  ",
        ])

        XCTAssertTrue(url.path.hasSuffix("Application Support/openNeko/settings.json"))
    }

    func testSaveAndLoadRoundTripsSettings() throws {
        let store = AppSettingsStore(fileURL: tmp.appendingPathComponent("nested/settings.json"))
        let settings = AppSettings(
            selectedSkinID: "black",
            launchAtLoginEnabled: true,
            hasCompletedFirstLaunch: true,
            aiProvider: AIProviderPreset.config(
                for: "local-openai",
                overrides: AIProviderConfig(baseURL: "http://127.0.0.1:1234/v1", model: "local-model")
            ),
            disabledSkillIDs: ["translate"],
            agentProcessDetectionEnabled: false,
            languageCode: "en",
            soundEffectsEnabled: false,
            webSearchEnabled: true,
            catName: "Nabi",
            userProfile: UserProfile(
                name: "Kim",
                birthDate: "1990-01-02",
                birthTime: "08:30",
                calendar: "lunar"
            ),
            neighborSettings: NeighborSettings(enabled: false, displayName: "Desk Cat"),
            peerID: "peer-123"
        )

        try store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testLoadLegacySettingsPreservesExistingValues() throws {
        let url = tmp.appendingPathComponent("settings.json")
        try Data(#"{"launchAtLoginEnabled":true,"selectedSkinID":"pink"}"#.utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(
            store.load(),
            AppSettings(
                selectedSkinID: "pink",
                launchAtLoginEnabled: true,
                hasCompletedFirstLaunch: false,
                aiProvider: AIProviderPreset.defaultConfig
            )
        )
    }

    func testLoadElectronSettingsMigratesUserFacingValues() throws {
        let url = tmp.appendingPathComponent("settings.json")
        let json = """
        {
          "provider": {
            "preset": "custom",
            "type": "openai-compat",
            "baseURL": "http://127.0.0.1:9090/v1",
            "model": "neko-local"
          },
          "skin": "black",
          "onboarded": true,
          "launchAtLogin": true,
          "disabledSkills": ["translate", "daily-bgm"],
          "lang": "ja",
          "sound": { "enabled": false },
          "webSearch": true,
          "catName": "Momo",
          "neighbor": { "enabled": false, "displayName": "Desk Cat" },
          "peerId": "legacy-peer",
          "profile": {
            "name": "Ari",
            "birthDate": "2001-02-03",
            "birthTime": "04:05",
            "calendar": "lunar"
          }
        }
        """
        try Data(json.utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(
            store.load(),
            AppSettings(
                selectedSkinID: "black",
                launchAtLoginEnabled: true,
                hasCompletedFirstLaunch: true,
                aiProvider: AIProviderPreset.config(
                    for: "custom",
                    overrides: AIProviderConfig(
                        presetID: "custom",
                        type: .openAICompatible,
                        baseURL: "http://127.0.0.1:9090/v1",
                        model: "neko-local"
                    )
                ),
                disabledSkillIDs: ["daily-bgm", "translate"],
                agentProcessDetectionEnabled: true,
                languageCode: "ja",
                soundEffectsEnabled: false,
                webSearchEnabled: true,
                catName: "Momo",
                userProfile: UserProfile(
                    name: "Ari",
                    birthDate: "2001-02-03",
                    birthTime: "04:05",
                    calendar: "lunar"
                ),
                neighborSettings: NeighborSettings(enabled: false, displayName: "Desk Cat"),
                peerID: "legacy-peer"
            )
        )
    }

    func testLoadElectronCatNameFallsBackToNeighborDisplayName() throws {
        let url = tmp.appendingPathComponent("settings.json")
        try Data(#"{"neighbor":{"displayName":"Desk Cat"}}"#.utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(store.load().catName, "Desk Cat")
        XCTAssertEqual(store.load().neighborSettings.displayName, "Desk Cat")
    }

    func testLoadElectronWhiteSkinUsesNativeDefaultSkin() throws {
        let url = tmp.appendingPathComponent("settings.json")
        try Data(#"{"skin":"white","onboarded":true}"#.utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(store.load().selectedSkinID, SkinManager.defaultID)
        XCTAssertTrue(store.load().hasCompletedFirstLaunch)
    }

    func testLoadElectronPresetWithoutOverridesUsesNativePresetDefaults() throws {
        let url = tmp.appendingPathComponent("settings.json")
        try Data(#"{"provider":{"preset":"ollama","type":"openai-compat"}}"#.utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(store.load().aiProvider, AIProviderPreset.config(for: "ollama"))
    }

    func testLoadInvalidSettingsReturnsDefaults() throws {
        let url = tmp.appendingPathComponent("settings.json")
        try Data("not json".utf8).write(to: url)
        let store = AppSettingsStore(fileURL: url)

        XCTAssertEqual(store.load(), .defaults)
    }
}
