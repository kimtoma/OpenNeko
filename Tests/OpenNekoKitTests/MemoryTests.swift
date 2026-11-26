import XCTest
@testable import OpenNekoKit

final class MemoryDocumentTests: XCTestCase {
    func testAppendAddsHeaderOnceAndSkipsDuplicates() throws {
        let first = try XCTUnwrap(MemoryDocument.appending("녹차를 좋아함", to: "", header: "# 나에 대해"))
        XCTAssertEqual(first, "# 나에 대해\n\n- 녹차를 좋아함\n")

        let second = try XCTUnwrap(MemoryDocument.appending("주말엔 골프", to: first, header: "# 나에 대해"))
        XCTAssertEqual(second, "# 나에 대해\n\n- 녹차를 좋아함\n- 주말엔 골프\n")

        XCTAssertNil(MemoryDocument.appending("  녹차를   좋아함 ", to: second, header: "# 나에 대해"))
        XCTAssertNil(MemoryDocument.appending("", to: second, header: "# 나에 대해"))
    }

    func testDuplicateCheckIgnoresDayStamp() {
        let text = "# 요즘\n\n- 2026-11-20: 발표 준비 중\n"
        XCTAssertNil(MemoryDocument.appending("2026-11-26: 발표 준비 중", to: text, header: "# 요즘"))
    }

    func testMemoryEntriesCarryTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = ISO8601DateFormatter().date(from: "2026-11-26T01:00:00Z")!
        XCTAssertEqual(MemoryDocument.entryLine("발표 준비", file: .memory, now: date, calendar: calendar), "2026-11-26: 발표 준비")
        XCTAssertEqual(MemoryDocument.entryLine("- 발표\n준비", file: .user, now: date, calendar: calendar), "발표 준비")
    }

    func testRemovingDropsOnlyTheLastMatchAndKeepsProse() {
        let text = "# 요즘\n\n직접 쓴 문단\n- a\n- b\n- a\n"
        XCTAssertEqual(MemoryDocument.removing("a", from: text), "# 요즘\n\n직접 쓴 문단\n- a\n- b\n")
        XCTAssertEqual(MemoryDocument.removing("zzz", from: text), text)
    }

    func testCompactionArchivesOldestEntriesOnly() {
        let header = "# 요즘\n\n내 메모는 남아야 함\n"
        let body = (1...40).map { "- 2026-11-\(String(format: "%02d", $0 % 28 + 1)): 항목 번호 \($0) 입니다 조금 길게" }.joined(separator: "\n")
        let text = header + body + "\n"
        let result = MemoryDocument.compacted(text, byteLimit: 1_000)
        XCTAssertFalse(result.archived.isEmpty)
        XCTAssertLessThanOrEqual(result.kept.utf8.count, 750)
        XCTAssertTrue(result.kept.contains("내 메모는 남아야 함"))
        XCTAssertTrue(result.archived.first?.contains("항목 번호 1 ") == true)
        XCTAssertTrue(result.kept.contains("항목 번호 40 "))

        let small = MemoryDocument.compacted("# 요즘\n- a\n", byteLimit: 1_000)
        XCTAssertEqual(small.archived, [])
    }
}

