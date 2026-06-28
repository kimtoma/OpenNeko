import XCTest
@testable import OpenNekoKit

final class AppUpdateDecisionTests: XCTestCase {
    func testParseBehindAcceptsPositiveCountsOnly() {
        XCTAssertEqual(AppUpdateDecision.parseBehind("3\n"), 3)
        XCTAssertEqual(AppUpdateDecision.parseBehind("0"), 0)
        XCTAssertEqual(AppUpdateDecision.parseBehind("-2"), 0)
        XCTAssertEqual(AppUpdateDecision.parseBehind("nope"), 0)
    }

    func testDirtyIgnoresBlankStatusOnly() {
        XCTAssertFalse(AppUpdateDecision.isDirty(""))
        XCTAssertFalse(AppUpdateDecision.isDirty(" \n\t"))
        XCTAssertTrue(AppUpdateDecision.isDirty(" M App/OpenNekoApp.swift\n"))
    }

    func testDecisionMatchesElectronUpdaterRules() {
        XCTAssertEqual(
            AppUpdateDecision.decide(isGit: false, behind: 4, dirty: false),
            AppUpdateDecision(available: false, reason: .notGit, behind: 0)
        )
        XCTAssertEqual(
            AppUpdateDecision.decide(isGit: true, behind: 4, dirty: true),
            AppUpdateDecision(available: false, reason: .dirty, behind: 4)
        )
        XCTAssertEqual(
            AppUpdateDecision.decide(isGit: true, behind: 4, dirty: false),
            AppUpdateDecision(available: true, reason: .behind, behind: 4)
        )
        XCTAssertEqual(
            AppUpdateDecision.decide(isGit: true, behind: 0, dirty: false),
            AppUpdateDecision(available: false, reason: .upToDate, behind: 0)
        )
    }

    func testMenuTitlesStayShortForMenuBar() {
        let states: [AppUpdateStatus] = [
            .idle,
            .checking,
            .available(behind: 12, branch: "main"),
            .updating,
        ]

        for state in states {
            XCTAssertLessThanOrEqual(state.menuTitle.count, 20)
        }
    }

    func testLocalizedUpdateCopy() {
        let available = AppUpdateStatus.available(behind: 2, branch: "main")

        XCTAssertEqual(available.menuTitle(languageCode: "en"), "Update (2)")
        XCTAssertEqual(available.bubbleText(languageCode: "en"), "2 update(s) available, nya~")
        XCTAssertEqual(AppUpdateStatus.upToDate.bubbleText(languageCode: "ja"), "最新版だにゃ ✓")
        XCTAssertEqual(AppUpdateStatus.checking.menuTitle(languageCode: "zh"), "正在检查更新")
    }

    func testUpdateBubbleCopyKeepsCatVoiceInSupportedLanguages() {
        XCTAssertTrue(AppUpdateStatus.checking.bubbleText(languageCode: "ko").contains("냥"))
        XCTAssertTrue(AppUpdateStatus.checkFailed.bubbleText(languageCode: "en").contains("nya"))
        XCTAssertTrue(AppUpdateStatus.dirty(behind: 1).bubbleText(languageCode: "ja").contains("にゃ"))
        XCTAssertTrue(AppUpdateStatus.updating.bubbleText(languageCode: "zh").contains("喵"))
    }
}
