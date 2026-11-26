import XCTest
@testable import OpenNekoKit

final class OllamaPullTrackerTests: XCTestCase {
    func testAggregatesLayerProgressAcrossDigests() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"status":"pulling manifest"}"#)
        XCTAssertEqual(tracker.phase, .preparing)
        XCTAssertEqual(tracker.fractionCompleted, 0)

        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":300,"completed":0}"#)
        tracker.consume(line: #"{"status":"pulling bbb","digest":"sha256:bbb","total":100,"completed":100}"#)
        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":300,"completed":100}"#)

        XCTAssertEqual(tracker.phase, .downloading)
        XCTAssertEqual(tracker.totalBytes, 400)
        XCTAssertEqual(tracker.completedBytes, 200)
        XCTAssertEqual(tracker.fractionCompleted, 0.5, accuracy: 0.0001)
    }

    func testDigestLineWithoutCompletedKeepsPreviousValue() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":100,"completed":40}"#)
        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":100}"#)
        XCTAssertEqual(tracker.completedBytes, 40)
    }

    func testVerifyingThenSuccess() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":10,"completed":10}"#)
        tracker.consume(line: #"{"status":"verifying sha256 digest"}"#)
        XCTAssertEqual(tracker.phase, .verifying)
        tracker.consume(line: #"{"status":"writing manifest"}"#)
        tracker.consume(line: #"{"status":"success"}"#)
        XCTAssertEqual(tracker.phase, .succeeded)
        XCTAssertTrue(tracker.isFinished)
        XCTAssertEqual(tracker.fractionCompleted, 1)
    }

    func testErrorLineFailsAndFurtherLinesAreIgnored() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"error":"pull model manifest: file does not exist"}"#)
        XCTAssertEqual(tracker.phase, .failed("pull model manifest: file does not exist"))
        tracker.consume(line: #"{"status":"success"}"#)
        XCTAssertEqual(tracker.phase, .failed("pull model manifest: file does not exist"))
    }

    func testIgnoresBlankAndGarbageLines() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: "")
        tracker.consume(line: "   ")
        tracker.consume(line: "not json")
        XCTAssertEqual(tracker, OllamaPullTracker())
    }

    func testCompletedNeverExceedsTotal() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"status":"pulling aaa","digest":"sha256:aaa","total":10,"completed":25}"#)
        XCTAssertEqual(tracker.completedBytes, 10)
        XCTAssertEqual(tracker.fractionCompleted, 1)
    }
}
