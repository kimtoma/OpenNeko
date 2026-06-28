import XCTest
@testable import OpenNekoKit

final class CatDragGeometryTests: XCTestCase {
    func testHorizontalVelocityUsesElectronSmoothing() {
        let velocity = CatDragGeometry.smoothedHorizontalVelocity(
            previous: 10,
            previousMouseX: 100,
            currentMouseX: 120
        )

        XCTAssertEqual(velocity, 13.5, accuracy: 0.0001)
    }

    func testDragStartsOnlyAfterElectronThreshold() {
        let start = CGPoint(x: 10, y: 20)

        XCTAssertFalse(CatDragGeometry.hasDraggedBeyondStartDistance(
            from: start,
            to: CGPoint(x: 13, y: 24)
        ))
        XCTAssertFalse(CatDragGeometry.hasDraggedBeyondStartDistance(
            from: start,
            to: CGPoint(x: 16, y: 20)
        ))
        XCTAssertTrue(CatDragGeometry.hasDraggedBeyondStartDistance(
            from: start,
            to: CGPoint(x: 17, y: 20)
        ))
    }

    func testSwingAngleIsClamped() {
        XCTAssertEqual(CatDragGeometry.swingAngle(for: 4), -0.1, accuracy: 0.0001)
        XCTAssertEqual(CatDragGeometry.swingAngle(for: 100), -0.3, accuracy: 0.0001)
        XCTAssertEqual(CatDragGeometry.swingAngle(for: -100), 0.3, accuracy: 0.0001)
    }

