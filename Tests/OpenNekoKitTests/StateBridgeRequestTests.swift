import XCTest
@testable import OpenNekoKit

final class StateBridgeRequestTests: XCTestCase {
    func testParsesStateBridgeJSONWithDefaultSource() throws {
        let event = try StateBridgeRequest.parse(Data(#"{"state":"coding"}"#.utf8))

        XCTAssertEqual(event.state, .coding)
        XCTAssertEqual(event.source, "agent")
        XCTAssertNil(event.message)
    }

    func testMapsWaitingStateToHoverAnimation() throws {
        let event = try StateBridgeRequest.parse(Data(#"{"state":"waiting","source":"hook"}"#.utf8))

        XCTAssertEqual(event.state, .hover)
        XCTAssertEqual(event.source, "hook")
    }

    func testTruncatesSourceAndMessageLikeElectronBridge() throws {
        let longSource = String(repeating: "s", count: 50)
        let longMessage = String(repeating: "m", count: 140)
        let json = #"{"state":"success","source":"\#(longSource)","message":"\#(longMessage)"}"#

        let event = try StateBridgeRequest.parse(Data(json.utf8))

        XCTAssertEqual(event.source.count, 40)
        XCTAssertEqual(event.message?.count, 120)
    }

    func testRejectsUnknownState() {
        XCTAssertThrowsError(try StateBridgeRequest.parse(Data(#"{"state":"ghost"}"#.utf8)))
    }
}
