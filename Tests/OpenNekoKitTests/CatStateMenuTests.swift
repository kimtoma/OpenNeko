import XCTest
@testable import OpenNekoKit

final class CatStateMenuTests: XCTestCase {
    func testPreviewStatesMatchElectronTrayMenuCoverage() {
        XCTAssertEqual(
            CatStateMenu.previewStates,
            [.thinking, .coding, .typing, .success, .error, .walk, .jump, .yawn, .lunch, .nap, .idle]
        )
    }

    func testMenuTitlesStayShort() {
        let titles = CatState.allCases.map { CatStateMenu.title(for: $0) } + [
            CatStateMenu.catVisibilityTitle(isVisible: true),
            CatStateMenu.catVisibilityTitle(isVisible: false),
        ]

        XCTAssertTrue(titles.allSatisfy { $0.count <= 30 })
    }

    func testCatVisibilityTitleReflectsVisibleState() {
        XCTAssertEqual(CatStateMenu.catVisibilityTitle(isVisible: true), "고양이 숨기기")
        XCTAssertEqual(CatStateMenu.catVisibilityTitle(isVisible: false), "고양이 보이기")
    }

    func testLocalizedMenuTitlesUseSelectedLanguage() {
        XCTAssertEqual(CatStateMenu.catVisibilityTitle(isVisible: true, languageCode: "en"), "Hide Cat")
        XCTAssertEqual(CatStateMenu.title(for: .thinking, languageCode: "en"), "Thinking")
        XCTAssertEqual(CatStateMenu.title(for: .thinking, languageCode: "ja"), "考え中")
        XCTAssertEqual(CatStateMenu.title(for: .thinking, languageCode: "zh"), "思考中")
    }
}
