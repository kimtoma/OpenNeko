import CoreGraphics
import Foundation

public struct ScreenPetCandidate: Equatable, Sendable {
    public let id: String
    public let ownerName: String
    public let windowName: String
    public let frame: CGRect

    public init(id: String, ownerName: String, windowName: String, frame: CGRect) {
        self.id = id
        self.ownerName = ownerName
        self.windowName = windowName
        self.frame = frame
    }
}

public struct ScreenPetApproachStep: Equatable, Sendable {
    public let origin: CGPoint
    public let direction: Int
    public let isContact: Bool

    public init(origin: CGPoint, direction: Int, isContact: Bool) {
        self.origin = origin
        self.direction = direction
        self.isContact = isContact
    }
}

public struct ScreenPetPunchSequence: Equatable, Sendable {
    public let punchCount: Int
    public let leadInDuration: TimeInterval
    public let frameDuration: TimeInterval
    public let recoveryDuration: TimeInterval
    public let settleDuration: TimeInterval

    public var singlePunchDuration: TimeInterval {
        frameDuration * 4
    }

    public var totalDuration: TimeInterval {
        leadInDuration
            + singlePunchDuration * Double(punchCount)
            + recoveryDuration * Double(max(0, punchCount - 1))
            + settleDuration
    }

    public static let `default` = ScreenPetPunchSequence(
        punchCount: 3,
        leadInDuration: 0.12,
        frameDuration: 0.16,
        recoveryDuration: 0.18,
        settleDuration: 0.18
    )
}

public enum ScreenPetEncounterPhase: Equatable, Sendable {
    case searching
    case approaching
    case punching
    case cooldown
}

public struct ScreenPetEncounterSession: Equatable, Sendable {
    public private(set) var phase: ScreenPetEncounterPhase = .searching
    public private(set) var target: ScreenPetCandidate?
    public private(set) var direction = 1
    public private(set) var phaseEndsAt: TimeInterval = 0

    public init() {}

    public var blocksAutonomousBehavior: Bool {
        phase == .approaching || phase == .punching
    }

    public var acceptsScanResults: Bool {
        phase == .searching || phase == .approaching
    }

    public mutating func lock(target: ScreenPetCandidate, relativeTo catFrame: CGRect) {
        self.target = target
        direction = target.frame.midX < catFrame.midX ? -1 : 1
        phase = .approaching
        phaseEndsAt = 0
    }

    public mutating func refreshTarget(_ target: ScreenPetCandidate, relativeTo catFrame: CGRect) {
        guard phase == .approaching else { return }
        lock(target: target, relativeTo: catFrame)
    }

    public mutating func beginPunching(at now: TimeInterval) {
        guard phase == .approaching else { return }
        phase = .punching
        phaseEndsAt = now + ScreenPetPunchSequence.default.totalDuration
    }

    public mutating func beginCooldown(at now: TimeInterval) {
        target = nil
        phase = .cooldown
        phaseEndsAt = now + ScreenPetEncounter.defaultPunchCooldown
    }

    public mutating func cancel() {
        self = ScreenPetEncounterSession()
    }

    public mutating func resetIfCooldownExpired(at now: TimeInterval) -> Bool {
        guard phase == .cooldown, now >= phaseEndsAt else { return false }
        self = ScreenPetEncounterSession()
        return true
    }
}

public struct ScreenPetScanTicket: Equatable, Sendable {
    fileprivate let requestID: Int
    fileprivate let resultGeneration: Int
}

public struct ScreenPetScanGate: Equatable, Sendable {
    public private(set) var isInFlight = false
    private var lastStartedAt = -TimeInterval.infinity
    private var nextRequestID = 0
    private var activeRequestID: Int?
    private var resultGeneration = 0

    public init() {}

    public mutating func beginScan(
        now: TimeInterval,
        minimumInterval: TimeInterval
    ) -> ScreenPetScanTicket? {
        guard !isInFlight, now - lastStartedAt >= minimumInterval else { return nil }
        nextRequestID &+= 1
        isInFlight = true
        activeRequestID = nextRequestID
        lastStartedAt = now
        return ScreenPetScanTicket(
            requestID: nextRequestID,
            resultGeneration: resultGeneration
        )
    }

    public mutating func finishScan(_ ticket: ScreenPetScanTicket) -> Bool {
        guard activeRequestID == ticket.requestID else { return false }
        isInFlight = false
        activeRequestID = nil
        return ticket.resultGeneration == resultGeneration
    }

    public mutating func invalidateResults() {
        resultGeneration &+= 1
    }
}

public struct ScreenPetPunchPresentation: Equatable, Sendable {
    public let size: CGSize
    public let position: CGPoint
    public let xScale: CGFloat
    public let yScale: CGFloat
    public let hidesBaseSprite: Bool
    public let displayDuration: TimeInterval

    public init(
        size: CGSize,
        position: CGPoint,
        xScale: CGFloat,
        yScale: CGFloat,
        hidesBaseSprite: Bool,
        displayDuration: TimeInterval
    ) {
        self.size = size
        self.position = position
        self.xScale = xScale
        self.yScale = yScale
        self.hidesBaseSprite = hidesBaseSprite
        self.displayDuration = displayDuration
    }

