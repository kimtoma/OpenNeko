import XCTest
@testable import OpenNekoKit

final class NekoBubbleCopyTests: XCTestCase {
    func testKoreanUsesCatVoiceForCoreActions() {
        XCTAssertTrue(NekoBubbleCopy.stretch(languageCode: "ko").contains("냥"))
        XCTAssertTrue(NekoBubbleCopy.chatReset(languageCode: "ko").contains("냥"))
        XCTAssertTrue(NekoBubbleCopy.unknownCommand(languageCode: "ko").contains("냥"))
    }

    func testLocalizedCatVoiceMarkers() {
        XCTAssertTrue(NekoBubbleCopy.bgmSearching(languageCode: "en").contains("nya"))
        XCTAssertTrue(NekoBubbleCopy.skillDisabled(languageCode: "ja").contains("にゃ"))
        XCTAssertTrue(NekoBubbleCopy.soundEnabled(false, languageCode: "zh").contains("喵"))
    }

    func testDynamicCopyKeepsProvidedValues() {
        XCTAssertTrue(NekoBubbleCopy.skinList("white, black", languageCode: "ko").contains("white, black"))
        XCTAssertTrue(NekoBubbleCopy.bgmOpened(title: "Lo-fi", query: "focus", languageCode: "en").contains("Lo-fi"))
        XCTAssertTrue(NekoBubbleCopy.thinking(skillName: "Translate", languageCode: "en").contains("Translate"))
    }

    func testChatPlaceholderUsesCatVoice() {
        XCTAssertEqual(NekoBubbleCopy.chatPlaceholder(languageCode: "ko"), "무엇을 물어볼까냥?")
        XCTAssertTrue(NekoBubbleCopy.chatPlaceholder(languageCode: "en").contains("nya"))
    }

    func testReplyCopiedUsesCatVoice() {
        XCTAssertTrue(NekoBubbleCopy.replyCopied(languageCode: "ko").contains("냥"))
        XCTAssertTrue(NekoBubbleCopy.replyCopied(languageCode: "en").contains("nya"))
        XCTAssertEqual(NekoBubbleCopy.copyReplyHelp(languageCode: "ko"), "답변 복사")
    }

    func testStyledChatReplyAddsCatVoiceWhenMissing() {
        XCTAssertEqual(NekoBubbleCopy.styledChatReply("좋아요.", languageCode: "ko"), "좋아요냥.")
        XCTAssertEqual(NekoBubbleCopy.styledChatReply("Sure!", languageCode: "en"), "Sure, nya~!")
    }

    func testStyledChatReplyDoesNotDuplicateCatVoice() {
        XCTAssertEqual(NekoBubbleCopy.styledChatReply("이미 알겠다냥!", languageCode: "ko"), "이미 알겠다냥!")
        XCTAssertEqual(NekoBubbleCopy.styledChatReply("Done, nya~", languageCode: "en"), "Done, nya~")
    }
}