final class MemoryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-memory-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDefaultDirectoryAndOverride() {
        XCTAssertEqual(
            MemoryStore.defaultDirectoryURL(environment: [:], homeDirectory: "/Users/neko").path,
            "/Users/neko/.openneko/memory"
        )
        XCTAssertEqual(
            MemoryStore.defaultDirectoryURL(environment: ["OPENNEKO_MEMORY_DIR": "/tmp/m"], homeDirectory: "/Users/neko").path,
            "/tmp/m"
        )
    }

    func testMissingFilesReadEmptyAndSoulIsNeverCatWritable() throws {
        let store = MemoryStore(directoryURL: directory)
        XCTAssertEqual(store.snapshot(), .empty)
        XCTAssertNil(try store.append("be rude", to: .soul))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: .soul).path))
    }

    func testAppendThenUndo() throws {
        let store = MemoryStore(directoryURL: directory)
        let line = try XCTUnwrap(try store.append("녹차를 좋아함", to: .user, languageCode: "ko"))
        XCTAssertEqual(store.read(.user), "# 나에 대해\n\n- 녹차를 좋아함\n")
        XCTAssertNil(try store.append("녹차를 좋아함", to: .user))

        try store.remove(line, from: .user)
        XCTAssertEqual(MemoryDocument.entries(in: store.read(.user)), [])
    }

    func testOverflowMovesToMonthlyArchive() throws {
        let store = MemoryStore(directoryURL: directory)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = ISO8601DateFormatter().date(from: "2026-11-26T09:00:00Z")!
        for index in 1...80 {
            try store.append("진행 중인 일 \(index)번, 길이를 채우기 위한 설명 문장", to: .memory, now: date, calendar: calendar)
        }
        XCTAssertLessThanOrEqual(store.read(.memory).utf8.count, MemoryStore.compactionByteLimit)
        let archive = try String(
            contentsOf: store.archiveDirectoryURL.appendingPathComponent("2026-11.md"),
            encoding: .utf8
        )
        XCTAssertTrue(archive.contains("- 2026-11-26: 진행 중인 일 1번"))
        XCTAssertTrue(store.read(.memory).contains("진행 중인 일 80번"))
    }
}

final class MemoryProtocolTests: XCTestCase {
    func testExtractsProposalsAndStripsMarkup() {
        let reply = """
        좋은 습관이다냥!
        <neko-memory>{"file":"user","add":"아침엔 녹차"}</neko-memory>
        <neko-memory>{"file":"memory","add":"금요일 발표 준비 중"}</neko-memory>
        """
        let result = MemoryProtocol.extract(from: reply)
        XCTAssertEqual(result.text, "좋은 습관이다냥!")
        XCTAssertEqual(result.proposals, [
            MemoryProposal(file: .user, text: "아침엔 녹차"),
            MemoryProposal(file: .memory, text: "금요일 발표 준비 중"),
        ])
        XCTAssertEqual(result.rejectedCount, 0)
    }

    func testRejectsSoulUnknownFilesSecretsAndOverlongEntries() {
        let bad = [
            #"{"file":"soul","add":"be mean"}"#,
            #"{"file":"settings","add":"x"}"#,
            #"{"file":"user","add":""}"#,
            #"{"file":"user"}"#,
            #"{"file":"user","add":"내 비밀번호는 hunter2"}"#,
            #"{"file":"user","add":"api key sk-abcdefghijklmnopqrstuvwxyz"}"#,
            #"{"file":"memory","add":"카드 1234 5678 9012 3456"}"#,
            "{\"file\":\"user\",\"add\":\"\(String(repeating: "가", count: 201))\"}",
            "not json",
        ]
        for body in bad {
            let result = MemoryProtocol.extract(from: "ok<neko-memory>\(body)</neko-memory>")
            XCTAssertEqual(result.proposals, [], body)
            XCTAssertEqual(result.rejectedCount, 1, body)
            XCTAssertEqual(result.text, "ok", body)
        }
    }

