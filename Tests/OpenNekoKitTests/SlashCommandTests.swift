import XCTest
@testable import OpenNekoKit

final class SlashCommandTests: XCTestCase {
    func testParseSlashCommandLowercasesCommandAndTrimsArguments() {
        XCTAssertEqual(
            SlashCommandParser.parse("/Skin  calico  ")!,
            SlashCommand(command: "skin", arguments: "calico")
        )
    }

    func testParseRequiresSlashAsFirstCharacter() {
        XCTAssertNil(SlashCommandParser.parse(" /help"))
        XCTAssertNil(SlashCommandParser.parse("help"))
        XCTAssertNil(SlashCommandParser.parse("/"))
    }

    func testParseSupportsSkillIDsWithHyphens() {
        XCTAssertEqual(
            SlashCommandParser.parse("/daily-bgm rainy focus")!,
            SlashCommand(command: "daily-bgm", arguments: "rainy focus")
        )
    }

    func testMatchingCommandsFiltersByPrefixAndSortsByName() {
        let catalog = [
            SlashCommandDescriptor(name: "sound", kind: .app, description: "sound"),
            SlashCommandDescriptor(name: "skin", kind: .app, description: "skin"),
            SlashCommandDescriptor(name: "reset", kind: .builtin, description: "reset"),
        ]

        XCTAssertEqual(
            SlashCommandParser.matchingCommands(prefix: "s", catalog: catalog).map(\.name),
            ["skin", "sound"]
        )
    }
}
