import XCTest
@testable import OpenNekoKit

final class SkillSuggestionTests: XCTestCase {
    private func skill(_ id: String, _ name: String, input: NekoSkillInput = .prompt, uses: [String] = []) -> NekoSkill {
        NekoSkill(id: id, name: name, description: "", input: input, body: "body", source: .bundled, uses: uses)
    }

    private lazy var skills = [
        skill("translate", "번역", input: .clipboard),
        skill("clipboard-summary", "클립보드 요약", input: .clipboard),
        skill("youtube-summary", "유튜브 링크 요약", input: .clipboard),
        skill("explain", "쉽게 설명"),
        skill("daily-fortune", "오늘의 운세", input: .none),
        skill("translate-en", "Translate"),
    ]

    private func suggest(_ message: String, disabled: Set<String> = [], already: Set<String> = []) -> String? {
        SkillSuggestion.suggest(message: message, skills: skills, disabledIDs: disabled, alreadySuggested: already)?.id
    }

    func testSuggestsOnlyWhenTheNameIsClearlyAskedFor() {
        XCTAssertEqual(suggest("이거 번역해줘"), "translate")
        XCTAssertEqual(suggest("유튜브 요약해줄 수 있어?"), "youtube-summary")
        XCTAssertEqual(suggest("이 개념 쉽게 설명해줘"), "explain")
        XCTAssertEqual(suggest("오늘 운세 어때?"), "daily-fortune")
        XCTAssertEqual(suggest("Can you translate this?"), "translate-en")

        XCTAssertNil(suggest("요약해줘"))
        XCTAssertNil(suggest("설명해줘"))
        XCTAssertNil(suggest("점심 뭐 먹지"))
        XCTAssertNil(suggest("/task 번역"))
        XCTAssertNil(suggest("번역"))
    }

    func testRespectsDisabledAndAlreadySuggested() {
        XCTAssertNil(suggest("이거 번역해줘", disabled: ["translate"]))
        XCTAssertNil(suggest("이거 번역해줘", already: ["translate"]))
    }

    func testUsesParsingAndConnectorHelpers() throws {
        let text = "---\nname: 이슈 정리\ndescription: 깃허브 이슈 요약\nuses: [github, \"notion\", bad name, github]\n---\n이슈를 정리해줘"
        let parsed = try NekoSkillManifestParser.parse(id: "issues", source: .user, text: text)
        XCTAssertEqual(parsed.uses, ["github", "notion"])
        XCTAssertEqual(try NekoSkillManifestParser.parse(id: "x", source: .user, text: "---\nname: x\nuses: files\n---\nbody").uses, ["files"])
        XCTAssertEqual(try NekoSkillManifestParser.parse(id: "x", source: .user, text: "---\nname: x\n---\nbody").uses, [])

        XCTAssertEqual(SkillSuggestion.missingConnectors(for: parsed, ready: ["github"]), ["notion"])

        let tools = [
            MCPTool(server: "files", name: "read", description: ""),
            MCPTool(server: "github", name: "search", description: ""),
        ]
        XCTAssertEqual(SkillSuggestion.prioritized(tools, for: parsed).map(\.server), ["github", "files"])
        XCTAssertEqual(SkillSuggestion.prioritized(tools, for: nil).map(\.server), ["files", "github"])

        let localized = NekoSkillLocalization.localize(
            NekoSkill(id: "translate", name: "번역", description: "", input: .clipboard, body: "b", source: .bundled, uses: ["deepl"]),
            languageCode: "en"
        )
        XCTAssertEqual(localized.uses, ["deepl"])
    }

    func testSuggestionKindIsMutableAndCopyIsLocalized() {
        XCTAssertEqual(ProactiveKind.skillSuggestion.priority, .suggestion)
        XCTAssertTrue(ProactiveKind.skillSuggestion.isMutable)
        let s = skill("translate", "Translate")
        for language in ["ko", "en", "ja", "zh"] {
            XCTAssertTrue(SkillSuggestionCopy.offer(s, languageCode: language).contains("Translate"))
            XCTAssertTrue(SkillSuggestionCopy.needsConnectors(["github"], languageCode: language).contains("github"))
        }
    }
}
