import XCTest
@testable import OpenNekoKit

final class NekoSkillLocalizationTests: XCTestCase {
    func testBundledSkillUsesSelectedLanguage() {
        let skill = makeSkill(id: "translate", source: .bundled)

        let english = NekoSkillLocalization.localize(skill, languageCode: "en")
        XCTAssertEqual(english.name, "Translate")
        XCTAssertEqual(english.description, "Translate copied text between Korean and English")
        XCTAssertTrue(english.body.contains("Return only the translation"))

        let japanese = NekoSkillLocalization.localize(skill, languageCode: "ja-JP")
        XCTAssertEqual(japanese.name, "翻訳")
        XCTAssertEqual(japanese.description, "コピーしたテキストを韓国語↔英語で翻訳")
        XCTAssertTrue(japanese.body.contains("翻訳結果だけ"))

        let chinese = NekoSkillLocalization.localize(skill, languageCode: "zh-Hans-CN")
        XCTAssertEqual(chinese.name, "翻译")
        XCTAssertEqual(chinese.description, "在韩语和英语之间翻译复制的文本")
        XCTAssertTrue(chinese.body.contains("只输出翻译结果"))
    }

    func testUnsupportedLanguageFallsBackToEnglish() {
        let skill = makeSkill(id: "daily-bgm", source: .bundled)

        let localized = NekoSkillLocalization.localize(skill, languageCode: "fr")

        XCTAssertEqual(localized.name, "Today's Random BGM")
        XCTAssertEqual(localized.description, "Open today's BGM playlist on YouTube Music")
        XCTAssertTrue(localized.body.contains("built-in action"))
    }

    func testUserSkillIsNotLocalized() {
        let skill = makeSkill(
            id: "translate",
            name: "My Translate",
            description: "Custom description",
            body: "Custom body",
            source: .user
        )

        let localized = NekoSkillLocalization.localize(skill, languageCode: "ja")

        XCTAssertEqual(localized, skill)
    }

    func testKnownBundledSkillsHaveTranslationsForSupportedLanguages() {
        let ids = [
            "clipboard-summary",
            "daily-fortune",
            "daily-bgm",
            "explain",
            "saju",
            "translate",
            "youtube-summary",
        ]

        for language in ["ko", "en", "ja", "zh"] {
            for id in ids {
                let original = makeSkill(id: id, source: .bundled)
                let localized = NekoSkillLocalization.localize(original, languageCode: language)

                XCTAssertFalse(localized.name.isEmpty, "\(id) missing \(language) name")
                XCTAssertFalse(localized.description.isEmpty, "\(id) missing \(language) description")
                XCTAssertFalse(localized.body.isEmpty, "\(id) missing \(language) body")
                XCTAssertNotEqual(localized.name, original.name, "\(id) did not localize for \(language)")
                XCTAssertEqual(localized.input, original.input)
                XCTAssertEqual(localized.source, .bundled)
            }
        }
    }

    private func makeSkill(
        id: String,
        name: String = "Original Name",
        description: String = "Original description",
        input: NekoSkillInput = .prompt,
        body: String = "Original body",
        source: NekoSkillSource
    ) -> NekoSkill {
        NekoSkill(
            id: id,
            name: name,
            description: description,
            input: input,
            body: body,
            source: source
        )
    }
}
