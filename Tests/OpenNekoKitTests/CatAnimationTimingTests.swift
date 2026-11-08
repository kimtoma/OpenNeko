import XCTest
@testable import OpenNekoKit

final class CatAnimationTimingTests: XCTestCase {
    func testFastStatesShareFrameTime() {
        for state in [CatState.typing, .click, .success, .jump] {
            XCTAssertEqual(CatAnimationTiming.timePerFrame(for: state), 0.125)
        }
    }

    func testDistinctStateTimings() {
        XCTAssertEqual(CatAnimationTiming.timePerFrame(for: .walk), 0.12)
        XCTAssertEqual(CatAnimationTiming.timePerFrame(for: .nap), 0.4)
        XCTAssertEqual(CatAnimationTiming.timePerFrame(for: .thinking), 0.2)
    }

    func testDefaultTimingForAmbientStates() {
        for state in [CatState.idle, .hover, .coding, .lunch, .yawn, .error, .dragging] {
            XCTAssertEqual(CatAnimationTiming.timePerFrame(for: state), 0.18)
        }
    }

    func testTypingSpeedClampedToReadableRange() {
        XCTAssertEqual(CatAnimationTiming.clampedTypingSpeed(0.1), 0.8)
        XCTAssertEqual(CatAnimationTiming.clampedTypingSpeed(1.0), 1.0)
        XCTAssertEqual(CatAnimationTiming.clampedTypingSpeed(5.0), 1.8)
    }
}