    func testDangleSwingSwaysWhenHeldStill() {
        XCTAssertEqual(CatDragGeometry.dangleSwingAngle(horizontalVelocity: 0, time: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(
            CatDragGeometry.dangleSwingAngle(
                horizontalVelocity: 0,
                time: CatDragGeometry.idleSwayPeriod / 4
            ),
            CatDragGeometry.idleSwayAmplitude,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CatDragGeometry.dangleSwingAngle(
                horizontalVelocity: 0,
                time: CatDragGeometry.idleSwayPeriod * 3 / 4
            ),
            -CatDragGeometry.idleSwayAmplitude,
            accuracy: 0.0001
        )
    }

    func testDangleSwingUsesDragVelocityWhenMovingSideways() {
        XCTAssertEqual(
            CatDragGeometry.dangleSwingAngle(horizontalVelocity: 4, time: CatDragGeometry.idleSwayPeriod / 4),
            CatDragGeometry.swingAngle(for: 4),
            accuracy: 0.0001
        )
    }

    func testDragVelocityDecaysTowardHeldStillMotion() {
        XCTAssertEqual(CatDragGeometry.decayedHorizontalVelocity(10), 8.2, accuracy: 0.0001)
        XCTAssertEqual(CatDragGeometry.decayedHorizontalVelocity(0.04), 0, accuracy: 0.0001)
    }

    func testDangleSwingRespondsToAcceleration() {
        let accelerated = CatDragGeometry.dangleSwingAngle(
            horizontalVelocity: 4,
            horizontalAcceleration: 5,
            time: 0
        )

        XCTAssertLessThan(accelerated, CatDragGeometry.swingAngle(for: 4))
    }

    func testDangleBodyLagsOppositeMouseAcceleration() {
        let offset = CatDragGeometry.dangleBodyOffset(
            horizontalVelocity: 2,
            horizontalAcceleration: 6,
            time: 0
        )

        XCTAssertLessThan(offset.x, 0)
        XCTAssertEqual(offset.y, 0)
    }

    func testHeldStillDragWrigglesMostlyInPlace() {
        let offset = CatDragGeometry.dangleBodyOffset(
            horizontalVelocity: 0,
            horizontalAcceleration: 0,
            time: CatDragGeometry.idleWrigglePeriod / 4
        )

        XCTAssertLessThanOrEqual(abs(offset.x), 1)
        XCTAssertGreaterThan(offset.y, 2)
    }

    func testDangleFrameFollowsDragDirectionAndIdlePulse() {
        XCTAssertEqual(CatDragGeometry.dangleFrameIndex(horizontalVelocity: 3, time: 0), 1)
        XCTAssertEqual(CatDragGeometry.dangleFrameIndex(horizontalVelocity: -3, time: 0), 3)
        XCTAssertEqual(CatDragGeometry.dangleFrameIndex(horizontalVelocity: 0, time: 0.1), 0)
        XCTAssertEqual(CatDragGeometry.dangleFrameIndex(horizontalVelocity: 0, time: 0.2), 2)
    }

    func testTopPinnedDragOriginHangsCatBelowPointer() {
        let size = CGSize(width: 160, height: 160)
        let pointer = CGPoint(x: 200, y: 300)
        let origin = CatDragGeometry.topPinnedDragOrigin(pointer: pointer, size: size)

        XCTAssertEqual(origin.x, 120)
        XCTAssertEqual(origin.y, 144)
        XCTAssertEqual(origin.y + size.height - CatDragGeometry.defaultPinOffsetY, pointer.y)
    }

    func testLandingDurationMatchesOriginalClamp() {
        XCTAssertEqual(CatDragGeometry.landingDuration(drop: 10), 0.12, accuracy: 0.0001)
        XCTAssertEqual(CatDragGeometry.landingDuration(drop: 300), 0.18, accuracy: 0.0001)
        XCTAssertEqual(CatDragGeometry.landingDuration(drop: 1_000), 0.45, accuracy: 0.0001)
    }

    func testLandingDistanceUsesAbsoluteFloorDelta() {
        XCTAssertEqual(CatDragGeometry.landingDistance(from: 124, floorY: 24), 100)
        XCTAssertEqual(CatDragGeometry.landingDistance(from: 4, floorY: 24), 20)
    }

    func testWalkVerticalMotionLaunchesUpToHigherDockFloor() {
        let step = CatDragGeometry.walkVerticalMotionStep(
            originY: 2,
            verticalVelocity: 0,
            previousFloorY: 2,
            targetFloorY: 82,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertTrue(step.didLaunch)
        XCTAssertFalse(step.isGrounded)
        XCTAssertGreaterThan(step.originY, 2)
        XCTAssertGreaterThan(step.verticalVelocity, 0)
    }

    func testWalkVerticalMotionHopsBeforeDroppingOffDock() {
        let step = CatDragGeometry.walkVerticalMotionStep(
            originY: 82,
            verticalVelocity: 0,
            previousFloorY: 82,
            targetFloorY: 2,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertTrue(step.didLaunch)
        XCTAssertFalse(step.isGrounded)
        XCTAssertGreaterThan(step.originY, 82)
    }

    func testWalkVerticalMotionLandsOnTargetFloor() {
        let step = CatDragGeometry.walkVerticalMotionStep(
            originY: 4,
            verticalVelocity: -200,
            previousFloorY: 82,
            targetFloorY: 2,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertFalse(step.didLaunch)
        XCTAssertTrue(step.isGrounded)
        XCTAssertEqual(step.originY, 2)
        XCTAssertEqual(step.verticalVelocity, 0)
    }

    func testClampedDragOriginKeepsCatOnFloor() {
        let visible = CGRect(x: 10, y: 20, width: 500, height: 300)
        let origin = CatDragGeometry.clampedDragOrigin(
            CGPoint(x: -100, y: -100),
            size: CGSize(width: 160, height: 160),
            visibleFrame: visible,
            floorMargin: 24
        )

        XCTAssertEqual(origin.x, 10)
        XCTAssertEqual(origin.y, 44)
    }

    func testSupportFloorUsesDockOnlyWhenCatIsOverDock() {
        let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let visible = CGRect(x: 0, y: 80, width: 1_000, height: 720)
        let dock = CGRect(x: 360, y: 0, width: 280, height: 80)
        let size = CGSize(width: 128, height: 128)

        XCTAssertEqual(
            CatDragGeometry.supportFloorY(
                originX: 430,
                size: size,
                screenFrame: screen,
                visibleFrame: visible,
                dockFrame: dock,
                margin: 2
            ),
            82
        )
        XCTAssertEqual(
            CatDragGeometry.supportFloorY(
                originX: 760,
                size: size,
                screenFrame: screen,
                visibleFrame: visible,
                dockFrame: dock,
                margin: 2
            ),
            2
        )
    }

    func testSupportFloorFallsToScreenBottomWithoutDock() {
        let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let visible = CGRect(x: 0, y: 80, width: 1_000, height: 720)

        XCTAssertEqual(
            CatDragGeometry.supportFloorY(
                originX: 430,
                size: CGSize(width: 128, height: 128),
                screenFrame: screen,
                visibleFrame: visible,
                dockFrame: nil,
                margin: 2
            ),
            2
        )
    }

    func testClampedDragOriginUsesDockSupportFloor() {
        let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let visible = CGRect(x: 0, y: 80, width: 1_000, height: 720)
        let dock = CGRect(x: 360, y: 0, width: 280, height: 80)
        let size = CGSize(width: 128, height: 128)

        let overDock = CatDragGeometry.clampedDragOrigin(
            CGPoint(x: 420, y: -50),
            size: size,
            screenFrame: screen,
            visibleFrame: visible,
            dockFrame: dock,
            floorMargin: 2
        )
        let outsideDock = CatDragGeometry.clampedDragOrigin(
            CGPoint(x: 760, y: -50),
            size: size,
            screenFrame: screen,
            visibleFrame: visible,
            dockFrame: dock,
            floorMargin: 2
        )

        XCTAssertEqual(overDock.y, 82)
        XCTAssertEqual(outsideDock.y, 2)
    }
}
