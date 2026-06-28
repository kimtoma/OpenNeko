import XCTest
@testable import OpenNekoKit

final class SettingsGlassStyleTests: XCTestCase {
    func testSettingsWindowUsesCompactDesktopLayout() {
        XCTAssertEqual(SettingsGlassStyle.windowWidth, 780)
        XCTAssertEqual(SettingsGlassStyle.windowHeight, 540)
    }

    func testSettingsPanelMetricsStayCompactForDesktopSettings() {
        XCTAssertLessThanOrEqual(SettingsGlassStyle.panelCornerRadius, 22)
        XCTAssertGreaterThanOrEqual(SettingsGlassStyle.rowCornerRadius, 12)
        XCTAssertLessThan(SettingsGlassStyle.rowCornerRadius, SettingsGlassStyle.panelCornerRadius)
    }

    func testSettingsStyleUsesNativeSettingsTerminology() {
        XCTAssertEqual(SettingsGlassStyle.designName, "macOS Settings")
    }
}
