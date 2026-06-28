import CoreGraphics
import Foundation

public enum CatDragGeometry {
    public static let defaultPinOffsetY: CGFloat = 4
    public static let dragStartDistance: CGFloat = 6
    public static let maxSwingAngle: CGFloat = 0.3
    public static let swingVelocityScale: CGFloat = 0.025
    public static let swingAccelerationScale: CGFloat = 0.012
    public static let idleSwayAmplitude: CGFloat = 0.026
    public static let idleSwayPeriod: TimeInterval = 0.58
    public static let idleWrigglePeriod: TimeInterval = 0.18
    public static let dragVelocityDecay: CGFloat = 0.82
    public static let maxDangleOffsetX: CGFloat = 12
    public static let walkGravity: CGFloat = 2_200
    public static let walkStepJumpPadding: CGFloat = 18
    public static let walkDropHopVelocity: CGFloat = 210

    public static func smoothedHorizontalVelocity(
        previous: CGFloat,
        previousMouseX: CGFloat,
        currentMouseX: CGFloat
    ) -> CGFloat {
        previous * 0.65 + (currentMouseX - previousMouseX) * 0.35
    }

    public static func hasDraggedBeyondStartDistance(from start: CGPoint, to current: CGPoint) -> Bool {
        hypot(current.x - start.x, current.y - start.y) > dragStartDistance
    }

    public static func swingAngle(for horizontalVelocity: CGFloat) -> CGFloat {
        clamp(-horizontalVelocity * swingVelocityScale, min: -maxSwingAngle, max: maxSwingAngle)
    }

    public static func smoothedHorizontalAcceleration(
        previous: CGFloat,
        previousVelocity: CGFloat,
        currentVelocity: CGFloat
    ) -> CGFloat {
        previous * 0.55 + (currentVelocity - previousVelocity) * 0.45
    }

    public static func decayedHorizontalVelocity(_ velocity: CGFloat) -> CGFloat {
        let decayed = velocity * dragVelocityDecay
        return abs(decayed) < 0.05 ? 0 : decayed
    }

    public static func dangleSwingAngle(horizontalVelocity: CGFloat, time: TimeInterval) -> CGFloat {
        dangleSwingAngle(horizontalVelocity: horizontalVelocity, horizontalAcceleration: 0, time: time)
    }

    public static func dangleSwingAngle(
        horizontalVelocity: CGFloat,
        horizontalAcceleration: CGFloat,
        time: TimeInterval
    ) -> CGFloat {
        if abs(horizontalVelocity) > 2.5 || abs(horizontalAcceleration) > 3 {
            let inertial = -horizontalVelocity * swingVelocityScale - horizontalAcceleration * swingAccelerationScale
            return clamp(inertial, min: -maxSwingAngle, max: maxSwingAngle)
        }
        let phase = (time / idleSwayPeriod) * 2 * Double.pi
        return CGFloat(sin(phase)) * idleSwayAmplitude
    }

    public static func dangleFrameIndex(horizontalVelocity: CGFloat, time: TimeInterval) -> Int {
        dangleFrameIndex(horizontalVelocity: horizontalVelocity, horizontalAcceleration: 0, time: time)
    }

    public static func dangleFrameIndex(
        horizontalVelocity: CGFloat,
        horizontalAcceleration: CGFloat,
        time: TimeInterval
    ) -> Int {
        if horizontalAcceleration > 3 { return 1 }
        if horizontalAcceleration < -3 { return 3 }
        if horizontalVelocity > 2.5 { return 1 }
        if horizontalVelocity < -2.5 { return 3 }
        return Int(floor(time / idleWrigglePeriod)).isMultiple(of: 2) ? 0 : 2
    }

    public static func dangleBodyOffset(
        horizontalVelocity: CGFloat,
        horizontalAcceleration: CGFloat,
        time: TimeInterval
    ) -> CGPoint {
        if abs(horizontalVelocity) > 2.5 || abs(horizontalAcceleration) > 2 {
            let inertial = -horizontalVelocity * 0.18 - horizontalAcceleration * 0.32
            return CGPoint(x: clamp(inertial, min: -maxDangleOffsetX, max: maxDangleOffsetX), y: 0)
        }
        let phase = (time / idleWrigglePeriod) * 2 * Double.pi
        let verticalPhase = (time / 0.21) * 2 * Double.pi
        return CGPoint(
            x: CGFloat(sin(phase)) * 0.8,
            y: abs(CGFloat(sin(verticalPhase))) * 3.2
        )
    }

