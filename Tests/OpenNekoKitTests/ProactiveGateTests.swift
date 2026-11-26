import XCTest
@testable import OpenNekoKit

final class ProactiveGateTests: XCTestCase {
    private let today = "2026-11-26"

    private func decide(
        _ kind: ProactiveKind,
        spent: Int = 0,
        chattiness: Chattiness = .normal,
        muted: Set<ProactiveKind> = [],
        quiet: QuietReason? = nil
    ) -> ProactiveDecision {
        ProactiveGate.decide(
            kind,
            day: today,
            ledger: ProactiveLedger(day: today, spent: spent),
            chattiness: chattiness,
            muted: muted,
            quiet: quiet
        )
    }

    func testRequestedAlwaysSpeaks() {
        XCTAssertEqual(decide(.agentNotice, spent: 99, chattiness: .quiet, muted: Set(ProactiveKind.allCases), quiet: .meeting), .speak)
    }

    func testScheduledWaitsForQuietToPassButIgnoresBudget() {
        XCTAssertEqual(decide(.routine, quiet: .meeting), .hold(.meeting))
        XCTAssertEqual(decide(.whatsNew, spent: 99, chattiness: .quiet), .speak)
    }

    func testSuggestionsRespectMuteQuietAndBudget() {
        XCTAssertEqual(decide(.healthBreak), .speak)
        XCTAssertEqual(decide(.healthBreak, muted: [.healthBreak]), .drop(.muted))
        XCTAssertEqual(decide(.dailyRitual, quiet: .presenting), .drop(.quiet(.presenting)))
        XCTAssertEqual(decide(.memorySuggestion, spent: 3, chattiness: .quiet), .drop(.budget))
        XCTAssertEqual(decide(.memorySuggestion, spent: 3, chattiness: .normal), .speak)
        XCTAssertEqual(decide(.neighbor, spent: 15, chattiness: .chatty), .drop(.budget))
    }

    func testLedgerCountsOnlySuggestionsAndResetsDaily() {
        var ledger = ProactiveLedger()
        ledger.record(.agentNotice, day: today)
        ledger.record(.routine, day: today)
        XCTAssertEqual(ledger.spent(on: today), 0)
        ledger.record(.healthBreak, day: today)
        ledger.record(.neighbor, day: today)
        XCTAssertEqual(ledger.spent(on: today), 2)
        XCTAssertEqual(ledger.spent(on: "2026-11-27"), 0)
        ledger.record(.healthBreak, day: "2026-11-27")
        XCTAssertEqual(ledger.spent(on: "2026-11-27"), 1)
    }

    func testBudgets() {
        XCTAssertEqual(Chattiness.allCases.map(\.dailyBudget), [3, 8, 15])
        XCTAssertFalse(ProactiveKind.agentNotice.isMutable)
        XCTAssertFalse(ProactiveKind.routine.isMutable)
        XCTAssertTrue(ProactiveKind.healthBreak.isMutable)
    }

    func testQuietContextUsesOnlyBundleIDAndFullScreen() {
        XCTAssertEqual(QuietContext.reason(frontmostBundleID: "us.zoom.xos", frontWindowFillsScreen: false), .meeting)
        XCTAssertEqual(QuietContext.reason(frontmostBundleID: "com.apple.iWork.Keynote", frontWindowFillsScreen: true), .presenting)
        XCTAssertNil(QuietContext.reason(frontmostBundleID: "com.apple.iWork.Keynote", frontWindowFillsScreen: false))
        XCTAssertEqual(QuietContext.reason(frontmostBundleID: "com.apple.TV", frontWindowFillsScreen: true), .watching)
        XCTAssertNil(QuietContext.reason(frontmostBundleID: "com.microsoft.VSCode", frontWindowFillsScreen: true))
        XCTAssertNil(QuietContext.reason(frontmostBundleID: nil, frontWindowFillsScreen: true))
    }

    func testStopRequestsAreShortAndExplicit() {
        for text in ["그만", "그만해!", "그만해줘요", "이제 그만", "stop", "Stop it.", "don't remind me", "やめて", "别说了"] {
            XCTAssertTrue(ProactiveMute.isStopRequest(text), text)
        }
        for text in ["그만두고 싶은 회사 얘기 들어줄래?", "stop words in NLP", "", "점심 뭐 먹지", "how do I stop a process"] {
            XCTAssertFalse(ProactiveMute.isStopRequest(text), text)
        }
    }

    func testStopTargetsOnlyARecentMutableSuggestion() {
        XCTAssertEqual(ProactiveMute.target(lastSuggestion: .healthBreak, shownAt: 100, now: 150), .healthBreak)
        XCTAssertNil(ProactiveMute.target(lastSuggestion: .healthBreak, shownAt: 100, now: 400))
        XCTAssertNil(ProactiveMute.target(lastSuggestion: .routine, shownAt: 100, now: 110))
        XCTAssertNil(ProactiveMute.target(lastSuggestion: nil, shownAt: nil, now: 110))
    }

    func testSettingsRoundTripDropsUnmutableKinds() throws {
        XCTAssertEqual(AppSettings.defaults.chattiness, .normal)
        XCTAssertEqual(AppSettings.defaults.mutedProactiveKinds, [])

        let decoded = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(#"{"chattiness":"quiet","mutedProactiveKinds":["healthBreak","routine","bogus"]}"#.utf8)
        )
        XCTAssertEqual(decoded.chattiness, .quiet)
        XCTAssertEqual(decoded.mutedProactiveKinds, [.healthBreak])

        let again = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(again, decoded)
    }

    func testCopyCoversEveryKindAndLanguage() {
        for language in ["ko", "en", "ja", "zh"] {
            for kind in ProactiveKind.allCases {
                XCTAssertFalse(ProactiveCopy.kindName(kind, languageCode: language).isEmpty)
                XCTAssertTrue(ProactiveCopy.muted(kind, languageCode: language).contains(ProactiveCopy.kindName(kind, languageCode: language)))
            }
            for level in Chattiness.allCases {
                XCTAssertTrue(ProactiveCopy.chattinessTitle(level, languageCode: language).contains("\(level.dailyBudget)"))
            }
        }
    }
}
