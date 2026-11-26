import XCTest
@testable import OpenNekoKit

final class CatAutonomousBehaviorTests: XCTestCase {
    func testNoActionWhenCatIsBusy() {
        let context = CatAutonomousContext(
            uptime: 10_000,
            hour: 12,
            lastInteraction: 0,
            nextAutoEffect: 0,
            lunchAlreadyShown: false,
            leaveWorkAlreadyShown: false,
            isAvailable: false,
            healthNudge: .stretch
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: context, randomValue: 0), .none)
    }

    func testDueHealthNudgeTakesPriority() {
        let context = availableContext(
            uptime: CatAutonomousBehavior.napAfter + 1,
            hour: CatAutonomousBehavior.lunchHour,
            lastInteraction: 0,
            healthNudge: .water
        )

        XCTAssertEqual(CatAutonomousBehavior.action(for: context, randomValue: 0), .healthNudge(.water))
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
        nextAutoEffect: TimeInterval = .greatestFiniteMagnitude,
        lunchAlreadyShown: Bool = false,
        leaveWorkAlreadyShown: Bool = false,
        healthNudge: HealthNudgeKind? = nil
    ) -> CatAutonomousContext {
        CatAutonomousContext(
            uptime: uptime,
            hour: hour,
            lastInteraction: lastInteraction,
            nextAutoEffect: nextAutoEffect,
            lunchAlreadyShown: lunchAlreadyShown,
            leaveWorkAlreadyShown: leaveWorkAlreadyShown,
            isAvailable: true,
            healthNudge: healthNudge
        )
    }
}
