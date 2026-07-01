import XCTest
@testable import OpenNekoKit

final class ChatTranscriptStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-chat-transcript-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
        tmp = nil
    }

    func testDefaultFileURLCanUseEnvironmentOverrideForQA() {
        let override = tmp.appendingPathComponent("custom.md").path
        let url = ChatTranscriptStore.defaultFileURL(environment: [
            "OPENNEKO_CHAT_HISTORY_PATH": " \(override) "
        ])

        XCTAssertEqual(url.path, override)
    }

    func testDefaultFileURLUsesApplicationSupportMarkdownFile() {
        let url = ChatTranscriptStore.defaultFileURL(environment: [
            "OPENNEKO_CHAT_HISTORY_PATH": "  "
        ])

        XCTAssertTrue(url.path.hasSuffix("Application Support/openNeko/chat-history.md"))
    }

    func testSaveWritesReadableMarkdownAndLoadRoundTripsMessages() throws {
        let url = tmp.appendingPathComponent("chat-history.md")
        let fixedDate = Date(timeIntervalSince1970: 1_704_067_200)
        let store = ChatTranscriptStore(fileURL: url, now: { fixedDate })
        let messages = [
            ChatMessage(role: .user, text: "안녕\n오늘 어때?"),
            ChatMessage(role: .assistant, text: "좋다냥.")
        ]

        try store.save(messages)

        let markdown = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(markdown.contains("# openNeko Chat History"))
        XCTAssertTrue(markdown.contains("### Me"))
        XCTAssertTrue(markdown.contains("### openNeko"))
        XCTAssertTrue(markdown.contains("안녕\n오늘 어때?"))
        XCTAssertTrue(markdown.contains("좋다냥."))
        XCTAssertEqual(store.load(), messages)
    }

    func testParseMarkdownSkipsEmptyMessages() {
        let markdown = """
        # openNeko Chat History

        <!-- openNeko:message role=user -->
        ### Me


        <!-- openNeko:message role=assistant -->
        ### openNeko

        답이다냥.
        """

        XCTAssertEqual(
            ChatTranscriptStore.parseMarkdown(markdown),
            [ChatMessage(role: .assistant, text: "답이다냥.")]
        )
    }

    func testSaveEmptyRemovesHistoryFile() throws {
        let url = tmp.appendingPathComponent("chat-history.md")
        let store = ChatTranscriptStore(fileURL: url)
        try store.save([ChatMessage(role: .user, text: "남아있으면 안 된다냥")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        try store.save([])

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.load(), [])
    }
}
