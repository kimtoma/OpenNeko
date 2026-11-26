import XCTest
@testable import OpenNekoKit

final class VoiceInputTests: XCTestCase {
    func testPermissionsAreRequestedInOrderAndDenialsFail() {
        XCTAssertEqual(VoiceInputPolicy.nextStep(microphone: .notDetermined, speech: .notDetermined, onDeviceSupported: true), .requestMicrophone)
        XCTAssertEqual(VoiceInputPolicy.nextStep(microphone: .granted, speech: .notDetermined, onDeviceSupported: true), .requestSpeechRecognition)
        XCTAssertEqual(VoiceInputPolicy.nextStep(microphone: .granted, speech: .granted, onDeviceSupported: true), .start)
        XCTAssertEqual(VoiceInputPolicy.nextStep(microphone: .denied, speech: .granted, onDeviceSupported: true), .fail(.microphoneDenied))
        XCTAssertEqual(VoiceInputPolicy.nextStep(microphone: .granted, speech: .denied, onDeviceSupported: true), .fail(.speechDenied))
    }

    func testNeverFallsBackToServerRecognition() {
        XCTAssertEqual(
            VoiceInputPolicy.nextStep(microphone: .granted, speech: .granted, onDeviceSupported: false),
            .fail(.onDeviceUnavailable)
        )
    }

    func testLocaleFollowsAppLanguage() {
        XCTAssertEqual(VoiceInputPolicy.localeIdentifier(languageCode: "ko"), "ko-KR")
        XCTAssertEqual(VoiceInputPolicy.localeIdentifier(languageCode: "en"), "en-US")
        XCTAssertEqual(VoiceInputPolicy.localeIdentifier(languageCode: "ja"), "ja-JP")
        XCTAssertEqual(VoiceInputPolicy.localeIdentifier(languageCode: "zh-Hans"), "zh-CN")
        XCTAssertEqual(VoiceInputPolicy.localeIdentifier(languageCode: nil), "ko-KR")
    }

    func testMergeKeepsTypedTextAndCapsLength() {
        XCTAssertEqual(VoiceInputPolicy.merged(base: "", transcript: " 안녕 "), "안녕")
        XCTAssertEqual(VoiceInputPolicy.merged(base: "/task ", transcript: "테스트 고쳐줘"), "/task 테스트 고쳐줘")
        XCTAssertEqual(VoiceInputPolicy.merged(base: "typed", transcript: "  "), "typed")
        let long = VoiceInputPolicy.merged(base: "", transcript: String(repeating: "가", count: 5_000))
        XCTAssertEqual(long.count, VoiceInputPolicy.maxCharacters)
    }

    func testDictationEndsOnSilenceNoSpeechOrMaxDuration() {
        // Still talking: no stop.
        XCTAssertFalse(VoiceInputPolicy.shouldAutoStop(startedAt: 0, lastChangeAt: 5, now: 6))
        // Paused after speaking.
        XCTAssertTrue(VoiceInputPolicy.shouldAutoStop(startedAt: 0, lastChangeAt: 5, now: 7.1))
        // Nothing heard yet, but give it time.
        XCTAssertFalse(VoiceInputPolicy.shouldAutoStop(startedAt: 0, lastChangeAt: nil, now: 5))
        XCTAssertTrue(VoiceInputPolicy.shouldAutoStop(startedAt: 0, lastChangeAt: nil, now: 8))
        // Hard cap even while the transcript keeps changing.
        XCTAssertTrue(VoiceInputPolicy.shouldAutoStop(startedAt: 0, lastChangeAt: 59.9, now: 60))
    }

    func testLateCallbacksFromAnEarlierDictationAreIgnored() {
        var sessions = VoiceDictationSessions()
        let first = sessions.next()
        XCTAssertTrue(sessions.isCurrent(first))
        let second = sessions.next()
        XCTAssertFalse(sessions.isCurrent(first))
        XCTAssertTrue(sessions.isCurrent(second))
        sessions.next() // cancel retires the current one too
        XCTAssertFalse(sessions.isCurrent(second))
        XCTAssertGreaterThan(VoiceInputPolicy.finalResultTimeout, 0)
        XCTAssertLessThan(VoiceInputPolicy.finalResultTimeout, VoiceInputPolicy.silenceTimeout)
    }

    func testCopyForEveryLanguage() {
        let failures: [VoiceInputFailure] = [.microphoneDenied, .speechDenied, .onDeviceUnavailable, .audioUnavailable, .nothingHeard]
        for language in AppLanguage.supportedCodes {
            XCTAssertFalse(VoiceInputCopy.listening(languageCode: language).isEmpty)
            XCTAssertFalse(VoiceInputCopy.micHelp(languageCode: language).isEmpty)
            XCTAssertFalse(VoiceInputCopy.stopHelp(languageCode: language).isEmpty)
            for failure in failures {
                XCTAssertFalse(VoiceInputCopy.failure(failure, languageCode: language).isEmpty)
            }
        }
        XCTAssertNotEqual(VoiceInputCopy.listening(languageCode: "en"), VoiceInputCopy.listening(languageCode: "ko"))
    }
}