    public static func fullBody(catFrameSize: CGSize, direction: Int) -> ScreenPetPunchPresentation {
        ScreenPetPunchPresentation(
            size: CGSize(
                width: catFrameSize.width * 1.16,
                height: catFrameSize.height * 1.16
            ),
            position: CGPoint(
                x: catFrameSize.width / 2,
                y: catFrameSize.height / 2 - 12
            ),
            xScale: direction < 0 ? 1 : -1,
            yScale: 1,
            hidesBaseSprite: true,
            displayDuration: ScreenPetPunchSequence.default.totalDuration
        )
    }
}

public enum ScreenPetEncounter {
    public static let defaultContactDistance: CGFloat = 18
    public static let defaultPunchCooldown: TimeInterval = 4
    public static let defaultPunchInteractionDuration = ScreenPetPunchSequence.default.totalDuration
    public static let minimumPetWindowSide: CGFloat = 36
    public static let maximumPetWindowSide: CGFloat = 260

    public static func isCodexPetCandidate(_ candidate: ScreenPetCandidate) -> Bool {
        let signature = [candidate.id, candidate.ownerName, candidate.windowName]
            .joined(separator: " ")
            .lowercased()
        let hasCodex = signature.contains("codex")
        let hasPetSignal = signature.contains("pet")
            || signature.contains("neko")
            || signature.contains("cat")
            || signature.contains("buddy")
            || signature.contains("mascot")
            || signature.contains("codexbar")
        return hasCodex && hasPetSignal
    }

    public static func nearestCodexPetCandidate(
        to catFrame: CGRect,
        candidates: [ScreenPetCandidate]
    ) -> ScreenPetCandidate? {
        candidates
            .filter { isCodexPetCandidate($0) && isPetSized($0.frame) }
            .min { lhs, rhs in
                distance(from: catFrame, to: lhs.frame) < distance(from: catFrame, to: rhs.frame)
            }
    }

    public static func shouldUseWindowCandidates(
        _ candidates: [ScreenPetCandidate],
        lockedTarget: ScreenPetCandidate?
    ) -> Bool {
        guard !candidates.isEmpty else { return false }
        guard let lockedTarget else { return true }
        guard !lockedTarget.id.hasPrefix("screen-pixels-") else { return true }
        return candidates.contains { $0.id == lockedTarget.id }
    }

    public static func refreshedCandidate(
        matching locked: ScreenPetCandidate,
        candidates: [ScreenPetCandidate]
    ) -> ScreenPetCandidate? {
        let validCandidates = candidates.filter {
            isCodexPetCandidate($0) && isPetSized($0.frame)
        }
        let lockedIsPixelCandidate = locked.id.hasPrefix("screen-pixels-")
        if !lockedIsPixelCandidate,
           let exactMatch = validCandidates.first(where: { $0.id == locked.id }) {
            return exactMatch
        }

        let maximumDrift = max(locked.frame.width, locked.frame.height) * 1.5
        let refreshCandidates = validCandidates.filter { candidate in
            lockedIsPixelCandidate || candidate.id.hasPrefix("screen-pixels-")
        }
        guard let nearest = refreshCandidates.min(by: {
                distance(from: locked.frame, to: $0.frame)
                    < distance(from: locked.frame, to: $1.frame)
            }),
            distance(from: locked.frame, to: nearest.frame) <= maximumDrift
        else {
            return nil
        }
        return nearest
    }

    public static func approachStep(
        catFrame: CGRect,
        targetFrame: CGRect,
        visibleFrame: CGRect,
        maxDistance: CGFloat
    ) -> ScreenPetApproachStep {
        let targetIsRight = targetFrame.midX >= catFrame.midX
        let destinationX = targetIsRight
            ? targetFrame.minX - catFrame.width + defaultContactDistance
            : targetFrame.maxX - defaultContactDistance
        let clampedDestinationX = clamp(
            destinationX,
            min: visibleFrame.minX,
            max: visibleFrame.maxX - catFrame.width
        )
        let deltaX = clampedDestinationX - catFrame.minX
        let limitedDeltaX: CGFloat
        if abs(deltaX) <= maxDistance {
            limitedDeltaX = deltaX
        } else {
            limitedDeltaX = deltaX > 0 ? maxDistance : -maxDistance
        }
        let origin = CGPoint(x: catFrame.minX + limitedDeltaX, y: catFrame.minY)
        let direction = deltaX < 0 ? -1 : 1
        return ScreenPetApproachStep(
            origin: origin,
            direction: direction,
            isContact: isContact(catFrame: catFrame, targetFrame: targetFrame)
        )
    }

    private static func isPetSized(_ frame: CGRect) -> Bool {
        frame.width >= minimumPetWindowSide
            && frame.height >= minimumPetWindowSide
            && frame.width <= maximumPetWindowSide
            && frame.height <= maximumPetWindowSide
    }

    private static func distance(from catFrame: CGRect, to targetFrame: CGRect) -> CGFloat {
        hypot(catFrame.midX - targetFrame.midX, catFrame.midY - targetFrame.midY)
    }

    private static func isContact(catFrame: CGRect, targetFrame: CGRect) -> Bool {
        let horizontallyClose: Bool
        if catFrame.maxX < targetFrame.minX {
            horizontallyClose = targetFrame.minX - catFrame.maxX <= defaultContactDistance
        } else if targetFrame.maxX < catFrame.minX {
            horizontallyClose = catFrame.minX - targetFrame.maxX <= defaultContactDistance
        } else {
            horizontallyClose = true
        }
        let verticalOverlap = catFrame.minY < targetFrame.maxY && targetFrame.minY < catFrame.maxY
        return horizontallyClose && verticalOverlap
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(value, maximum))
    }
}
