import XCTest
@testable import OpenNekoKit

final class RepositoryRootSearchTests: XCTestCase {
    func testWalksUpToRootAndStops() {
        XCTAssertEqual(
            RepositoryRootSearch.candidates(startingAt: "/Applications/OpenNeko.app"),
            ["/Applications/OpenNeko.app", "/Applications", "/"]
        )
        XCTAssertEqual(
            RepositoryRootSearch.candidates(startingAt: "/Users/me/Projects/openNeko/build/OpenNeko.app/"),
            ["/Users/me/Projects/openNeko/build/OpenNeko.app", "/Users/me/Projects/openNeko/build", "/Users/me/Projects/openNeko", "/Users/me/Projects", "/Users/me", "/Users", "/"]
        )
        XCTAssertEqual(RepositoryRootSearch.candidates(startingAt: "/"), ["/"])
    }

    func testDotDotAndRelativeInputsStayBounded() {
        XCTAssertEqual(RepositoryRootSearch.candidates(startingAt: "/../.."), ["/"])
        XCTAssertEqual(RepositoryRootSearch.candidates(startingAt: "/Applications/../Applications/X.app"), ["/Applications/X.app", "/Applications", "/"])
        XCTAssertEqual(RepositoryRootSearch.candidates(startingAt: "relative/path"), [])
        XCTAssertEqual(RepositoryRootSearch.candidates(startingAt: ""), [])
    }
}
