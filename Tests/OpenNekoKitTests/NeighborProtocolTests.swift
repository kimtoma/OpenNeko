import XCTest
@testable import OpenNekoKit

final class NeighborProtocolTests: XCTestCase {
    func testCoarsePresenceOnlySharesBroadActivity() {
        XCTAssertEqual(NeighborPresence.coarse(for: .typing), .typing)
        XCTAssertEqual(NeighborPresence.coarse(for: .coding), .coding)
        XCTAssertEqual(NeighborPresence.coarse(for: .thinking), .coding)
        XCTAssertEqual(NeighborPresence.coarse(for: .nap), .away)
        XCTAssertEqual(NeighborPresence.coarse(for: .yawn), .away)
        XCTAssertEqual(NeighborPresence.coarse(for: .success), .idle)
    }

    func testNeighborSettingsSanitizesDisplayName() {
        let settings = NeighborSettings(enabled: true, displayName: "  \(String(repeating: "n", count: 80))  ")

        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.displayName.count, 64)
        XCTAssertFalse(settings.displayName.hasPrefix(" "))
    }

    func testHelloMessageRoundTripsElectronShape() throws {
        let message = try XCTUnwrap(NeighborMessage.hello(id: "peer-1", name: "Desk Cat", skin: "black"))
        let data = try NeighborMessageCodec.encode(message)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(text.contains(#""t":"hello""#))
        XCTAssertTrue(text.hasSuffix("\n"))
        XCTAssertEqual(NeighborMessageCodec.decodeLine(text), message)
    }

    func testInvalidMessagesAreRejected() {
        XCTAssertNil(NeighborMessage.hello(id: "", name: "Nope", skin: "black"))
        XCTAssertNil(NeighborMessage.greeting(key: 100))
        XCTAssertNil(NeighborMessageCodec.decodeLine(#"{"t":"presence","state":"secret"}"#))
        XCTAssertNil(NeighborMessageCodec.decodeLine(String(repeating: "x", count: NeighborMessageCodec.maxRawBytes + 1)))
    }

    func testPeerBookPrunesExpiredPeers() {
        var book = NeighborPeerBook()
        _ = book.addOrUpdate(NeighborPeer(id: "b", name: "B", lastSeen: 10))
        _ = book.addOrUpdate(NeighborPeer(id: "a", name: "A", lastSeen: 30))

        let expired = book.prune(now: 50, ttl: 25)

        XCTAssertEqual(expired.map(\.id), ["b"])
        XCTAssertEqual(book.peers.map(\.id), ["a"])
    }

    func testNeighborEventPresentationMatchesPresenceAndGreetings() {
        XCTAssertEqual(NeighborEventPresentation.presenceState(for: .coding), .coding)
        XCTAssertEqual(NeighborEventPresentation.presenceState(for: .typing), .typing)
        XCTAssertEqual(NeighborEventPresentation.presenceState(for: .away), .nap)
        XCTAssertEqual(NeighborEventPresentation.greeting(key: 5, languageCode: "en"), "Nice to meet, nya~")
        XCTAssertEqual(NeighborEventPresentation.greeting(key: 3, languageCode: "ko"), "같이 일하자냥!")
    }

    func testNeighborEventPresentationLocalizesMainBubbleText() {
        let peer = NeighborPeer(id: "peer-1", name: "Desk Cat")

        XCTAssertEqual(
            NeighborEventPresentation.mainBubbleText(for: .joined(peer), languageCode: "en"),
            "Desk Cat joined"
        )
        XCTAssertEqual(
            NeighborEventPresentation.mainBubbleText(for: .left(peer), languageCode: "ko"),
            "Desk Cat 떠남"
        )
        XCTAssertNil(
            NeighborEventPresentation.mainBubbleText(for: .presence(peer), languageCode: "ja")
        )
    }
}
