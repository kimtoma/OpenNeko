import XCTest
@testable import OpenNekoKit

final class StateBridgeExampleTests: XCTestCase {
    func testEndpointUsesLoopbackAndSelectedPort() {
        XCTAssertEqual(StateBridgeExample.endpoint(port: 48801), "http://127.0.0.1:48801")
        XCTAssertEqual(StateBridgeExample.stateURL(port: 48801), "http://127.0.0.1:48801/state")
    }

    func testCurlCommandUsesStateEndpointAndParseablePayload() throws {
        let command = StateBridgeExample.curlCommand(port: 48801)

        XCTAssertTrue(command.contains("curl -X POST http://127.0.0.1:48801/state"))
        XCTAssertTrue(command.contains("-H 'Content-Type: application/json'"))
        XCTAssertTrue(command.contains("\"state\":\"coding\""))
        XCTAssertTrue(command.contains("\"source\":\"manual\""))

        let marker = "-d '"
        let start = try XCTUnwrap(command.range(of: marker)?.upperBound)
        let tail = command[start...]
        let end = try XCTUnwrap(tail.firstIndex(of: "'"))
        let payload = Data(tail[..<end].utf8)
        let event = try StateBridgeRequest.parse(payload)

        XCTAssertEqual(event.state, .coding)
        XCTAssertEqual(event.source, "manual")
        XCTAssertEqual(event.message, "Working")
    }

    func testCommonStateLabelsStayCompact() {
        XCTAssertEqual(StateBridgeExample.commonStateLabels, "idle, typing, coding, thinking, success, error")
        XCTAssertEqual(
            StateBridgeExample.debugEndpointLabels,
            "/health, /anim, /pos, /debug/position, /capture, /debug/settings, /debug/settings/apply, /debug/agent, /debug/drag, /debug/typing"
        )
    }
}
