import XCTest
@testable import OpenNekoKit

final class AgentTaskFolderPolicyTests: XCTestCase {
    private let home = "/Users/neko"

    private func reason(_ path: String) -> AgentTaskFolderRejection? {
        if case let .failure(error) = AgentTaskFolderPolicy.validate(path, homeDirectory: home) {
            return error.reason
        }
        return nil
    }

    func testAcceptsProjectFolderAndNormalizes() {
        XCTAssertEqual(try AgentTaskFolderPolicy.validate("/Users/neko/Projects/app/", homeDirectory: home).get(), "/Users/neko/Projects/app")
        XCTAssertEqual(try AgentTaskFolderPolicy.validate("/Users/neko/Projects/a/../b", homeDirectory: home).get(), "/Users/neko/Projects/b")
        XCTAssertEqual(try AgentTaskFolderPolicy.validate("/Volumes/Work/site", homeDirectory: home).get(), "/Volumes/Work/site")
    }

    func testRejectsBroadOrSystemFolders() {
        XCTAssertEqual(reason("relative/path"), .notAbsolute)
        XCTAssertEqual(reason("/"), .filesystemRoot)
        XCTAssertEqual(reason("/Users/neko"), .homeDirectory)
        XCTAssertEqual(reason("/Users/neko/"), .homeDirectory)
        XCTAssertEqual(reason("/Users"), .homeDirectory)
        XCTAssertEqual(reason("/System/Library"), .systemLocation)
        XCTAssertEqual(reason("/Applications"), .systemLocation)
        XCTAssertEqual(reason("/usr/local/bin"), .systemLocation)
    }

    func testSimilarPrefixIsNotTreatedAsSystem() {
        XCTAssertNil(reason("/Users/neko/usr-notes"))
        XCTAssertEqual(reason("/Library"), .systemLocation)
        XCTAssertNil(reason("/Users/neko/Library-projects"))
    }
}
