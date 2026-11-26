import XCTest
@testable import OpenNekoKit

final class NekoToolTests: XCTestCase {
    func testExtractsOneValidCallAndStripsMarkup() {
        let reply = """
        라면 타이머 맞춰줄게냥!
        <neko-tool>{"tool":"timer","minutes":3,"label":"라면"}</neko-tool>
        """
        let result = NekoToolProtocol.extract(from: reply)
        XCTAssertEqual(result.text, "라면 타이머 맞춰줄게냥!")
        XCTAssertEqual(result.calls, [.timer(seconds: 180, label: "라면")])
        XCTAssertEqual(result.rejectedCount, 0)
    }

    func testOnlyFirstCallIsKeptAndOthersCountAsRejected() {
        let reply = #"a<neko-tool>{"tool":"clipboard","text":"x"}</neko-tool>b<neko-tool>{"tool":"clipboard","text":"y"}</neko-tool>c"#
        let result = NekoToolProtocol.extract(from: reply)
        XCTAssertEqual(result.text, "abc")
        XCTAssertEqual(result.calls, [.copyToClipboard("x")])
        XCTAssertEqual(result.rejectedCount, 1)
    }

    func testRejectsUnknownUnsafeOrOutOfRangeCalls() {
        let bad = [
            #"{"tool":"shell","command":"rm -rf /"}"#,
            #"{"tool":"open_url","url":"file:///etc/passwd"}"#,
            #"{"tool":"open_url","url":"javascript:alert(1)"}"#,
            #"{"tool":"open_url","url":"https://user:pw@example.com"}"#,
            #"{"tool":"timer","minutes":0}"#,
            #"{"tool":"timer","minutes":2000}"#,
            #"{"tool":"timer","minutes":true}"#,
            #"{"tool":"reminder","minutes":5}"#,
            #"{"tool":"clipboard","text":""}"#,
            "not json",
        ]
        for body in bad {
            let result = NekoToolProtocol.extract(from: "<neko-tool>\(body)</neko-tool>")
            XCTAssertEqual(result.calls, [], body)
            XCTAssertEqual(result.rejectedCount, 1, body)
        }
    }

    func testAcceptsSafeURLAndMixedDuration() {
        let url = NekoToolProtocol.extract(from: #"<neko-tool>{"tool":"open_url","url":" https://kimtoma.com/blog "}</neko-tool>"#)
        XCTAssertEqual(url.calls, [.openURL(URL(string: "https://kimtoma.com/blog")!)])

        let reminder = NekoToolProtocol.extract(from: #"<neko-tool>{"tool":"reminder","minutes":"1","seconds":30,"message":"stand\nup"}</neko-tool>"#)
        XCTAssertEqual(reminder.calls, [.reminder(seconds: 90, message: "stand up")])
    }

    func testUnclosedTagIsDroppedFromText() {
        let result = NekoToolProtocol.extract(from: #"hi <neko-tool>{"tool":"timer""#)
        XCTAssertEqual(result.text, "hi")
        XCTAssertEqual(result.calls, [])
        XCTAssertEqual(result.rejectedCount, 1)
    }

    func testStripPartialHidesHalfStreamedTag() {
        XCTAssertEqual(NekoToolProtocol.stripPartial("ok <neko-t"), "ok")
        XCTAssertEqual(NekoToolProtocol.stripPartial(#"ok <neko-tool>{"tool":"#), "ok")
        XCTAssertEqual(NekoToolProtocol.stripPartial("plain <b> text"), "plain <b> text")
    }

    func testInstructionsMentionEveryToolInEveryLanguage() {
        for language in ["ko", "en", "ja", "zh"] {
            let text = NekoToolProtocol.instructions(languageCode: language)
            for tool in ["timer", "reminder", "clipboard", "open_url"] {
                XCTAssertTrue(text.contains(tool), "\(language) \(tool)")
            }
        }
    }

    func testCopyIsLocalizedAndShort() {
        let calls: [NekoToolCall] = [
            .timer(seconds: 3_725, label: "tea"),
            .reminder(seconds: 600, message: "stretch"),
            .copyToClipboard("x"),
            .openURL(URL(string: "https://example.com/a")!),
        ]
        for call in calls {
            let texts = ["ko", "en", "ja", "zh"].map { NekoToolCopy.approval(call, languageCode: $0) }
            XCTAssertEqual(Set(texts).count, 4)
            XCTAssertTrue(texts.allSatisfy { $0.count <= 70 }, "\(texts)")
            XCTAssertEqual(Set(["ko", "en", "ja", "zh"].map { NekoToolCopy.done(call, languageCode: $0) }).count, 4)
        }
        XCTAssertEqual(NekoToolCopy.approval(.timer(seconds: 3_725, label: "tea"), languageCode: "en"), "⏱ Set a 1h 2m 5s timer (tea)? Click to allow")
        XCTAssertEqual(NekoToolCopy.fired(.timer(seconds: 60, label: ""), languageCode: "ko"), "⏰ 시간 다 됐다냥!")
        XCTAssertNil(NekoToolCopy.fired(.copyToClipboard("x"), languageCode: "ko"))
        XCTAssertEqual(NekoToolCall.openURL(URL(string: "https://a.com")!).name, "open_url")
    }

    func testNativeToolsSettingDefaultsOnAndRoundTrips() throws {
        XCTAssertTrue(AppSettings.defaults.nativeToolsEnabled)
        var settings = AppSettings.defaults
        settings.nativeToolsEnabled = false
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertFalse(decoded.nativeToolsEnabled)
        XCTAssertFalse(AppSettingsDebugSnapshot(settings: settings).nativeToolsEnabled)
        XCTAssertEqual(SettingsCopy.text(.nativeTools, languageCode: "en"), "Cat tools")
    }
}
