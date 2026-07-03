import XCTest
@testable import OpenNekoKit

final class NekoStatePriorityTests: XCTestCase {
    func testChatAnsweringUsesThinkingState() {
        XCTAssertEqual(NekoStatePriority.chatAnsweringState, .thinking)
    }

    func testBridgeEventsDoNotOverrideChatAnswering() {
        XCTAssertFalse(NekoStatePriority.acceptsBridgeEvent(isChatAnswering: true))
        XCTAssertTrue(NekoStatePriority.acceptsBridgeEvent(isChatAnswering: false))
    }

    func testAgentCodingDoesNotOverrideChatAnswering() {
        XCTAssertFalse(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: true, currentState: .idle))
        XCTAssertFalse(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: true, currentState: .coding))
        XCTAssertFalse(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: true, currentState: .walk))
    }

    func testAgentCodingOnlyAppliesToAmbientWorkStates() {
        XCTAssertTrue(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: false, currentState: .idle))
        XCTAssertTrue(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: false, currentState: .coding))
        XCTAssertTrue(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: false, currentState: .walk))
        XCTAssertFalse(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: false, currentState: .thinking))
        XCTAssertFalse(NekoStatePriority.acceptsAgentCodingState(isChatAnswering: false, currentState: .typing))
    }

    func testOneShotStatesPlayOnceWithoutIdleRevertTimer() {
        XCTAssertEqual(NekoStatePriority.oneShotStates, [.click, .yawn, .success, .error, .jump])
    }

    func testStickyStatesAreNotOneShot() {
        for state in [CatState.coding, .typing, .thinking, .nap, .lunch, .walk, .idle] {
            XCTAssertFalse(NekoStatePriority.oneShotStates.contains(state))
        }
    }
}
