import XCTest
@testable import OpenNekoKit

final class StateBridgeHTTPTests: XCTestCase {
    private func request(_ raw: String) -> StateBridgeHTTPRequest? {
        StateBridgeHTTPRequest(data: Data(raw.utf8))
    }

    func testParsesGetRequestWithoutBody() {
        let parsed = request("GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")

        XCTAssertEqual(parsed?.method, "GET")
        XCTAssertEqual(parsed?.path, "/health")
        XCTAssertEqual(parsed?.body, Data())
    }

    func testParsesPostBodyUsingContentLength() {
        let body = #"{"state":"coding"}"#
        let parsed = request(
            "POST /state HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        )

        XCTAssertEqual(parsed?.method, "POST")
        XCTAssertEqual(parsed?.path, "/state")
        XCTAssertEqual(parsed?.body, Data(body.utf8))
    }

    func testContentLengthHeaderIsCaseInsensitive() {
        let parsed = request("POST /state HTTP/1.1\r\ncontent-length: 2\r\n\r\nok")

        XCTAssertEqual(parsed?.body, Data("ok".utf8))
    }

    func testBodyIsTruncatedToContentLength() {
        let parsed = request("POST /state HTTP/1.1\r\nContent-Length: 2\r\n\r\nokEXTRA")

        XCTAssertEqual(parsed?.body, Data("ok".utf8))
    }

    func testIncompleteHeaderReturnsNil() {
        XCTAssertNil(request("POST /state HTTP/1.1\r\nContent-Length: 5\r\n"))
    }

    func testIncompleteBodyReturnsNil() {
        XCTAssertNil(request("POST /state HTTP/1.1\r\nContent-Length: 5\r\n\r\nab"))
    }

    func testMalformedRequestLineReturnsNil() {
        XCTAssertNil(request("NONSENSE\r\n\r\n"))
    }

    func testOversizedContentLengthReturnsNil() {
        let oversized = StateBridgeRequest.maxBodyBytes + 1
        XCTAssertNil(request("POST /state HTTP/1.1\r\nContent-Length: \(oversized)\r\n\r\n"))
    }

    func testOkResponseSerialization() {
        let data = StateBridgeHTTPResponse.ok("openneko").data
        let text = String(data: data, encoding: .utf8)

        XCTAssertEqual(
            text,
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 8\r\nConnection: close\r\n\r\nopenneko"
        )
    }

    func testJSONResponseUsesJSONContentType() {
        let response = StateBridgeHTTPResponse.json("{}")

        XCTAssertEqual(response.contentType, "application/json")
        XCTAssertEqual(response.status, "200 OK")
    }

    func testPNGResponseKeepsBinaryBody() {
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])
        let response = StateBridgeHTTPResponse.png(bytes)

        XCTAssertEqual(response.contentType, "image/png")
        XCTAssertEqual(response.data.suffix(4), bytes)
    }

    func testErrorResponses() {
        XCTAssertEqual(StateBridgeHTTPResponse.badRequest.status, "400 Bad Request")
        XCTAssertEqual(StateBridgeHTTPResponse.notFound.status, "404 Not Found")
        XCTAssertEqual(StateBridgeHTTPResponse.serviceUnavailable.status, "503 Service Unavailable")
    }

    func testPortFallsBackWithoutEnvironmentVariable() {
        XCTAssertEqual(StateBridgePort.resolve(environment: [:]), 48800)
    }

    func testPortUsesValidEnvironmentVariable() {
        XCTAssertEqual(StateBridgePort.resolve(environment: ["OPENNEKO_PORT": "48801"]), 48801)
    }

    func testPortFallsBackOnInvalidValue() {
        XCTAssertEqual(StateBridgePort.resolve(environment: ["OPENNEKO_PORT": "not-a-port"]), 48800)
        XCTAssertEqual(StateBridgePort.resolve(environment: ["OPENNEKO_PORT": "99999"]), 48800)
    }
}
