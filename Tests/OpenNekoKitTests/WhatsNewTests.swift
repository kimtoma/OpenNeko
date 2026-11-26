import XCTest
@testable import OpenNekoKit

final class WhatsNewTests: XCTestCase {
    private let withAI = WhatsNew.Context(onDeviceModelAvailable: true)
    private let withoutAI = WhatsNew.Context(onDeviceModelAvailable: false)

    func testAppleIntelligenceIsShownOnlyWhenAvailable() {
        XCTAssertTrue(WhatsNew.features(context: withAI).contains(.appleIntelligence))
        XCTAssertFalse(WhatsNew.features(context: withoutAI).contains(.appleIntelligence))
        XCTAssertEqual(WhatsNew.features(context: withAI).count, WhatsNewFeature.allCases.count)
    }

    func testPendingFeaturesFollowTheLastSeenRevision() {
        XCTAssertEqual(WhatsNew.pendingFeatures(lastSeenRevision: 0, context: withoutAI).count, WhatsNewFeature.allCases.count - 1)
        XCTAssertTrue(WhatsNew.pendingFeatures(lastSeenRevision: WhatsNew.currentRevision, context: withAI).isEmpty)
        for feature in WhatsNewFeature.allCases {
            XCTAssertLessThanOrEqual(feature.revision, WhatsNew.currentRevision)
        }
    }

    func testTourWaitsForFirstLaunchSetupAndRunsOncePerRevision() {
        XCTAssertFalse(WhatsNew.shouldOfferTour(hasCompletedFirstLaunch: false, lastSeenRevision: 0, context: withAI))
        XCTAssertTrue(WhatsNew.shouldOfferTour(hasCompletedFirstLaunch: true, lastSeenRevision: 0, context: withAI))
        XCTAssertFalse(WhatsNew.shouldOfferTour(
            hasCompletedFirstLaunch: true,
            lastSeenRevision: WhatsNew.currentRevision,
            context: withAI
        ))
    }

    func testTourStepsGoIntroFeaturesOutroThenEnd() {
        var tour = WhatsNewTour(features: [.selectedText, .catTools])
        XCTAssertEqual(tour.current, .intro(count: 2))
        XCTAssertEqual(tour.advance(), .feature(.selectedText, index: 1, count: 2))
        XCTAssertEqual(tour.advance(), .feature(.catTools, index: 2, count: 2))
        XCTAssertEqual(tour.advance(), .outro)
        XCTAssertNil(tour.advance())
        XCTAssertNil(tour.advance())
    }

    func testEmptyTourHasNoSteps() {
        var tour = WhatsNewTour(features: [])
        XCTAssertTrue(tour.isEmpty)
        XCTAssertNil(tour.current)
        XCTAssertNil(tour.advance())
    }

    func testCopyExistsForEveryLanguageAndStaysShort() {
        let steps: [WhatsNewTour.Step] = [.intro(count: 7), .outro]
            + WhatsNewFeature.allCases.map { .feature($0, index: 1, count: 7) }
        for language in AppLanguage.supportedCodes {
            for step in steps {
                let text = WhatsNewCopy.text(step, languageCode: language)
                XCTAssertFalse(text.isEmpty)
                XCTAssertLessThanOrEqual(text.count, 110, "\(language) \(step)")
            }
            XCTAssertFalse(WhatsNewCopy.menuTitle(languageCode: language).isEmpty)
            XCTAssertFalse(WhatsNewCopy.nextHint(languageCode: language).isEmpty)
        }
        XCTAssertNotEqual(
            WhatsNewCopy.text(.outro, languageCode: "en"),
            WhatsNewCopy.text(.outro, languageCode: "ko")
        )
    }

    func testLastSeenRevisionRoundTripsAndDefaultsToZero() throws {
        XCTAssertEqual(AppSettings.defaults.lastSeenWhatsNewRevision, 0)
        var settings = AppSettings.defaults
        settings.lastSeenWhatsNewRevision = WhatsNew.currentRevision
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.lastSeenWhatsNewRevision, WhatsNew.currentRevision)

        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"selectedSkinID":"default"}"#.utf8))
        XCTAssertEqual(legacy.lastSeenWhatsNewRevision, 0)
    }
}
