import XCTest
@testable import OpenNekoKit

final class TypingPulseDetectorTests: XCTestCase {
    func testPrimePreventsStartupPulseFromRecentKeyDown() {
        var detector = TypingPulseDetector()
        detector.prime(keyDownAge: 0.02)

        XCTAssertFalse(detector.sample(keyDownAge: 0.03, at: 10.0))
    }

    func testAgeDropReportsNewKeyPulse() {
        var detector = TypingPulseDetector()
        detector.prime(keyDownAge: 0.12)

        XCTAssertTrue(detector.sample(keyDownAge: 0.01, at: 10.0))
    }

    func testSameKeyPulseIsNotRepeatedWhileAgeRises() {
        var detector = TypingPulseDetector()
        detector.prime(keyDownAge: 0.12)

        XCTAssertTrue(detector.sample(keyDownAge: 0.01, at: 10.0))
        XCTAssertFalse(detector.sample(keyDownAge: 0.06, at: 10.05))
        XCTAssertFalse(detector.sample(keyDownAge: 0.11, at: 10.10))
    }

    func testNewPulseAfterIdleWindow() {
        var detector = TypingPulseDetector(activeWindow: 0.16)
        detector.prime(keyDownAge: 0.20)

        XCTAssertTrue(detector.sample(keyDownAge: 0.02, at: 10.0))
    }

    func testMinimumPulseIntervalFiltersUnrealisticDoubleReports() {
        var detector = TypingPulseDetector(minimumPulseInterval: 0.06)
        detector.prime(keyDownAge: 0.20)

        XCTAssertTrue(detector.sample(keyDownAge: 0.01, at: 10.0))
        XCTAssertFalse(detector.sample(keyDownAge: 0.00, at: 10.03))
    }
}
