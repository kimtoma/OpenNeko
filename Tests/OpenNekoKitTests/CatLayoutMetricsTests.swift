import XCTest
@testable import OpenNekoKit

final class CatLayoutMetricsTests: XCTestCase {
    func testPrimaryCatLayoutMatchesElectronRendererBaseline() {
        XCTAssertEqual(CatLayoutMetrics.primaryCatSize.width, 128)
        XCTAssertEqual(CatLayoutMetrics.primaryCatSize.height, 128)
        XCTAssertEqual(CatLayoutMetrics.floorPadding, 2)
    }

    func testGuestCatUsesSameGroundedSpriteFrame() {
        XCTAssertEqual(CatLayoutMetrics.guestCatSize, CatLayoutMetrics.primaryCatSize)
    }
}
