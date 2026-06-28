import XCTest
@testable import OpenNekoKit

final class SettingsPaneTests: XCTestCase {
    func testSettingsPanesAppearInUserFacingOrder() {
        XCTAssertEqual(SettingsPane.allCases, [.start, .ai, .skins, .skills, .profile, .general, .neighbors, .permissions, .bridge, .about])
    }

    func testSettingsPaneTitles() {
        XCTAssertEqual(SettingsPane.start.title, "시작")
        XCTAssertEqual(SettingsPane.general.title, "일반")
        XCTAssertEqual(SettingsPane.neighbors.title, "이웃 고양이")
        XCTAssertEqual(SettingsPane.profile.title, "내 프로필")
        XCTAssertEqual(SettingsPane.ai.title, "AI")
        XCTAssertEqual(SettingsPane.skills.title, "스킬")
        XCTAssertEqual(SettingsPane.permissions.title, "권한")
        XCTAssertEqual(SettingsPane.bridge.title, "브리지")
        XCTAssertEqual(SettingsPane.skins.title, "외형")
        XCTAssertEqual(SettingsPane.about.title, "정보")
    }

    func testLocalizedSettingsPaneTitles() {
        XCTAssertEqual(SettingsPane.start.title(languageCode: "en"), "Start")
        XCTAssertEqual(SettingsPane.skins.title(languageCode: "en"), "Appearance")
        XCTAssertEqual(SettingsPane.neighbors.title(languageCode: "en"), "Neighbor Cats")
        XCTAssertEqual(SettingsPane.permissions.title(languageCode: "ja"), "権限")
        XCTAssertEqual(SettingsPane.bridge.title(languageCode: "zh"), "桥接")
    }

    func testSettingsPaneLabelsStayShort() {
        for pane in SettingsPane.allCases {
            XCTAssertLessThanOrEqual(pane.title.count, 10)
            XCTAssertFalse(pane.systemImage.isEmpty)
        }
    }

    func testSettingsCopyUsesSelectedLanguage() {
        XCTAssertEqual(SettingsCopy.text(.soundEffects, languageCode: "en"), "Sound Effects")
        XCTAssertEqual(SettingsCopy.text(.neighborDiscovery, languageCode: "ja"), "近くのねこを探す")
        XCTAssertEqual(SettingsCopy.text(.webSearchOff, languageCode: "zh"), "不使用搜索辅助。")
        XCTAssertEqual(SettingsCopy.text(.activateSkill, languageCode: "en"), "Activate skill")
        XCTAssertEqual(SettingsCopy.text(.defaultSkin, languageCode: "ko"), "white")
        XCTAssertEqual(
            SettingsCopy.enabledSkillsCount(enabled: 2, total: 7, languageCode: "en"),
            "2/7 enabled"
        )
        XCTAssertEqual(
            SettingsCopy.neighborStatus(enabled: true, peerCount: 3, languageCode: "ko"),
            "3명 발견"
        )
    }

    func testOnboardingCopyKeepsCatVoiceForFirstLaunch() {
        let onboardingKeys: [SettingsCopyKey] = [
            .onboardingTitle,
            .onboardingWelcomeBody,
            .onboardingFeatureDesktopBody,
            .onboardingFeatureChatBody,
            .onboardingFeatureSkillsBody,
            .onboardingNekoGuideBody,
            .onboardingNext,
            .onboardingFinish
        ]

        for key in onboardingKeys {
            XCTAssertTrue(
                SettingsCopy.text(key, languageCode: "ko").contains("냥"),
                "\(key.rawValue) should use cat voice"
            )
        }
    }
}
