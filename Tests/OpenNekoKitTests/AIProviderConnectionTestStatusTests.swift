import XCTest
@testable import OpenNekoKit

final class AIProviderConnectionTestStatusTests: XCTestCase {
    func testIdleIsNotRunning() {
        let status = AIProviderConnectionTestStatus.idle

        XCTAssertEqual(status.severity, .idle)
        XCTAssertFalse(status.isRunning)
    }

    func testRunningIncludesProviderTitle() {
        let status = AIProviderConnectionTestStatus.running(providerTitle: "Codex")

        XCTAssertEqual(status.severity, .running)
        XCTAssertTrue(status.isRunning)
        XCTAssertTrue(status.detail.contains("Codex"))
    }

    func testSuccessSummarizesReply() {
        let status = AIProviderConnectionTestStatus.success(reply: " 준비됨\n\n좋아요 ")

        XCTAssertEqual(status.severity, .success)
        XCTAssertEqual(status.detail, "응답: 준비됨 좋아요")
    }

    func testFailureUsesFallbackForBlankMessage() {
        let status = AIProviderConnectionTestStatus.failure(message: "   ")

        XCTAssertEqual(status.severity, .failure)
        XCTAssertEqual(status.detail, "연결 설정을 확인해 주세요.")
    }

    func testConnectionCopyUsesSelectedLanguage() {
        XCTAssertEqual(AIProviderConnectionTestStatus.idle(languageCode: "en").title, "Connection Test")
        XCTAssertEqual(
            AIProviderConnectionTestStatus.success(reply: "ok", languageCode: "zh").detail,
            "回复：ok"
        )
    }
}
