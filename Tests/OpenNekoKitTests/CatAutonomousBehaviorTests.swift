import XCTest
@testable import OpenNekoKit

final class CatAutonomousBehaviorTests: XCTestCase {
    func testNoActionWhenCatIsBusy() {
        let context = CatAutonomousContext(
            uptime: 10_000,
            hour: 12,
            lastInteraction: 0,
            lastStretch: 0,
            nextAutoEffect: 0,
            lunchAlreadyShown: false,
            leaveWorkAlreadyShown: false,
            isAvailable: false
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: context, randomValue: 0), .none)
    }

    func testStretchTakesPriorityAfterInterval() {
        let context = availableContext(
            uptime: CatAutonomousBehavior.stretchInterval + 1,
            hour: 12,
            lastInteraction: 0,
            lastStretch: 0
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: context, randomValue: 0), .stretch)
    }

    func testLunchRunsOnceAtLunchHour() {
        let first = availableContext(uptime: 100, hour: CatAutonomousBehavior.lunchHour)
        let alreadyShown = availableContext(
            uptime: 100,
            hour: CatAutonomousBehavior.lunchHour,
            lunchAlreadyShown: true
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: first, randomValue: 0), .lunch)
        XCTAssertNotEqual(CatAutonomousBehavior.action(for: alreadyShown, randomValue: 0), .lunch)
    }

    func testLeaveWorkRunsOnceAtLeaveWorkHour() {
        let first = availableContext(uptime: 100, hour: CatAutonomousBehavior.leaveWorkHour)
        let alreadyShown = availableContext(
            uptime: 100,
            hour: CatAutonomousBehavior.leaveWorkHour,
            leaveWorkAlreadyShown: true
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: first, randomValue: 0), .leaveWork)
        XCTAssertNotEqual(CatAutonomousBehavior.action(for: alreadyShown, randomValue: 0), .leaveWork)
    }

    func testNapAfterIdleTimeout() {
        let context = availableContext(
            uptime: CatAutonomousBehavior.napAfter + 1,
            hour: 10,
            lastInteraction: 0
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: context, randomValue: 0), .nap)
    }

    func testAutoEffectChoosesYawnOrJump() {
        let yawn = availableContext(uptime: 31, hour: 10, nextAutoEffect: 30)
        let jump = availableContext(uptime: 31, hour: 10, nextAutoEffect: 30)

        XCTAssertEqual(CatAutonomousBehavior.action(for: yawn, randomValue: 0.1), .yawn)
        XCTAssertEqual(CatAutonomousBehavior.action(for: jump, randomValue: 0.9), .jump)
    }

    private func availableContext(
        uptime: TimeInterval,
        hour: Int,
        lastInteraction: TimeInterval = 0,
        lastStretch: TimeInterval = 0,
        nextAutoEffect: TimeInterval = .greatestFiniteMagnitude,
        lunchAlreadyShown: Bool = false,
        leaveWorkAlreadyShown: Bool = false
    ) -> CatAutonomousContext {
        CatAutonomousContext(
            uptime: uptime,
            hour: hour,
            lastInteraction: lastInteraction,
            lastStretch: lastStretch,
            nextAutoEffect: nextAutoEffect,
            lunchAlreadyShown: lunchAlreadyShown,
            leaveWorkAlreadyShown: leaveWorkAlreadyShown,
            isAvailable: true
        )
    }
}
