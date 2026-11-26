import XCTest
@testable import OpenNekoKit

final class RoutineTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    /// 2026-11-26 is a Thursday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func routine(
        _ id: String = "r",
        hour: Int = 9,
        minute: Int = 0,
        days: RoutineDays = .everyday,
        enabled: Bool = true,
        prompt: String = "brief me",
        lastRunDay: String? = nil
    ) -> Routine {
        Routine(id: id, title: "T", prompt: prompt, hour: hour, minute: minute, days: days, enabled: enabled, lastRunDay: lastRunDay)
    }

    func testDaysUseCalendarWeekdays() {
        XCTAssertTrue(RoutineDays.weekdays.includes(weekday: 2))
        XCTAssertTrue(RoutineDays.weekdays.includes(weekday: 6))
        XCTAssertFalse(RoutineDays.weekdays.includes(weekday: 1))
        XCTAssertFalse(RoutineDays.weekdays.includes(weekday: 7))
        XCTAssertTrue(RoutineDays.weekends.includes(weekday: 7))
        XCTAssertTrue(RoutineDays.everyday.includes(weekday: 4))
    }

    func testDueOnlyAfterTheTimeAndWithinCatchUpWindow() {
        let r = routine()
        XCTAssertTrue(RoutineScheduler.due([r], now: date(26, 8, 59), calendar: calendar).isEmpty)
        XCTAssertEqual(RoutineScheduler.due([r], now: date(26, 9, 0), calendar: calendar).map(\.id), ["r"])
        XCTAssertEqual(RoutineScheduler.due([r], now: date(26, 10, 59), calendar: calendar).map(\.id), ["r"])
        XCTAssertTrue(RoutineScheduler.due([r], now: date(26, 11, 1), calendar: calendar).isEmpty, "too late after sleep")
    }

    func testRunsOncePerDay() {
        let now = date(26, 9, 5)
        let marked = RoutineScheduler.markingRan("r", in: [routine()], now: now, calendar: calendar)
        XCTAssertEqual(marked.first?.lastRunDay, "2026-11-26")
        XCTAssertTrue(RoutineScheduler.due(marked, now: date(26, 9, 30), calendar: calendar).isEmpty)
        XCTAssertEqual(RoutineScheduler.due(marked, now: date(27, 9, 0), calendar: calendar).count, 1)
    }

    func testSkipsDisabledEmptyAndWrongDay() {
        let now = date(28, 9, 10) // Saturday
        let routines = [
            routine("off", enabled: false),
            routine("empty", prompt: "   "),
            routine("weekday", days: .weekdays),
            routine("weekend", days: .weekends),
        ]
        XCTAssertEqual(RoutineScheduler.due(routines, now: now, calendar: calendar).map(\.id), ["weekend"])
    }

    func testNextRunSkipsTodayWhenPastOrAlreadyRun() {
        let r = routine(hour: 8, minute: 30, days: .weekdays)
        XCTAssertEqual(RoutineScheduler.nextRun(for: r, after: date(26, 8, 0), calendar: calendar), date(26, 8, 30))
        XCTAssertEqual(RoutineScheduler.nextRun(for: r, after: date(26, 9, 0), calendar: calendar), date(27, 8, 30))
        // Friday evening → Monday.
        XCTAssertEqual(RoutineScheduler.nextRun(for: r, after: date(27, 20, 0), calendar: calendar), date(30, 8, 30))
        XCTAssertNil(RoutineScheduler.nextRun(for: routine(enabled: false), after: date(26, 8, 0), calendar: calendar))
    }

    func testSavingANewRoutineWhoseTimePassedDoesNotFireImmediately() {
        let now = date(26, 10, 0)
        let saved = RoutineScheduler.reconcile(edited: [routine(hour: 9)], previous: [], now: now, calendar: calendar)
        XCTAssertEqual(saved.first?.lastRunDay, "2026-11-26")
        XCTAssertTrue(RoutineScheduler.due(saved, now: now, calendar: calendar).isEmpty)

        let later = RoutineScheduler.reconcile(edited: [routine(hour: 11)], previous: [], now: now, calendar: calendar)
        XCTAssertNil(later.first?.lastRunDay)
        XCTAssertEqual(RoutineScheduler.due(later, now: date(26, 11, 0), calendar: calendar).count, 1)
    }

    func testEditingOnlyThePromptKeepsTheLastRun() {
        let now = date(26, 10, 0)
        let old = routine(lastRunDay: "2026-11-25")
        var edited = old
        edited.prompt = "new prompt"
        let saved = RoutineScheduler.reconcile(edited: [edited], previous: [old], now: now, calendar: calendar)
        XCTAssertEqual(saved.first?.lastRunDay, "2026-11-25", "prompt edits must not change the schedule")
        XCTAssertEqual(saved.first?.prompt, "new prompt")
    }

    func testReconcileDropsDuplicatesAndCapsCount() {
        let many = (0..<20).map { routine("r\($0)", hour: 23, minute: 59) } + [routine("r0", hour: 23, minute: 59)]
        let saved = RoutineScheduler.reconcile(edited: many, previous: [], now: date(26, 10, 0), calendar: calendar)
        XCTAssertEqual(saved.count, RoutineScheduler.maxRoutines)
        XCTAssertEqual(Set(saved.map(\.id)).count, saved.count)
    }

    func testNormalizationClampsAndTrims() {
        let r = Routine(id: "x", title: "  " + String(repeating: "a", count: 80), prompt: " hi ", hour: 30, minute: -5, folder: "  ")
        XCTAssertEqual(r.title.count, Routine.titleLimit)
        XCTAssertEqual(r.prompt, "hi")
        XCTAssertEqual(r.hour, 23)
        XCTAssertEqual(r.minute, 0)
        XCTAssertNil(r.folder)
        XCTAssertEqual(r.timeText, "23:00")
    }

    func testDecodingIsTolerantAndSettingsRoundTrip() throws {
        let decoded = try JSONDecoder().decode(Routine.self, from: Data(#"{"title":"아침","prompt":"hi","hour":7}"#.utf8))
        XCTAssertEqual(decoded.hour, 7)
        XCTAssertEqual(decoded.minute, 0)
        XCTAssertEqual(decoded.days, .everyday)
        XCTAssertFalse(decoded.id.isEmpty)

        var settings = AppSettings.defaults
        XCTAssertTrue(settings.routines.isEmpty)
        settings.routines = [routine(), RoutineTemplate.repoDigest.routine(id: "g", languageCode: "en")]
        let roundTrip = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(roundTrip.routines, settings.routines)
    }

    func testChatPromptCarriesTitleAndDateHeader() {
        let r = routine()
        let ko = RoutineScheduler.chatPrompt(for: r, now: date(26, 9, 0), languageCode: "ko", calendar: calendar)
        XCTAssertTrue(ko.hasSuffix("\nbrief me"))
        XCTAssertTrue(ko.contains("\"T\""))
        XCTAssertTrue(ko.contains("2026"))
        let en = RoutineScheduler.chatPrompt(for: r, now: date(26, 9, 0), languageCode: "en", calendar: calendar)
        XCTAssertTrue(en.contains("Scheduled routine"))
    }

    func testTemplatesAndCopyCoverEveryLanguage() {
        for language in AppLanguage.supportedCodes {
            for template in RoutineTemplate.allCases {
                let r = template.routine(id: "t", languageCode: language)
                XCTAssertFalse(r.title.isEmpty)
                XCTAssertFalse(r.prompt.isEmpty)
                XCTAssertNil(r.folder)
            }
            for key in RoutineCopy.Key.allCases {
                XCTAssertFalse(RoutineCopy.text(key, languageCode: language).isEmpty)
            }
            XCTAssertLessThanOrEqual(RoutineCopy.starting(routine(), languageCode: language).count, 40)
            XCTAssertFalse(RoutineCopy.nextRun(nil, languageCode: language, calendar: calendar).isEmpty)
        }
        XCTAssertTrue(RoutineTemplate.repoDigest.needsFolder)
        XCTAssertFalse(RoutineTemplate.morningBriefing.needsFolder)
    }
}
