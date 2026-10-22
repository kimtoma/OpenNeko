import XCTest
@testable import OpenNekoKit

final class ScreenPetEncounterTests: XCTestCase {
    func testCodexPetCandidateRequiresCodexAndPetSignature() {
        let codexPet = ScreenPetCandidate(
            id: "window-1",
            ownerName: "Codex",
            windowName: "Desktop Pet",
            frame: CGRect(x: 500, y: 20, width: 96, height: 96)
        )
        let codexEditor = ScreenPetCandidate(
            id: "window-2",
            ownerName: "Codex",
            windowName: "Task",
            frame: CGRect(x: 40, y: 80, width: 900, height: 700)
        )
        let regularPet = ScreenPetCandidate(
            id: "window-3",
            ownerName: "Desk Pet",
            windowName: "Buddy",
            frame: CGRect(x: 300, y: 20, width: 96, height: 96)
        )

        XCTAssertTrue(ScreenPetEncounter.isCodexPetCandidate(codexPet))
        XCTAssertFalse(ScreenPetEncounter.isCodexPetCandidate(codexEditor))
        XCTAssertFalse(ScreenPetEncounter.isCodexPetCandidate(regularPet))
    }

    func testNearestCodexPetCandidateIgnoresLargeWindowsAndChoosesClosest() {
        let catFrame = CGRect(x: 100, y: 2, width: 128, height: 128)
        let farPet = ScreenPetCandidate(
            id: "far",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 760, y: 2, width: 96, height: 96)
        )
        let largeCodexWindow = ScreenPetCandidate(
            id: "large",
            ownerName: "Codex",
            windowName: "Desktop Pet",
            frame: CGRect(x: 0, y: 0, width: 900, height: 700)
        )
        let nearPet = ScreenPetCandidate(
            id: "near",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 360, y: 2, width: 96, height: 96)
        )

        let match = ScreenPetEncounter.nearestCodexPetCandidate(
            to: catFrame,
            candidates: [farPet, largeCodexWindow, nearPet]
        )

        XCTAssertEqual(match?.id, "near")
    }

    func testApproachStepMovesTowardPetAndReportsContactOnlyWhenClose() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let targetFrame = CGRect(x: 420, y: 2, width: 96, height: 96)
        let farStep = ScreenPetEncounter.approachStep(
            catFrame: CGRect(x: 100, y: 2, width: 128, height: 128),
            targetFrame: targetFrame,
            visibleFrame: visibleFrame,
            maxDistance: 40
        )
        let closeStep = ScreenPetEncounter.approachStep(
            catFrame: CGRect(x: 286, y: 2, width: 128, height: 128),
            targetFrame: targetFrame,
            visibleFrame: visibleFrame,
            maxDistance: 40
        )

        XCTAssertEqual(farStep.origin.x, 140)
        XCTAssertEqual(farStep.direction, 1)
        XCTAssertFalse(farStep.isContact)
        XCTAssertTrue(closeStep.isContact)
    }

    func testPixelDetectorFindsCodexMascotBlueBlobInScreenCapture() {
        let width = 220
        let height = 180
        let mascotBlue = ScreenPetPixel(red: 87, green: 138, blue: 255, alpha: 255)
        let darkBackground = ScreenPetPixel(red: 18, green: 18, blue: 20, alpha: 255)
        var pixels = Array(repeating: darkBackground, count: width * height)

        for y in 42..<132 {
            for x in 78..<172 {
                pixels[y * width + x] = mascotBlue
            }
        }
        for y in 10..<28 {
            for x in 14..<62 {
                pixels[y * width + x] = mascotBlue
            }
        }

        let candidates = ScreenPetPixelDetector.candidates(
            imageWidth: width,
            imageHeight: height,
            imageFrame: CGRect(x: 0, y: 0, width: width, height: height),
            pixelAt: { x, y in pixels[y * width + x] }
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(ScreenPetEncounter.isCodexPetCandidate(candidates[0]))
        XCTAssertEqual(candidates[0].frame, CGRect(x: 78, y: 48, width: 94, height: 90))
    }

    func testPixelDetectorIgnoresExcludedCatFrame() {
        let width = 260
        let height = 180
        let mascotBlue = ScreenPetPixel(red: 75, green: 128, blue: 245, alpha: 255)
        let background = ScreenPetPixel(red: 12, green: 12, blue: 14, alpha: 255)
        var pixels = Array(repeating: background, count: width * height)

        for y in 36..<126 {
            for x in 36..<126 {
                pixels[y * width + x] = mascotBlue
            }
        }
        for y in 40..<130 {
            for x in 154..<244 {
                pixels[y * width + x] = mascotBlue
            }
        }

        let candidates = ScreenPetPixelDetector.candidates(
            imageWidth: width,
            imageHeight: height,
            imageFrame: CGRect(x: 0, y: 0, width: width, height: height),
            excludedFrames: [CGRect(x: 30, y: 48, width: 104, height: 104)],
            pixelAt: { x, y in pixels[y * width + x] }
        )

        XCTAssertEqual(candidates.map(\.frame), [
            CGRect(x: 154, y: 50, width: 90, height: 90)
        ])
    }

    func testPunchPresentationMatchesWalkScaleFloorAndTargetDirection() {
        let leftPunch = ScreenPetPunchPresentation.fullBody(
            catFrameSize: CGSize(width: 128, height: 128),
            direction: -1
        )
        let rightPunch = ScreenPetPunchPresentation.fullBody(
            catFrameSize: CGSize(width: 128, height: 128),
            direction: 1
        )

        XCTAssertEqual(leftPunch.size.width, 148.48, accuracy: 0.001)
        XCTAssertEqual(leftPunch.size.height, 148.48, accuracy: 0.001)
        XCTAssertEqual(leftPunch.position.x, 64, accuracy: 0.001)
        XCTAssertEqual(leftPunch.position.y, 52, accuracy: 0.001)
        XCTAssertEqual(leftPunch.xScale, 1)
        XCTAssertEqual(rightPunch.xScale, -1)
        XCTAssertEqual(leftPunch.yScale, 1)
        XCTAssertEqual(rightPunch.yScale, 1)
        XCTAssertTrue(leftPunch.hidesBaseSprite)
        XCTAssertEqual(
            leftPunch.displayDuration,
            ScreenPetPunchSequence.default.totalDuration,
            accuracy: 0.0001
        )
    }

    func testPunchCooldownRepeatsWhilePetsStayClose() {
        XCTAssertLessThanOrEqual(ScreenPetEncounter.defaultPunchCooldown, 6)
        XCTAssertGreaterThanOrEqual(ScreenPetEncounter.defaultPunchInteractionDuration, 1)
    }

    func testDefaultPunchSequencePlaysThreeTimesWithinApprovedDuration() {
        let sequence = ScreenPetPunchSequence.default

        XCTAssertEqual(sequence.punchCount, 3)
        XCTAssertGreaterThanOrEqual(sequence.totalDuration, 2.4)
        XCTAssertLessThanOrEqual(sequence.totalDuration, 2.7)
    }

    func testEncounterLocksDirectionTowardTargetUntilPunchingStarts() {
        let catFrame = CGRect(x: 200, y: 2, width: 128, height: 128)
        let leftTarget = ScreenPetCandidate(
            id: "left",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 40, y: 2, width: 96, height: 96)
        )
        let rightTarget = ScreenPetCandidate(
            id: "right",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 480, y: 2, width: 96, height: 96)
        )
        var session = ScreenPetEncounterSession()

        session.lock(target: leftTarget, relativeTo: catFrame)
        XCTAssertEqual(session.phase, .approaching)
        XCTAssertEqual(session.direction, -1)

        session.refreshTarget(rightTarget, relativeTo: catFrame)
        XCTAssertEqual(session.direction, 1)
        session.beginPunching(at: 10)
        session.refreshTarget(leftTarget, relativeTo: catFrame)

        XCTAssertEqual(session.phase, .punching)
        XCTAssertEqual(session.direction, 1)
        XCTAssertEqual(session.target?.id, "right")
    }

    func testEncounterBlocksAutonomyThroughPunchThenAllowsCooldown() {
        let target = ScreenPetCandidate(
            id: "right",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 480, y: 2, width: 96, height: 96)
        )
        var session = ScreenPetEncounterSession()
        session.lock(
            target: target,
            relativeTo: CGRect(x: 200, y: 2, width: 128, height: 128)
        )
        session.beginPunching(at: 20)

        XCTAssertTrue(session.blocksAutonomousBehavior)
        XCTAssertEqual(
            session.phaseEndsAt,
            20 + ScreenPetPunchSequence.default.totalDuration,
            accuracy: 0.0001
        )

        session.beginCooldown(at: session.phaseEndsAt)

        XCTAssertEqual(session.phase, .cooldown)
        XCTAssertFalse(session.blocksAutonomousBehavior)
        XCTAssertNil(session.target)
        XCTAssertFalse(session.resetIfCooldownExpired(at: session.phaseEndsAt - 0.01))
        XCTAssertTrue(session.resetIfCooldownExpired(at: session.phaseEndsAt))
        XCTAssertEqual(session.phase, .searching)
    }

    func testEncounterAcceptsScanResultsOnlyWhileSearchingOrApproaching() {
        let target = ScreenPetCandidate(
            id: "right",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 480, y: 2, width: 96, height: 96)
        )
        var session = ScreenPetEncounterSession()

        XCTAssertTrue(session.acceptsScanResults)
        session.lock(
            target: target,
            relativeTo: CGRect(x: 200, y: 2, width: 128, height: 128)
        )
        XCTAssertTrue(session.acceptsScanResults)
        session.beginPunching(at: 10)
        XCTAssertFalse(session.acceptsScanResults)
        session.beginCooldown(at: session.phaseEndsAt)
        XCTAssertFalse(session.acceptsScanResults)
    }

    func testScanGateRejectsOverlappingAndTooFrequentScans() {
        var gate = ScreenPetScanGate()

        let first = gate.beginScan(now: 10, minimumInterval: 0.8)
        XCTAssertNotNil(first)
        XCTAssertNil(gate.beginScan(now: 11, minimumInterval: 0.8))
        XCTAssertTrue(gate.finishScan(first!))
        XCTAssertNil(gate.beginScan(now: 10.5, minimumInterval: 0.8))
        XCTAssertNotNil(gate.beginScan(now: 10.8, minimumInterval: 0.8))
    }

    func testScanGateRejectsResultInvalidatedWhileCaptureWasInFlight() {
        var gate = ScreenPetScanGate()
        let stale = gate.beginScan(now: 10, minimumInterval: 0.8)!

        gate.invalidateResults()

        XCTAssertFalse(gate.finishScan(stale))
        XCTAssertFalse(gate.isInFlight)
        let fresh = gate.beginScan(now: 11, minimumInterval: 0.8)!
        XCTAssertTrue(gate.finishScan(fresh))
    }

    func testRefreshedCandidateKeepsLockedWindowIdentity() {
        let locked = ScreenPetCandidate(
            id: "window-42",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 400, y: 2, width: 96, height: 96)
        )
        let other = ScreenPetCandidate(
            id: "window-7",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 390, y: 2, width: 96, height: 96)
        )
        let movedLocked = ScreenPetCandidate(
            id: "window-42",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 420, y: 2, width: 96, height: 96)
        )

        let refreshed = ScreenPetEncounter.refreshedCandidate(
            matching: locked,
            candidates: [other, movedLocked]
        )

        XCTAssertEqual(refreshed, movedLocked)
    }

    func testRefreshedPixelCandidateUsesNearbyBlobAndRejectsDisappearance() {
        let locked = ScreenPetCandidate(
            id: "screen-pixels-0",
            ownerName: "Screen Capture",
            windowName: "Codex Pet Pixels",
            frame: CGRect(x: 400, y: 2, width: 96, height: 96)
        )
        let nearby = ScreenPetCandidate(
            id: "screen-pixels-1",
            ownerName: "Screen Capture",
            windowName: "Codex Pet Pixels",
            frame: CGRect(x: 424, y: 4, width: 96, height: 96)
        )
        let farAway = ScreenPetCandidate(
            id: "screen-pixels-0",
            ownerName: "Screen Capture",
            windowName: "Codex Pet Pixels",
            frame: CGRect(x: 900, y: 4, width: 96, height: 96)
        )

        XCTAssertEqual(
            ScreenPetEncounter.refreshedCandidate(
                matching: locked,
                candidates: [farAway, nearby]
            ),
            nearby
        )
        XCTAssertNil(
            ScreenPetEncounter.refreshedCandidate(
                matching: locked,
                candidates: [farAway]
            )
        )
        XCTAssertNil(
            ScreenPetEncounter.refreshedCandidate(matching: locked, candidates: [])
        )
    }

    func testRefreshedCandidateSurvivesWindowAndPixelDetectionSourceChanges() {
        let windowTarget = ScreenPetCandidate(
            id: "window-42",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 400, y: 2, width: 96, height: 96)
        )
        let pixelTarget = ScreenPetCandidate(
            id: "screen-pixels-0",
            ownerName: "Screen Capture",
            windowName: "Codex Pet Pixels",
            frame: CGRect(x: 412, y: 4, width: 94, height: 92)
        )

        XCTAssertEqual(
            ScreenPetEncounter.refreshedCandidate(
                matching: windowTarget,
                candidates: [pixelTarget]
            ),
            pixelTarget
        )
        XCTAssertEqual(
            ScreenPetEncounter.refreshedCandidate(
                matching: pixelTarget,
                candidates: [windowTarget]
            ),
            windowTarget
        )
    }

    func testWindowCandidatesDoNotBlockPixelFallbackWhenLockedWindowDisappears() {
        let lockedWindow = ScreenPetCandidate(
            id: "window-42",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 400, y: 2, width: 96, height: 96)
        )
        let otherWindow = ScreenPetCandidate(
            id: "window-7",
            ownerName: "Codex",
            windowName: "Pet",
            frame: CGRect(x: 900, y: 2, width: 96, height: 96)
        )

        XCTAssertFalse(
            ScreenPetEncounter.shouldUseWindowCandidates(
                [otherWindow],
                lockedTarget: lockedWindow
            )
        )
        XCTAssertTrue(
            ScreenPetEncounter.shouldUseWindowCandidates(
                [lockedWindow, otherWindow],
                lockedTarget: lockedWindow
            )
        )
        XCTAssertTrue(
            ScreenPetEncounter.shouldUseWindowCandidates(
                [otherWindow],
                lockedTarget: nil
            )
        )
    }
}
