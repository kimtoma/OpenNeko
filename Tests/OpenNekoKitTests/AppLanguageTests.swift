import XCTest
@testable import OpenNekoKit

final class AppLanguageTests: XCTestCase {
    func testNormalizedAcceptsLanguageAndLocaleCodes() {
        XCTAssertEqual(AppLanguage.normalized("ko"), "ko")
        XCTAssertEqual(AppLanguage.normalized("ko-KR"), "ko")
        XCTAssertEqual(AppLanguage.normalized("en_US"), "en")
        XCTAssertEqual(AppLanguage.normalized("ja-JP"), "ja")
        XCTAssertEqual(AppLanguage.normalized("zh-Hans-CN"), "zh")
        XCTAssertEqual(AppLanguage.normalized("zh_CN"), "zh")
        XCTAssertNil(AppLanguage.normalized("fr-FR"))
    }

    func testResolvedUsesStoredLanguageBeforeLocale() {
        XCTAssertEqual(AppLanguage.resolved("ja", localeIdentifier: "ko-KR"), "ja")
        XCTAssertEqual(AppLanguage.resolved("ko-KR", localeIdentifier: "en-US"), "ko")
        XCTAssertEqual(AppLanguage.resolved(nil, localeIdentifier: "zh-Hans-CN"), "zh")
        XCTAssertEqual(AppLanguage.resolved("zz", localeIdentifier: "ja-JP"), "ja")
        XCTAssertEqual(AppLanguage.resolved(nil, localeIdentifier: "fr-FR"), "en")
    }
}
