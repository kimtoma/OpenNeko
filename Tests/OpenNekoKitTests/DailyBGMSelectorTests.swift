import XCTest
@testable import OpenNekoKit

final class DailyBGMSelectorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testStopCommandsAcrossLanguagesAndCase() {
        for text in ["stop", "OFF", "Pause", "정지", "중지", "끄기"] {
            XCTAssertTrue(DailyBGMSelector.isStopCommand(text), text)
        }
    }

    func testNonStopPreferencesAreNotStopCommands() {
        for text in ["lofi", "재즈", "", "stop the music"] {
            XCTAssertFalse(DailyBGMSelector.isStopCommand(text), text)
        }
    }

    func testDateKeyFormatsLocalDate() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 9, minute: 30))!

        XCTAssertEqual(DailyBGMSelector.dateKey(date, calendar: calendar), "2026-06-24")
    }

    func testPickDailyBGMUsesSamePresetForSameDate() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 9))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 23))!

        let first = DailyBGMSelector.pick(date: morning, languageCode: "en", calendar: calendar)
        let second = DailyBGMSelector.pick(date: night, languageCode: "en", calendar: calendar)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.dateKey, "2026-06-24")
        XCTAssertEqual(first.service, "YouTube Music")
        XCTAssertTrue(first.url.absoluteString.hasPrefix("https://music.youtube.com/search?q="))
    }

    func testPreferenceIsReflectedInQueryAndSeed() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 9))!

        let bgm = DailyBGMSelector.pick(
            date: date,
            preference: "jazz cafe",
            languageCode: "ko",
            calendar: calendar
        )
        let decodedURL = bgm.url.absoluteString.removingPercentEncoding ?? ""

        XCTAssertTrue(bgm.query.contains("jazz cafe"))
        XCTAssertTrue(decodedURL.contains("jazz cafe"))
        XCTAssertTrue(bgm.personalized)
    }

    func testProfilePersonalizesPresetButDoesNotLeakToURL() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 9))!

        let bgm = DailyBGMSelector.pick(
            date: date,
            profile: UserProfile(name: "Alice", birthDate: "1990-01-02", calendar: "solar"),
            languageCode: "en",
            calendar: calendar
        )
        let decodedURL = bgm.url.absoluteString.removingPercentEncoding ?? ""

        XCTAssertTrue(bgm.personalized)
        XCTAssertFalse(decodedURL.contains("Alice"))
        XCTAssertFalse(decodedURL.contains("1990-01-02"))
    }

    func testBuildYouTubeMusicSearchURLEncodesQuery() {
        XCTAssertEqual(
            DailyBGMSelector.buildYouTubeMusicSearchURL(query: "lofi coding BGM").absoluteString,
            "https://music.youtube.com/search?q=lofi%20coding%20BGM"
        )
    }

    func testNormalizePreferenceRemovesUnsafeAndLongInput() {
        let text = DailyBGMSelector.normalizePreference("  <jazz>\n\(String(repeating: "x", count: 120))")

        XCTAssertFalse(text.contains("<"))
        XCTAssertFalse(text.contains(">"))
        XCTAssertLessThanOrEqual(text.count, 80)
    }

    func testPresetsIncludeYouTubeMusicSearchFields() {
        for preset in DailyBGMSelector.presets {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.terms.isEmpty)
        }
    }
}
