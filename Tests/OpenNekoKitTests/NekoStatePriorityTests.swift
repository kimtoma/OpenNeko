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

    func testBridgeRevertDelayKeepsAttentionRequestsUpLonger() {
        let attention = StateBridgeEvent(state: .hover, source: "claude-code", message: nil, isAttentionRequest: true)
        let coding = StateBridgeEvent(state: .coding, source: "agent", message: nil)

        XCTAssertEqual(NekoStatePriority.bridgeRevertDelay(for: attention), 600)
        XCTAssertEqual(NekoStatePriority.bridgeRevertDelay(for: coding), 90)
    }

    func testBridgeRevertDelayIsNilForIdleAndOneShotStates() {
        for state in [CatState.idle, .success, .error, .click] {
            let event = StateBridgeEvent(state: state, source: "agent", message: nil)
            XCTAssertNil(NekoStatePriority.bridgeRevertDelay(for: event), state.rawValue)
        }
    }
}
