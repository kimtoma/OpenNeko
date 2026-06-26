import XCTest
@testable import OpenNekoKit

final class SpriteManifestTests: XCTestCase {
    func testParsesStatesAndFrames() throws {
        let json = """
        { "idle": ["idle_0.png", "idle_1.png"], "walk": ["walk_0.png"] }
        """.data(using: .utf8)!
        let m = try SpriteManifest(data: json)
        XCTAssertEqual(m.frames(for: "idle"), ["idle_0.png", "idle_1.png"])
        XCTAssertEqual(m.frames(for: "walk"), ["walk_0.png"])
    }

    func testMissingStateReturnsEmpty() throws {
        let json = #"{ "idle": ["idle_0.png"] }"#.data(using: .utf8)!
        let m = try SpriteManifest(data: json)
        XCTAssertEqual(m.frames(for: "nope"), [])
    }

    func testStateNamesSorted() throws {
        let json = #"{ "walk": ["w.png"], "idle": ["i.png"] }"#.data(using: .utf8)!
        let m = try SpriteManifest(data: json)
        XCTAssertEqual(m.stateNames, ["idle", "walk"])
    }

    func testInvalidJSONThrows() {
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try SpriteManifest(data: bad))
    }

    func testEmptyThrows() {
        let empty = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try SpriteManifest(data: empty)) { error in
            XCTAssertEqual(error as? SpriteManifestError, .empty)
        }
    }
}
