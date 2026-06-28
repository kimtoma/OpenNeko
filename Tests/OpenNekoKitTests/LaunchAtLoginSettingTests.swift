import XCTest
@testable import OpenNekoKit

final class LaunchAtLoginSettingTests: XCTestCase {
    func testLaunchAtLoginCopyIsShortAndSpecific() {
        let setting = LaunchAtLoginSetting(isEnabled: false)

        XCTAssertEqual(setting.title, "로그인 시 자동 실행")
        XCTAssertLessThanOrEqual(setting.title.count, 15)
        XCTAssertFalse(setting.detail.isEmpty)
    }

    func testLaunchAtLoginSettingCanReflectEnabledState() {
        XCTAssertFalse(LaunchAtLoginSetting(isEnabled: false).isEnabled)
        XCTAssertTrue(LaunchAtLoginSetting(isEnabled: true).isEnabled)
    }
}
