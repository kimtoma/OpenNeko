import XCTest
@testable import OpenNekoKit

final class AppLaunchOptionsTests: XCTestCase {
    func testOpenSettingsFlagDefaultsOff() {
        XCTAssertFalse(AppLaunchOptions(environment: [:]).opensSettingsOnLaunch)
    }

    func testOpenSettingsFlagAcceptsOneAndTrue() {
        XCTAssertTrue(AppLaunchOptions(environment: ["OPENNEKO_OPEN_SETTINGS": "1"]).opensSettingsOnLaunch)
        XCTAssertTrue(AppLaunchOptions(environment: ["OPENNEKO_OPEN_SETTINGS": "true"]).opensSettingsOnLaunch)
    }

    func testSettingsSnapshotPathTrimsBlankValues() {
        XCTAssertNil(AppLaunchOptions(environment: ["OPENNEKO_SETTINGS_SNAPSHOT": "  "]).settingsSnapshotPath)
        XCTAssertEqual(
            AppLaunchOptions(environment: ["OPENNEKO_SETTINGS_SNAPSHOT": " /tmp/openneko-settings.png "]).settingsSnapshotPath,
            "/tmp/openneko-settings.png"
        )
    }

    func testDebugSettingsMutationFlagDefaultsOffAndRequiresExplicitOptIn() {
        XCTAssertFalse(AppLaunchOptions(environment: [:]).debugSettingsMutationEnabled)
        XCTAssertTrue(AppLaunchOptions(environment: ["OPENNEKO_DEBUG_SETTINGS_MUTATION": "1"]).debugSettingsMutationEnabled)
        XCTAssertTrue(AppLaunchOptions(environment: ["OPENNEKO_DEBUG_SETTINGS_MUTATION": "true"]).debugSettingsMutationEnabled)
        XCTAssertFalse(AppLaunchOptions(environment: ["OPENNEKO_DEBUG_SETTINGS_MUTATION": "yes"]).debugSettingsMutationEnabled)
    }
}
