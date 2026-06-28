import XCTest
@testable import OpenNekoKit

final class TypingActivityTrackerTests: XCTestCase {
    func testKeyDownStartsTypingAndReportsChange() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)

        let changed = tracker.keyDown(at: 10.0)

        XCTAssertTrue(changed)
        XCTAssertTrue(tracker.isTyping)
    }

    func testTickBeforeIdleDelayKeepsTyping() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)

        let changed = tracker.tick(at: 10.7)

        XCTAssertFalse(changed)
        XCTAssertTrue(tracker.isTyping)
    }

    func testTickAfterIdleDelayStopsTypingAndReportsChange() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)

        let changed = tracker.tick(at: 10.8)

        XCTAssertTrue(changed)
        XCTAssertFalse(tracker.isTyping)
    }

    func testRepeatedKeyDownExtendsTypingWindow() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)
        tracker.keyDown(at: 10.5)

        XCTAssertFalse(tracker.tick(at: 11.2))
        XCTAssertTrue(tracker.isTyping)
        XCTAssertTrue(tracker.tick(at: 11.3))
        XCTAssertFalse(tracker.isTyping)
    }

    func testNextIdleDelayUsesRemainingTime() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)

        XCTAssertEqual(tracker.nextIdleCheckDelay(at: 10.3), 0.5, accuracy: 0.0001)
        XCTAssertEqual(tracker.nextIdleCheckDelay(at: 10.9), 0.0, accuracy: 0.0001)
    }

    func testFastRepeatedKeyDownRaisesAnimationSpeed() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)

        tracker.keyDown(at: 10.09)

        XCTAssertGreaterThan(tracker.animationSpeed, 1.3)
        XCTAssertLessThanOrEqual(tracker.animationSpeed, 1.8)
    }

    func testSlowRepeatedKeyDownLowersAnimationSpeed() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)

        tracker.keyDown(at: 10.65)

        XCTAssertLessThan(tracker.animationSpeed, 1.0)
        XCTAssertGreaterThanOrEqual(tracker.animationSpeed, 0.8)
    }

    func testTypingSpeedDeceleratesSmoothlyWhenCadenceSlows() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)
        tracker.keyDown(at: 10.09)
        let fastSpeed = tracker.animationSpeed

        tracker.keyDown(at: 10.70)

        XCTAssertLessThan(tracker.animationSpeed, fastSpeed)
        XCTAssertGreaterThan(tracker.animationSpeed, 1.0)
    }

    func testIdleResetReturnsAnimationSpeedToNeutral() {
        var tracker = TypingActivityTracker(idleDelay: 0.8)
        tracker.keyDown(at: 10.0)
        tracker.keyDown(at: 10.09)

        XCTAssertTrue(tracker.tick(at: 10.89))

        XCTAssertEqual(tracker.animationSpeed, 1.0, accuracy: 0.0001)
    }
}
