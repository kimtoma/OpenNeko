import XCTest
@testable import OpenNekoKit

final class HTTPChatResponseParserTests: XCTestCase {
    func testParsesOpenAICompatibleResponse() throws {
        let data = Data(#"{"choices":[{"message":{"content":"좋아요"}}]}"#.utf8)

        XCTAssertEqual(try HTTPChatResponseParser.parse(data, type: .openAICompatible), "좋아요")
    }

    func testParsesGeminiResponse() throws {
        let data = Data(#"{"candidates":[{"content":{"parts":[{"text":"첫 줄"},{"text":"둘째 줄"}]}}]}"#.utf8)

        XCTAssertEqual(try HTTPChatResponseParser.parse(data, type: .gemini), "첫 줄둘째 줄")
    }

    func testParsesAnthropicResponse() throws {
        let data = Data(#"{"content":[{"type":"text","text":"완료"}]}"#.utf8)

        XCTAssertEqual(try HTTPChatResponseParser.parse(data, type: .anthropic), "완료")
    }

    func testThrowsOnEmptyText() {
        XCTAssertThrowsError(
            try HTTPChatResponseParser.parse(Data(#"{"choices":[]}"#.utf8), type: .openAICompatible)
        )
    }

    func testParsesOpenAIStreamingDeltaLines() throws {
        let first = try HTTPChatStreamParser.parseOpenAIEventLine(
            #"data: {"choices":[{"delta":{"role":"assistant","content":"좋"}}]}"#
        )
        let second = try HTTPChatStreamParser.parseOpenAIEventLine(
            #"data: {"choices":[{"delta":{"content":"아요"}}]}"#
        )
        let roleOnly = try HTTPChatStreamParser.parseOpenAIEventLine(
            #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#
        )
        let done = try HTTPChatStreamParser.parseOpenAIEventLine("data: [DONE]")

        XCTAssertEqual(first, HTTPChatStreamEvent(text: "좋", isDone: false))
        XCTAssertEqual(second, HTTPChatStreamEvent(text: "아요", isDone: false))
        XCTAssertNil(roleOnly)
        XCTAssertEqual(done, HTTPChatStreamEvent(text: "", isDone: true))
    }

    func testStreamingParserIgnoresNonDataLinesAndRejectsEmptyFinalText() throws {
        XCTAssertNil(try HTTPChatStreamParser.parseOpenAIEventLine(": keep-alive"))
        XCTAssertThrowsError(try HTTPChatStreamParser.nonEmpty(" \n\t "))
    }
}
