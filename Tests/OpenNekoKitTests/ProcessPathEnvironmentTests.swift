import XCTest
@testable import OpenNekoKit

final class ProcessPathEnvironmentTests: XCTestCase {
    func testAugmentPathPrependsMacUserAndPackageManagerBins() {
        let path = ProcessPathEnvironment.augmentPath(
            "/usr/bin:/bin",
            homeDirectory: "/Users/me",
            platform: "darwin"
        )
        let entries = path.split(separator: ":").map(String.init)

        XCTAssertTrue(entries.contains("/opt/homebrew/bin"))
        XCTAssertTrue(entries.contains("/opt/homebrew/sbin"))
        XCTAssertTrue(entries.contains("/usr/local/bin"))
        XCTAssertTrue(entries.contains("/Users/me/.local/bin"))
        XCTAssertTrue(entries.contains("/Users/me/bin"))
        XCTAssertTrue(entries.contains("/usr/bin"))
    }

    func testAugmentPathDoesNotDuplicateExistingEntries() {
        let path = ProcessPathEnvironment.augmentPath(
            "/opt/homebrew/bin:/usr/bin",
            homeDirectory: "/Users/me",
            platform: "darwin"
        )
        let entries = path.split(separator: ":").map(String.init)

        XCTAssertEqual(entries.filter { $0 == "/opt/homebrew/bin" }.count, 1)
        XCTAssertEqual(entries.filter { $0 == "/usr/bin" }.count, 1)
    }

    func testSpawnEnvironmentPreservesValuesAndSetsPathOnlyByDefault() {
        let environment = ProcessPathEnvironment.spawnEnvironment(
            baseEnvironment: ["PATH": "/usr/bin", "FOO": "bar"],
            homeDirectory: "/Users/me",
            platform: "darwin"
        )

        XCTAssertEqual(environment["FOO"], "bar")
        XCTAssertTrue(environment["PATH"]?.split(separator: ":").contains("/Users/me/.local/bin") == true)
        XCTAssertNil(environment["NO_COLOR"])
        XCTAssertNil(environment["TERM"])
    }

    func testSpawnEnvironmentCanAddTerminalDefaultsForCLIProviders() {
        let environment = ProcessPathEnvironment.spawnEnvironment(
            baseEnvironment: ["PATH": "/usr/bin"],
            homeDirectory: "/Users/me",
            platform: "darwin",
            terminalDefaults: true
        )

        XCTAssertEqual(environment["NO_COLOR"], "1")
        XCTAssertEqual(environment["TERM"], "xterm-256color")
    }
}
