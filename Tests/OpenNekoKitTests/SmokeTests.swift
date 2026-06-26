import XCTest
@testable import OpenNekoKit

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(OpenNekoKit.version, "0.1.0")
    }
}
