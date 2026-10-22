import XCTest
@testable import OpenNekoKit

final class CatAutonomousDecisionCadenceTests: XCTestCase {
    func testFirstDecisionIsImmediateAndSubsequentDecisionsWaitForInterval() {
        var cadence = CatAutonomousDecisionCadence()

        XCTAssertTrue(cadence.shouldEvaluate(at: 500))
        XCTAssertFalse(cadence.shouldEvaluate(at: 500 + 1.0 / 60))
        XCTAssertFalse(cadence.shouldEvaluate(at: 500.249))
        XCTAssertTrue(cadence.shouldEvaluate(at: 500.25))
        XCTAssertFalse(cadence.shouldEvaluate(at: 500.25))
    }

    func testSixtyHertzClockEvaluatesFortyDecisionsInTenSeconds() {
        var cadence = CatAutonomousDecisionCadence()
        var decisionCount = 0
        for frame in 0..<600 {
            if cadence.shouldEvaluate(at: TimeInterval(frame) / 60) {
                decisionCount += 1
            }
        }

        XCTAssertEqual(decisionCount, 40)
    }

    func testDelayedClockDoesNotReplayMissedDecisions() {
        var cadence = CatAutonomousDecisionCadence()
        XCTAssertTrue(cadence.shouldEvaluate(at: 10))

        XCTAssertTrue(cadence.shouldEvaluate(at: 1_000))
        XCTAssertFalse(cadence.shouldEvaluate(at: 1_000 + 1.0 / 60))
        XCTAssertTrue(cadence.shouldEvaluate(at: 1_000.25))
    }

    func testNapThresholdIsObservedByNextDecision() {
        var cadence = CatAutonomousDecisionCadence()
        let threshold = CatAutonomousBehavior.napAfter
        var actions: [CatAutonomousAction] = []
        for frame in 0...15 {
            let now = threshold + TimeInterval(frame) / 60
            guard cadence.shouldEvaluate(at: now) else { continue }
            actions.append(CatAutonomousBehavior.action(
                for: CatAutonomousContext(
                    uptime: now,
                    hour: 10,
                    lastInteraction: 0,
                    lastStretch: 0,
                    nextAutoEffect: .infinity,
                    lunchAlreadyShown: false,
                    leaveWorkAlreadyShown: false,
                    isAvailable: true
                ),
                randomValue: 0
            ))
        }

        XCTAssertEqual(actions, [.none, .nap])
    }
}
