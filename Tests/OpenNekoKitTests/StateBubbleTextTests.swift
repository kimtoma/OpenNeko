import XCTest
@testable import OpenNekoKit

final class StateBubbleTextTests: XCTestCase {
    func testExplicitBridgeMessageWinsAndStaysShort() {
        let event = StateBridgeEvent(
            state: .coding,
            source: "agent",
            message: String(repeating: "작업", count: 80)
        )

        let text = StateBubbleText.text(for: event)

        XCTAssertEqual(text?.count, StateBubbleText.maxDisplayLength)
    }

    func testCodingAndThinkingHaveDefaultBubbleText() {
        XCTAssertEqual(StateBubbleText.text(for: event(.coding)), "코딩 중이다냥")
        XCTAssertEqual(StateBubbleText.text(for: event(.thinking)), "생각 중이다냥")
    }

    func testLocalizedDefaultBridgeText() {
        XCTAssertEqual(StateBubbleText.text(for: event(.thinking), languageCode: "en"), "Thinking, nya~")
        XCTAssertEqual(StateBubbleText.text(for: event(.error), languageCode: "ja"), "問題が起きたにゃ...")
        XCTAssertEqual(StateBubbleText.text(for: event(.success), languageCode: "zh"), "完成喵!")
    }

    func testWakeTextIsLocalized() {
        XCTAssertEqual(StateBubbleText.wakeText(), "...깼다냥!")
        XCTAssertEqual(StateBubbleText.wakeText(languageCode: "en"), "...I'm awake, nya!")
        XCTAssertEqual(StateBubbleText.wakeText(languageCode: "ja"), "...起きたにゃ!")
        XCTAssertEqual(StateBubbleText.wakeText(languageCode: "zh"), "...我醒了喵!")
    }

    func testPlayfulStatesUseCatVoice() {
        XCTAssertEqual(StateBubbleText.text(for: event(.walk)), "산책하는 중이다냥")
        XCTAssertEqual(StateBubbleText.text(for: event(.jump), languageCode: "en"), "Hop, nya!")
        XCTAssertEqual(StateBubbleText.text(for: event(.yawn), languageCode: "ja"), "ふわぁ、にゃ...")
    }

    func testIdleDoesNotShowBubbleWithoutMessage() {
        XCTAssertNil(StateBubbleText.text(for: event(.idle)))
    }

    private func event(_ state: CatState) -> StateBridgeEvent {
        StateBridgeEvent(state: state, source: "agent", message: nil)
    }
}
