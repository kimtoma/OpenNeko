import XCTest
@testable import OpenNekoKit

final class CatAnimationTimingTests: XCTestCase {
    func testFourAndEightFramesKeepEveryStateDuration() {
        let expected: [CatState: TimeInterval] = [
            .idle: 0.72, .hover: 0.72, .click: 0.5, .coding: 0.72,
            .typing: 0.5, .thinking: 0.8, .lunch: 0.72, .yawn: 0.72,
            .nap: 1.6, .success: 0.5, .error: 0.72, .dragging: 0.72,
            .walk: 0.48, .jump: 0.5,
        ]

        for state in CatState.allCases {
            for count in [4, 8] {
                let duration = CatAnimationTiming.frameDuration(for: state, frameCount: count)
                XCTAssertEqual(duration * Double(count), expected[state]!, accuracy: 0.000_001,
                               "\(state.rawValue) with \(count) frames")
            }
        }
    }

    func testInterleavedFramesRetainOriginalPoseTimes() {
        for state in CatState.allCases {
            let cycle = CatAnimationTiming.cycleDuration(for: state)
            for originalPose in 0..<4 {
                let originalTime = (Double(originalPose) + 0.1) * cycle / 4
                let inBetweenTime = (Double(originalPose) + 0.6) * cycle / 4
                XCTAssertEqual(CatAnimationTiming.frameIndex(
                    at: originalTime, cycleDuration: cycle, frameCount: 4
                ), originalPose)
                XCTAssertEqual(CatAnimationTiming.frameIndex(
                    at: originalTime, cycleDuration: cycle, frameCount: 8
                ), originalPose * 2)
                XCTAssertEqual(CatAnimationTiming.frameIndex(
                    at: inBetweenTime, cycleDuration: cycle, frameCount: 8
                ), originalPose * 2 + 1)
            }
        }
    }

    func testShortLegacyAnimationsKeepTheirOriginalFrameCadence() {
        for state in CatState.allCases {
            let originalCadence = CatAnimationTiming.cycleDuration(for: state) / 4
            for count in 1...3 {
                XCTAssertEqual(CatAnimationTiming.frameDuration(for: state, frameCount: count),
                               originalCadence, accuracy: 0.000_001)
            }
        }
    }

    func testPreviewUsesAllEightFramesWithoutSlowingTheLoop() {
        let cycle = CatAnimationTiming.previewCycleDuration
        XCTAssertEqual(cycle, 0.48)
        for frame in 0..<8 {
            let elapsed = (Double(frame) + 0.25) * cycle / 8
            XCTAssertEqual(CatAnimationTiming.frameIndex(
                at: elapsed, cycleDuration: cycle, frameCount: 8
            ), frame)
            XCTAssertEqual(CatAnimationTiming.frameIndex(
                at: elapsed, cycleDuration: cycle, frameCount: 4
            ), frame / 2)
            XCTAssertEqual(CatAnimationTiming.frameIndex(
                at: elapsed + cycle, cycleDuration: cycle, frameCount: 8
            ), frame)
        }
    }

    func testPunchFallbackKeepsEncounterCompletionTime() {
        let sequence = ScreenPetPunchSequence.default
        for count in [4, 8] {
            let frameDuration = CatAnimationTiming.frameDuration(
                cycleDuration: sequence.singlePunchDuration, frameCount: count
            )
            let total = sequence.leadInDuration
                + frameDuration * Double(count * sequence.punchCount)
                + sequence.recoveryDuration * Double(sequence.punchCount - 1)
                + sequence.settleDuration
            XCTAssertEqual(total, 2.58, accuracy: 0.000_001)
            XCTAssertEqual(total, sequence.totalDuration, accuracy: 0.000_001)
        }
    }

    func testEmptyAndInvalidTimingInputsStaySafe() {
        XCTAssertEqual(CatAnimationTiming.frameDuration(for: .idle, frameCount: 0), 0)
        XCTAssertEqual(CatAnimationTiming.frameDuration(cycleDuration: .nan, frameCount: 8), 0)
        for count in [0, 1, 8] {
            XCTAssertEqual(CatAnimationTiming.frameIndex(
                at: .infinity, cycleDuration: 0.48, frameCount: count
            ), 0)
            XCTAssertEqual(CatAnimationTiming.frameIndex(
                at: 1, cycleDuration: 0, frameCount: count
            ), 0)
        }
    }
}
