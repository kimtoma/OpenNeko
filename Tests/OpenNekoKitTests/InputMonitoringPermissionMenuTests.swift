import XCTest
@testable import OpenNekoKit

final class InputMonitoringPermissionMenuTests: XCTestCase {
    func testGrantedStatusShowsTypingReactionOn() {
        let menu = InputMonitoringPermissionMenu(status: .granted)

        XCTAssertEqual(menu.statusTitle, "타이핑 반응 켜짐")
        XCTAssertFalse(menu.needsUserAction)
    }

    func testMissingStatusShowsPermissionNeeded() {
        let menu = InputMonitoringPermissionMenu(
            status: .missing,
            accessibilityGranted: true,
            inputMonitoringGranted: false
        )

        XCTAssertEqual(menu.statusTitle, "타이핑 권한 필요")
        XCTAssertTrue(menu.accessibilityGranted)
        XCTAssertFalse(menu.inputMonitoringGranted)
        XCTAssertTrue(menu.needsUserAction)
    }

    func testNeedsUserActionUsesBothPermissionFlags() {
        let menu = InputMonitoringPermissionMenu(
            status: .granted,
            accessibilityGranted: false,
            inputMonitoringGranted: true
        )

        XCTAssertTrue(menu.needsUserAction)
    }

    func testActionTitlesStayShortForMenuBar() {
        let menu = InputMonitoringPermissionMenu(status: .missing)

        XCTAssertLessThanOrEqual(menu.openAccessibilityTitle(languageCode: nil).count, 30)
        XCTAssertLessThanOrEqual(menu.openSettingsTitle.count, 30)
        XCTAssertLessThanOrEqual(menu.retryTitle.count, 30)
    }

    func testLocalizedPermissionTitles() {
        let granted = InputMonitoringPermissionMenu(status: .granted)
        let missing = InputMonitoringPermissionMenu(status: .missing)

        XCTAssertEqual(granted.statusTitle(languageCode: "en"), "Typing Reaction On")
        XCTAssertEqual(missing.statusTitle(languageCode: "en"), "Typing Permission Needed")
        XCTAssertEqual(missing.accessibilityTitle(languageCode: "en"), "Accessibility")
        XCTAssertEqual(missing.permissionStateTitle(granted: false, languageCode: "ko"), "허용 필요")
        XCTAssertEqual(missing.openAccessibilityTitle(languageCode: "zh"), "打开辅助功能")
        XCTAssertEqual(missing.openSettingsTitle(languageCode: "ja"), "入力監視を開く")
        XCTAssertEqual(missing.retryTitle(languageCode: "zh"), "重试输入反应")
    }
}
