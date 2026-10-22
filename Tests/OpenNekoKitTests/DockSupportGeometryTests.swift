import XCTest
@testable import OpenNekoKit

final class DockSupportGeometryTests: XCTestCase {
    func testPreferenceSnapshotLoadsOncePerSecondDuringSixtyHertzMotion() {
        var cache = DockSupportPreferenceCache()
        var loadCount = 0
        for frame in 0..<600 {
            _ = cache.preferences(at: TimeInterval(frame) / 60) {
                loadCount += 1
                return DockSupportPreferences()
            }
        }

        XCTAssertEqual(loadCount, 10)
    }

    func testPreferenceChangesBecomeVisibleAtExpiry() {
        var cache = DockSupportPreferenceCache()
        let original = DockSupportPreferences(orientation: "bottom")
        let changed = DockSupportPreferences(orientation: "left")

        XCTAssertEqual(cache.preferences(at: 5) { original }, original)
        XCTAssertEqual(cache.preferences(at: 5.999) { changed }, original)
        XCTAssertEqual(cache.preferences(at: 6) { changed }, changed)
    }

    func testVisibleFrameChangesAreImmediateWithoutReloadingPreferences() throws {
        var cache = DockSupportPreferenceCache()
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let preferences = cache.preferences(at: 1) { DockSupportPreferences() }
        let dock = try XCTUnwrap(preferences.frame(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 70, width: 1_440, height: 805)
        ))

        let stillCached = cache.preferences(at: 1.1) {
            XCTFail("A geometry update must not reload Dock preferences")
            return DockSupportPreferences()
        }
        XCTAssertEqual(dock.height, 70)
        XCTAssertNil(stillCached.frame(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 875)
        ))
    }

    func testCachedPreferencesUseEachDisplaysLiveOriginAndSize() throws {
        let preferences = DockSupportPreferences()
        let primary = try XCTUnwrap(preferences.frame(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_440, height: 805)
        ))
        let secondary = try XCTUnwrap(preferences.frame(
            screenFrame: CGRect(x: -900, y: -120, width: 900, height: 600),
            visibleFrame: CGRect(x: -900, y: -60, width: 900, height: 515)
        ))

        XCTAssertEqual(primary.midX, 720)
        XCTAssertEqual(secondary.midX, -450)
        XCTAssertEqual(secondary.minY, -120)
        XCTAssertEqual(secondary.height, 60)
    }

    func testWidthRetainsExistingDockPreferenceEstimateAndScreenClamp() throws {
        let preferences = DockSupportPreferences(
            tileSize: 60,
            appCount: 10,
            otherCount: 2,
            showRecents: false
        )
        let wide = try XCTUnwrap(preferences.frame(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_440, height: 805)
        ))
        let narrow = try XCTUnwrap(preferences.frame(
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 500, height: 805)
        ))

        XCTAssertEqual(wide.width, 667.4, accuracy: 0.0001)
        XCTAssertEqual(narrow.width, 460)
    }
}