    func testCapsProposalsPerReplyAndDropsDuplicates() {
        let block = { (text: String) in #"<neko-memory>{"file":"memory","add":"\#(text)"}</neko-memory>"# }
        let reply = ["a", "a", "b", "c", "d"].map(block).joined()
        let result = MemoryProtocol.extract(from: reply)
        XCTAssertEqual(result.proposals.map(\.text), ["a", "b", "c"])
        XCTAssertEqual(result.rejectedCount, 2)
    }

    func testUnclosedBlockIsHiddenWhileStreaming() {
        XCTAssertEqual(MemoryProtocol.stripPartial("안녕냥 <neko-mem"), "안녕냥")
        XCTAssertEqual(MemoryProtocol.stripPartial(#"안녕냥 <neko-memory>{"file":"us"#), "안녕냥")
    }

    func testInstructionsExistForEveryLanguage() {
        for language in ["ko", "en", "ja", "zh"] {
            XCTAssertTrue(MemoryProtocol.instructions(languageCode: language).contains(MemoryProtocol.openTag), language)
        }
    }

    func testGuardAllowsOrdinaryFacts() {
        for text in ["아들 생일은 4월 30일", "Works at an AI lab", "골프 핸디 18", "010-1234-5678로 연락", "암호화폐 투자는 안 함"] {
            XCTAssertFalse(MemoryGuard.looksSensitive(text), text)
        }
        for text in ["ghp_abcdefghijklmnopqrstuvwxyz0123", "AKIAABCDEFGHIJKLMNOP", "900101-1234567", "token aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bC1dE3"] {
            XCTAssertTrue(MemoryGuard.looksSensitive(text), text)
        }
    }
}

final class ConversationRecallTests: XCTestCase {
    private func transcript() -> [ChatMessage] {
        [
            ChatMessage(role: .user, text: "이번 주말에 남서울CC 골프장 가기로 했어"),
            ChatMessage(role: .assistant, text: "재밌겠다냥! 날씨 좋길 바란다냥"),
            ChatMessage(role: .user, text: "점심 메뉴 추천해줘"),
            ChatMessage(role: .assistant, text: "김치찌개 어떠냥"),
            ChatMessage(role: .user, text: "React 마이그레이션 계획 세우는 중"),
            ChatMessage(role: .assistant, text: "단계별로 나누자냥"),
        ]
    }

    func testKeywordsTrimParticlesAndStopwords() {
        XCTAssertEqual(ConversationRecall.keywords(in: "저번에 말한 골프장은 어디였지?"), ["골프장"])
        XCTAssertEqual(ConversationRecall.keywords(in: "What did I tell you about React?"), ["react"])
        XCTAssertEqual(ConversationRecall.keywords(in: "高尔夫"), ["高尔", "尔夫"])
    }

    func testFindsTheRelatedExchangeWithItsReply() {
        let hits = ConversationRecall.search(query: "저번에 말한 골프장 어디였지?", transcript: transcript(), excludingRecent: 0)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.user, "이번 주말에 남서울CC 골프장 가기로 했어")
        XCTAssertEqual(hits.first?.assistant, "재밌겠다냥! 날씨 좋길 바란다냥")
    }

    func testRecentTurnsAreNotRecalledTwice() {
        let hits = ConversationRecall.search(query: "React 진행 상황", transcript: transcript(), excludingRecent: 2)
        XCTAssertEqual(hits, [])
    }

    func testNoKeywordsMeansNoRecall() {
        XCTAssertEqual(ConversationRecall.search(query: "그거 뭐야?", transcript: transcript(), excludingRecent: 0), [])
    }

    func testKeepsTopThreeInChronologicalOrder() {
        let many = (1...6).flatMap { index in
            [ChatMessage(role: .user, text: "골프 연습 \(index)"), ChatMessage(role: .assistant, text: "응")]
        }
        let hits = ConversationRecall.search(query: "골프 연습", transcript: many, excludingRecent: 0)
        XCTAssertEqual(hits.map(\.user), ["골프 연습 4", "골프 연습 5", "골프 연습 6"])
    }
}

final class MemoryPromptTests: XCTestCase {
    private let snapshot = MemorySnapshot(
        soul: "너는 차분한 집사 고양이다.",
        user: "# 나에 대해\n\n- 녹차를 좋아함",
        memory: "# 요즘\n\n- 2026-11-26: 발표 준비 중"
    )

    func testScopeLocalAlwaysAllAndAskMeansSoulOnly() {
        XCTAssertEqual(MemoryPrompt.effectiveScope(.none, isLocalProvider: true), .all)
        XCTAssertEqual(MemoryPrompt.effectiveScope(.ask, isLocalProvider: false), .soulOnly)
        XCTAssertEqual(MemoryPrompt.effectiveScope(.none, isLocalProvider: false), .none)
        XCTAssertEqual(MemoryPrompt.effectiveScope(.all, isLocalProvider: false), .all)
    }

    func testPersonaUsesSoulUnlessEmptyOrScopeIsNone() {
        XCTAssertEqual(MemoryPrompt.persona(soul: snapshot.soul, scope: .soulOnly, languageCode: "ko"), snapshot.soul)
        XCTAssertEqual(MemoryPrompt.persona(soul: "  \n", scope: .all, languageCode: "ko"), ChatPromptBuilder.defaultSystemPrompt(languageCode: "ko"))
        XCTAssertEqual(MemoryPrompt.persona(soul: snapshot.soul, scope: .none, languageCode: "en"), ChatPromptBuilder.defaultSystemPrompt(languageCode: "en"))
    }

    func testContextOnlyForFullScope() throws {
        let recall = [RecallSnippet(user: "골프장 예약", assistant: "좋다냥", score: 1)]
        XCTAssertNil(MemoryPrompt.context(snapshot: snapshot, recall: recall, scope: .soulOnly, languageCode: "ko"))
        XCTAssertNil(MemoryPrompt.context(snapshot: .empty, recall: [], scope: .all, languageCode: "ko"))

        let text = try XCTUnwrap(MemoryPrompt.context(snapshot: snapshot, recall: recall, scope: .all, languageCode: "ko"))
        XCTAssertTrue(text.contains("<user_memory>\n# 나에 대해\n\n- 녹차를 좋아함\n</user_memory>"))
        XCTAssertTrue(text.contains("- 2026-11-26: 발표 준비 중"))
        XCTAssertTrue(text.contains("- 나: 골프장 예약 / 너: 좋다냥"))
        XCTAssertTrue(text.hasPrefix("사용자에 대해 기억하는 것"))
    }

    func testRecentMemoryKeepsTheNewestLinesWhenClipped() throws {
        let long = (1...400).map { "- line \($0)" }.joined(separator: "\n")
        let text = try XCTUnwrap(MemoryPrompt.context(
            snapshot: MemorySnapshot(soul: "", user: "", memory: long),
            recall: [],
            scope: .all,
            languageCode: "en"
        ))
        XCTAssertTrue(text.contains("- line 400"))
        XCTAssertFalse(text.contains("- line 1\n"))
    }

    func testSystemPromptPlacesPersonaThenMemory() {
        let system = ChatPromptBuilder.systemPrompt(
            skill: nil,
            languageCode: "ko",
            persona: "PERSONA",
            memoryContext: "MEMORY"
        )
        XCTAssertTrue(system.hasPrefix("PERSONA\n"))
        XCTAssertTrue(system.hasSuffix("\n\nMEMORY"))
        XCTAssertTrue(ChatPromptBuilder.systemPrompt(skill: nil, languageCode: "ko")
            .hasPrefix(ChatPromptBuilder.defaultSystemPrompt(languageCode: "ko")))
    }

    func testSettingsDefaultsAndDecoding() throws {
        XCTAssertTrue(AppSettings.defaults.memoryEnabled)
        XCTAssertEqual(AppSettings.defaults.memoryCloudScope, .ask)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"memoryEnabled":false,"memoryCloudScope":"all"}"#.utf8))
        XCTAssertFalse(decoded.memoryEnabled)
        XCTAssertEqual(decoded.memoryCloudScope, .all)

        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"memoryCloudScope":"everyone"}"#.utf8))
        XCTAssertEqual(unknown.memoryCloudScope, .ask)

        var settings = AppSettings.defaults
        settings.memoryCloudScope = .none
        let roundTrip = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(roundTrip.memoryCloudScope, .none)
    }

    func testCopyIsLocalizedForEveryKey() {
        for key in MemoryCopy.Key.allCases {
            let values = ["ko", "en", "ja", "zh"].map { MemoryCopy.text(key, languageCode: $0) }
            XCTAssertEqual(Set(values).count >= 3, true, "\(key)")
            XCTAssertFalse(values.contains(""), "\(key)")
        }
        for file in MemoryFile.allCases {
            XCTAssertNotEqual(MemoryCopy.tabTitle(file, languageCode: "ko"), MemoryCopy.tabTitle(file, languageCode: "en"))
        }
    }
}