    public static func topPinnedDragOrigin(pointer: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: pointer.x - size.width / 2,
            y: pointer.y - size.height + defaultPinOffsetY
        )
    }

    public static func landingDuration(drop: CGFloat) -> TimeInterval {
        min(0.45, max(0.12, TimeInterval(drop * 0.0006)))
    }

    public static func landingDistance(from originY: CGFloat, floorY: CGFloat) -> CGFloat {
        abs(originY - floorY)
    }

    public static func walkJumpVelocity(forHeightDelta heightDelta: CGFloat) -> CGFloat {
        sqrt(2 * walkGravity * max(0, heightDelta + walkStepJumpPadding))
    }

    public struct VerticalMotionStep: Equatable {
        public let originY: CGFloat
        public let verticalVelocity: CGFloat
        public let isGrounded: Bool
        public let didLaunch: Bool

        public init(
            originY: CGFloat,
            verticalVelocity: CGFloat,
            isGrounded: Bool,
            didLaunch: Bool
        ) {
            self.originY = originY
            self.verticalVelocity = verticalVelocity
            self.isGrounded = isGrounded
            self.didLaunch = didLaunch
        }
    }

    public static func walkVerticalMotionStep(
        originY: CGFloat,
        verticalVelocity: CGFloat,
        previousFloorY: CGFloat,
        targetFloorY: CGFloat,
        deltaTime: TimeInterval
    ) -> VerticalMotionStep {
        let dt = CGFloat(max(0, min(deltaTime, 1.0 / 20.0)))
        let wasGrounded = abs(originY - previousFloorY) <= 0.75 && abs(verticalVelocity) < 1
        var y = originY
        var velocity = verticalVelocity
        var didLaunch = false

        if wasGrounded {
            let floorDelta = targetFloorY - previousFloorY
            if floorDelta > 1 {
                velocity = walkJumpVelocity(forHeightDelta: floorDelta)
                didLaunch = true
            } else if floorDelta < -1 {
                velocity = walkDropHopVelocity
                didLaunch = true
            }
        }

        y += velocity * dt - 0.5 * walkGravity * dt * dt
        velocity -= walkGravity * dt

        if y <= targetFloorY && velocity <= 0 {
            return VerticalMotionStep(
                originY: targetFloorY,
                verticalVelocity: 0,
                isGrounded: true,
                didLaunch: didLaunch
            )
        }

        return VerticalMotionStep(
            originY: y,
            verticalVelocity: velocity,
            isGrounded: false,
            didLaunch: didLaunch
        )
    }

    public static func floorY(visibleFrame: CGRect, margin: CGFloat) -> CGFloat {
        visibleFrame.minY + margin
    }

    public static func supportFloorY(
        originX: CGFloat,
        size: CGSize,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockFrame: CGRect?,
        margin: CGFloat
    ) -> CGFloat {
        let screenFloor = screenFrame.minY + margin
        guard
            let dockFrame,
            dockFrame.height > 1,
            dockFrame.minY <= screenFrame.minY + margin + 1
        else {
            return screenFloor
        }

        let footRect = CGRect(
            x: originX + size.width * 0.28,
            y: dockFrame.minY,
            width: size.width * 0.44,
            height: dockFrame.height
        )
        if footRect.intersects(dockFrame.insetBy(dx: -margin, dy: 0)) {
            return dockFrame.maxY + margin
        }
        return screenFloor
    }

    public static func clampedOrigin(_ origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: clamp(origin.x, min: visibleFrame.minX, max: visibleFrame.maxX - size.width),
            y: clamp(origin.y, min: visibleFrame.minY, max: visibleFrame.maxY - size.height)
        )
    }

    public static func clampedDragOrigin(
        _ origin: CGPoint,
        size: CGSize,
        visibleFrame: CGRect,
        floorMargin: CGFloat
    ) -> CGPoint {
        let floor = floorY(visibleFrame: visibleFrame, margin: floorMargin)
        return CGPoint(
            x: clamp(origin.x, min: visibleFrame.minX, max: visibleFrame.maxX - size.width),
            y: clamp(origin.y, min: floor, max: visibleFrame.maxY - size.height)
        )
    }

    public static func clampedDragOrigin(
        _ origin: CGPoint,
        size: CGSize,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        dockFrame: CGRect?,
        floorMargin: CGFloat
    ) -> CGPoint {
        let x = clamp(origin.x, min: visibleFrame.minX, max: visibleFrame.maxX - size.width)
        let floor = supportFloorY(
            originX: x,
            size: size,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockFrame: dockFrame,
            margin: floorMargin
        )
        return CGPoint(
            x: x,
            y: clamp(origin.y, min: floor, max: visibleFrame.maxY - size.height)
        )
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(value, maximum))
    }
}
