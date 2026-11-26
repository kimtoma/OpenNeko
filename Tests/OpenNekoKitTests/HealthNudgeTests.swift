import XCTest
@testable import OpenNekoKit

final class HealthNudgeTests: XCTestCase {
    private let policy = HealthNudgePolicy(
        workSession: 100,
        breakResetsAfter: 30,
        stillWorkingWithin: 10,
        minimumGap: 80,
        dailyLimit: 2
    )

    /// Types once every 5 seconds from `start` through `end`.
    private func type(_ tracker: inout HealthNudgeTracker, from start: TimeInterval, to end: TimeInterval) {
        var t = start
        while t <= end {
            tracker.recordActivity(at: t)
            t += 5
        }
    }

    func testNoNudgeBeforeWorkSessionLength() {
        var tracker = HealthNudgeTracker(policy: policy)
        type(&tracker, from: 0, to: 95)
        XCTAssertNil(tracker.nextNudge(at: 95, day: 1, enabled: true))
    }

    func testNudgesAfterContinuousWorkAndRotatesKinds() {
        var tracker = HealthNudgeTracker(policy: policy)
        type(&tracker, from: 0, to: 100)
        XCTAssertEqual(tracker.nextNudge(at: 100, day: 1, enabled: true), .stretch)
        XCTAssertEqual(tracker.nudgesToday, 1)

        // Session restarts at the nudge; next one needs another full session.
        type(&tracker, from: 105, to: 195)
        XCTAssertNil(tracker.nextNudge(at: 195, day: 1, enabled: true))
        type(&tracker, from: 200, to: 200)
        XCTAssertEqual(tracker.nextNudge(at: 200, day: 1, enabled: true), .eyes)
    }

    func testRealBreakRestartsSession() {
        var tracker = HealthNudgeTracker(policy: policy)
        type(&tracker, from: 0, to: 60)
        // 40s gap >= breakResetsAfter (30s)
        type(&tracker, from: 100, to: 150)
        XCTAssertEqual(tracker.sessionStart, 100)
        XCTAssertNil(tracker.nextNudge(at: 150, day: 1, enabled: true))
    }

    func testNoNudgeWhenAwayFromKeyboard() {
        var tracker = HealthNudgeTracker(policy: policy)
        type(&tracker, from: 0, to: 100)
        XCTAssertNil(tracker.nextNudge(at: 120, day: 1, enabled: true), "idle for 20s > stillWorkingWithin")
    }

    func testDisabledNeverNudges() {
        var tracker = HealthNudgeTracker(policy: policy)
        type(&tracker, from: 0, to: 100)
        XCTAssertNil(tracker.nextNudge(at: 100, day: 1, enabled: false))
        XCTAssertEqual(tracker.nudgesToday, 0)
    }

    func testMinimumGapBetweenNudges() {
        let tightGap = HealthNudgePolicy(workSession: 20, breakResetsAfter: 30, stillWorkingWithin: 10, minimumGap: 80, dailyLimit: 9)
        var tracker = HealthNudgeTracker(policy: tightGap)
        type(&tracker, from: 0, to: 20)
        XCTAssertNotNil(tracker.nextNudge(at: 20, day: 1, enabled: true))
        type(&tracker, from: 25, to: 60)
        XCTAssertNil(tracker.nextNudge(at: 60, day: 1, enabled: true), "within minimumGap")
        type(&tracker, from: 65, to: 100)
        XCTAssertNotNil(tracker.nextNudge(at: 100, day: 1, enabled: true))
    }

    func testDailyLimitResetsOnNewDay() {
        let quick = HealthNudgePolicy(workSession: 10, breakResetsAfter: 30, stillWorkingWithin: 10, minimumGap: 0, dailyLimit: 2)
        var tracker = HealthNudgeTracker(policy: quick)
        type(&tracker, from: 0, to: 10)
        XCTAssertNotNil(tracker.nextNudge(at: 10, day: 1, enabled: true))
        type(&tracker, from: 15, to: 20)
        XCTAssertNotNil(tracker.nextNudge(at: 20, day: 1, enabled: true))
        type(&tracker, from: 25, to: 30)
        XCTAssertNil(tracker.nextNudge(at: 30, day: 1, enabled: true), "daily limit reached")
        XCTAssertNotNil(tracker.nextNudge(at: 30, day: 2, enabled: true))
    }

    func testStandardPolicyValues() {
        XCTAssertEqual(HealthNudgePolicy.standard.workSession, 50 * 60)
        XCTAssertEqual(HealthNudgePolicy.standard.dailyLimit, 6)
    }

    func testKindsMapToCatStatesAndLocalizedCopy() {
        XCTAssertEqual(HealthNudgeKind.stretch.catState, .yawn)
        XCTAssertEqual(HealthNudgeKind.water.catState, .lunch)
        for kind in HealthNudgeKind.allCases {
            let texts = ["ko", "en", "ja", "zh"].map { NekoBubbleCopy.healthNudge(kind, languageCode: $0) }
            XCTAssertEqual(Set(texts).count, 4)
            XCTAssertTrue(texts[0].contains("냥"))
            XCTAssertLessThanOrEqual(texts[1].count, 48, "bubble copy stays short")
        }
    }

    func testSettingDefaultsOnAndRoundTrips() throws {
        XCTAssertTrue(AppSettings.defaults.healthCompanionEnabled)
        var settings = AppSettings.defaults
        settings.healthCompanionEnabled = false
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertFalse(decoded.healthCompanionEnabled)
        XCTAssertFalse(AppSettingsDebugSnapshot(settings: settings).healthCompanionEnabled)

        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"selectedSkinID":"default"}"#.utf8))
        XCTAssertTrue(legacy.healthCompanionEnabled)
    }

    func testCopyKeysAreLocalized() {
        XCTAssertEqual(SettingsCopy.text(.healthCompanion, languageCode: "ko"), "건강 알림")
        XCTAssertEqual(SettingsCopy.text(.healthCompanion, languageCode: "en"), "Break reminders")
    }
}
