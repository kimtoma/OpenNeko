import XCTest
@testable import OpenNekoKit

final class AgentActivityLogTests: XCTestCase {
    func testEntryRoundTripsAsOneJSONLine() {
        let entry = AgentActivityEntry(
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            agent: "claude",
            folder: "/Users/neko/app",
            kind: .approved,
            detail: "Bash(npm test)"
        )
        let line = entry.jsonLine()
        XCTAssertTrue(line.hasSuffix("\n"))
        XCTAssertEqual(line.filter { $0 == "\n" }.count, 1)
        XCTAssertTrue(line.contains(#""folder":"/Users/neko/app""#))
        XCTAssertEqual(AgentActivityEntry.decode(line: line), entry)
    }

    func testDetailIsCapped() {
        let entry = AgentActivityEntry(timestamp: Date(), agent: "claude", folder: "/p", kind: .tool, detail: String(repeating: "a", count: 5_000))
        XCTAssertEqual(entry.detail.count, 2_000)
    }

    func testLineBufferKeepsPartialTail() {
        var buffer = LineBuffer()
        XCTAssertEqual(buffer.append(Data("{\"a\":1}\n{\"b\"".utf8)), ["{\"a\":1}"])
        XCTAssertEqual(buffer.append(Data(":2}\n\n".utf8)), ["{\"b\":2}", ""])
        XCTAssertNil(buffer.flush())
        _ = buffer.append(Data("tail".utf8))
        XCTAssertEqual(buffer.flush(), "tail")
        XCTAssertNil(buffer.flush())
    }

    func testLineBufferHandlesMultibyteSplitAcrossChunks() {
        var buffer = LineBuffer()
        let bytes = Array("냥\n".utf8)
        XCTAssertEqual(buffer.append(Data(bytes[0..<2])), [])
        XCTAssertEqual(buffer.append(Data(bytes[2...])), ["냥"])
    }
}
