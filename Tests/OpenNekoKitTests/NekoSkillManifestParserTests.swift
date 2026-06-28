import XCTest
@testable import OpenNekoKit

final class NekoSkillManifestParserTests: XCTestCase {
    func testParseSkillMarkdownFrontMatter() throws {
        let text = """
        ---
        name: 번역
        description: 복사한 텍스트 번역
        input: clipboard
        ---
        번역 결과만 답해줘.
        """

        let skill = try NekoSkillManifestParser.parse(
            id: "translate",
            source: .bundled,
            text: text
        )

        XCTAssertEqual(skill.id, "translate")
        XCTAssertEqual(skill.name, "번역")
        XCTAssertEqual(skill.description, "복사한 텍스트 번역")
        XCTAssertEqual(skill.input, .clipboard)
        XCTAssertEqual(skill.body, "번역 결과만 답해줘.")
        XCTAssertEqual(skill.source, .bundled)
    }

    func testPromptInputIsDefault() throws {
        let text = """
        ---
        name: 쉽게 설명
        description: 설명
        ---
        쉽게 설명해줘.
        """

        let skill = try NekoSkillManifestParser.parse(id: "explain", source: .user, text: text)

        XCTAssertEqual(skill.input, .prompt)
    }

    func testSkillInputTitleUsesSelectedLanguage() {
        XCTAssertEqual(NekoSkillInput.prompt.title(languageCode: "en"), "Input")
        XCTAssertEqual(NekoSkillInput.clipboard.title(languageCode: "ja"), "クリップボード")
        XCTAssertEqual(NekoSkillInput.none.title(languageCode: "zh"), "运行")
    }

    func testMissingBodyThrows() {
        let text = """
        ---
        name: 빈 스킬
        ---

        """

        XCTAssertThrowsError(try NekoSkillManifestParser.parse(id: "empty", source: .user, text: text)) { error in
            XCTAssertEqual(error as? NekoSkillManifestError, .missingBody)
        }
    }
}
