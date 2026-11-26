import XCTest
@testable import OpenNekoKit

final class AgentTaskCopyTests: XCTestCase {
    func testEveryKeyIsTranslated() {
        for key in AgentTaskCopyKey.allCases {
            let texts = ["ko", "en", "ja", "zh"].map { AgentTaskCopy.text(key, languageCode: $0) }
            XCTAssertTrue(texts.allSatisfy { !$0.isEmpty }, "\(key)")
            XCTAssertEqual(Set(texts).count, 4, "\(key)")
        }
    }

    func testResultBubbleClipsLongSummaries() {
        let long = String(repeating: "가", count: 200)
        let bubble = AgentTaskCopy.resultBubble(.finished(long), languageCode: "ko", limit: 10)
        XCTAssertEqual(bubble, "작업 끝! " + String(repeating: "가", count: 10) + "…")
        XCTAssertEqual(AgentTaskCopy.resultBubble(.finished("a\nb"), languageCode: "en"), "Done! a b")
        XCTAssertNil(AgentTaskCopy.resultBubble(.running, languageCode: "en"))
        XCTAssertEqual(AgentTaskCopy.resultBubble(.denied(""), languageCode: "en"), "Okay, stopping here, nya")
    }

    func testFolderRejectionCopy() {
        XCTAssertEqual(AgentTaskCopy.folderRejected(.homeDirectory, languageCode: "en"), "Not your whole home folder, nya. Pick a subfolder.")
    }
}
