import XCTest
@testable import OpenNekoKit

final class CatStateMachineTests: XCTestCase {
    func testStartsIdle() {
        let sm = CatStateMachine()
        XCTAssertEqual(sm.current, .idle)
    }

    func testTypingStartedGoesTyping() {
        var sm = CatStateMachine()
        sm.handle(.typingStarted)
        XCTAssertEqual(sm.current, .typing)
    }

    func testTypingStoppedReturnsIdle() {
        var sm = CatStateMachine()
        sm.handle(.typingStarted)
        sm.handle(.typingStopped)
        XCTAssertEqual(sm.current, .idle)
    }

    func testHoverThenEnded() {
        var sm = CatStateMachine()
        sm.handle(.hoverBegan)
        XCTAssertEqual(sm.current, .hover)
        sm.handle(.hoverEnded)
        XCTAssertEqual(sm.current, .idle)
    }

    func testDragOverridesTyping() {
        var sm = CatStateMachine()
        sm.handle(.dragBegan)
        XCTAssertEqual(sm.current, .dragging)
        sm.handle(.typingStarted)   // 드래그 중엔 무시
        XCTAssertEqual(sm.current, .dragging)
        sm.handle(.dragEnded)
        XCTAssertEqual(sm.current, .idle)
    }

    func testIdleTimeoutNaps() {
        var sm = CatStateMachine()
        sm.handle(.idleTimeout)
        XCTAssertEqual(sm.current, .nap)
    }

    func testTypingWakesFromNap() {
        var sm = CatStateMachine()
        sm.handle(.idleTimeout)     // nap
        sm.handle(.typingStarted)
        XCTAssertEqual(sm.current, .typing)
    }
}
