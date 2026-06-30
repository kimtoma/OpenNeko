import XCTest
@testable import OpenNekoKit

final class ChatPromptBuilderTests: XCTestCase {
    func testFormatPromptUsesSingleLatestMessageForFirstTurn() {
        let prompt = ChatPromptBuilder.formatPrompt([
            ChatMessage(role: .user, text: "안녕")
        ])

        XCTAssertEqual(prompt, "안녕")
    }

    func testFormatPromptKeepsOnlyRecentTurns() {
        let history = (0..<8).map { index in
            ChatMessage(role: index.isMultiple(of: 2) ? .user : .assistant, text: "m\(index)")
        }

        let prompt = ChatPromptBuilder.formatPrompt(history)

        XCTAssertFalse(prompt.contains("m0"))
        XCTAssertFalse(prompt.contains("m1"))
        XCTAssertTrue(prompt.contains("나: m2"))
        XCTAssertTrue(prompt.contains("너: m3"))
        XCTAssertTrue(prompt.contains("지금 질문: m7"))
    }

    func testFormatPromptLocalizesConversationLabels() {
        let history = [
            ChatMessage(role: .user, text: "Hello"),
            ChatMessage(role: .assistant, text: "Hi"),
            ChatMessage(role: .user, text: "Again"),
        ]

        let english = ChatPromptBuilder.formatPrompt(history, languageCode: "en")
        let japanese = ChatPromptBuilder.formatPrompt(history, languageCode: "ja")
        let chinese = ChatPromptBuilder.formatPrompt(history, languageCode: "zh")

        XCTAssertTrue(english.contains("Previous conversation:"))
        XCTAssertTrue(english.contains("User: Hello"))
        XCTAssertTrue(english.contains("openNeko: Hi"))
        XCTAssertTrue(english.contains("Current question: Again"))
        XCTAssertTrue(japanese.contains("これまでの会話:"))
        XCTAssertTrue(japanese.contains("ユーザー: Hello"))
        XCTAssertTrue(japanese.contains("今の質問: Again"))
        XCTAssertTrue(chinese.contains("之前的对话:"))
        XCTAssertTrue(chinese.contains("用户: Hello"))
        XCTAssertTrue(chinese.contains("当前问题: Again"))
    }

    func testCodexPromptWrapsSystemAndFormattedHistory() {
        let prompt = ChatPromptBuilder.codexPrompt(
            history: [ChatMessage(role: .user, text: "한마디 해줘")],
            system: "짧게 답해",
            languageCode: "ko"
        )

        XCTAssertTrue(prompt.contains("openNeko"))
        XCTAssertTrue(prompt.contains("<system>\n짧게 답해\n</system>"))
        XCTAssertTrue(prompt.hasSuffix("한마디 해줘"))
    }

    func testSystemPromptIncludesSelectedSkillInstructions() {
        let skill = NekoSkill(
            id: "translate",
            name: "번역",
            description: "복사한 텍스트 번역",
            input: .clipboard,
            body: "번역 결과만 답해줘.",
            source: .bundled
        )

        let system = ChatPromptBuilder.systemPrompt(skill: skill, languageCode: "ko")

        XCTAssertTrue(system.contains("스킬 이름: 번역"))
        XCTAssertTrue(system.contains("<skill_instructions>\n번역 결과만 답해줘.\n</skill_instructions>"))
    }

    func testSystemPromptLocalizesSkillMetadata() {
        let skill = NekoSkill(
            id: "summarize",
            name: "Summarize",
            description: "Short summary",
            input: .prompt,
            body: "Answer briefly.",
            source: .user
        )

        let english = ChatPromptBuilder.systemPrompt(skill: skill, languageCode: "en")
        let japanese = ChatPromptBuilder.systemPrompt(skill: skill, languageCode: "ja")
        let chinese = ChatPromptBuilder.systemPrompt(skill: skill, languageCode: "zh")

        XCTAssertTrue(english.contains("Skill name: Summarize"))
        XCTAssertTrue(japanese.contains("スキル名: Summarize"))
        XCTAssertTrue(chinese.contains("技能名称: Summarize"))
    }

    func testSystemPromptIncludesProfileContext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_772_496_000)

        let system = ChatPromptBuilder.systemPrompt(
            skill: nil,
            languageCode: "ko",
            userProfile: UserProfile(
                name: "Kim",
                birthDate: "1990-01-02",
                birthTime: "08:30",
                calendar: "lunar"
            ),
            now: date
        )

        XCTAssertTrue(system.contains("오늘 날짜:"))
        XCTAssertTrue(system.contains("사용자 생년월일: 1990-01-02 (음력), 태어난 시각: 08:30"))
        XCTAssertTrue(system.contains("사용자 이름: Kim"))
    }

    func testDefaultSystemPromptKeepsLocalizedCatVoice() {
        let korean = ChatPromptBuilder.defaultSystemPrompt(languageCode: "ko")
        let english = ChatPromptBuilder.defaultSystemPrompt(languageCode: "en")
        let japanese = ChatPromptBuilder.defaultSystemPrompt(languageCode: "ja")
        let chinese = ChatPromptBuilder.defaultSystemPrompt(languageCode: "zh")

        XCTAssertTrue(korean.contains("항상 한국어"))
        XCTAssertTrue(korean.contains("~냥"))
        XCTAssertTrue(korean.contains("3문장 이내"))
        XCTAssertTrue(korean.contains("진지하게 거절하지 말고"))
        XCTAssertTrue(english.contains("Always reply in English"))
        XCTAssertTrue(english.contains("nya~"))
        XCTAssertTrue(english.contains("3 sentences or fewer"))
        XCTAssertTrue(japanese.contains("常に日本語"))
        XCTAssertTrue(japanese.contains("～にゃ"))
        XCTAssertTrue(chinese.contains("始终用简体中文"))
        XCTAssertTrue(chinese.contains("喵"))
    }

    func testAppSystemContextIsLocalized() {
        XCTAssertEqual(ChatPromptBuilder.catNameContext("Momo", languageCode: "ko"), "고양이 이름: Momo")
        XCTAssertEqual(ChatPromptBuilder.catNameContext("Momo", languageCode: "en"), "Cat name: Momo")
        XCTAssertEqual(ChatPromptBuilder.catNameContext("Momo", languageCode: "ja"), "ねこの名前: Momo")
        XCTAssertEqual(ChatPromptBuilder.catNameContext("Momo", languageCode: "zh"), "猫咪名字: Momo")
        XCTAssertNil(ChatPromptBuilder.catNameContext("   ", languageCode: "en"))
        XCTAssertTrue(ChatPromptBuilder.webSearchContext(languageCode: "en").contains("Web search setting: enabled"))
        XCTAssertTrue(ChatPromptBuilder.webSearchContext(languageCode: "ja").contains("Web検索設定"))
        XCTAssertTrue(ChatPromptBuilder.webSearchContext(languageCode: "zh").contains("网页搜索设置"))
    }

    func testProfileContextIsLocalizedForJapaneseAndChinese() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_772_496_000)
        let profile = UserProfile(
            name: "Ari",
            birthDate: "2001-02-03",
            birthTime: "04:05",
            calendar: "lunar"
        )

        let japanese = ChatPromptBuilder.profileContext(
            userProfile: profile,
            now: date,
            languageCode: "ja",
            calendar: calendar
        )
        let chinese = ChatPromptBuilder.profileContext(
            userProfile: profile,
            now: date,
            languageCode: "zh",
            calendar: calendar
        )

        XCTAssertTrue(japanese.contains("今日の日付:"))
        XCTAssertTrue(japanese.contains("ユーザーの生年月日: 2001-02-03 (旧暦), 生まれた時刻: 04:05"))
        XCTAssertTrue(japanese.contains("ユーザー名: Ari"))
        XCTAssertTrue(chinese.contains("今天日期:"))
        XCTAssertTrue(chinese.contains("用户出生日期: 2001-02-03 (农历), 出生时间: 04:05"))
        XCTAssertTrue(chinese.contains("用户姓名: Ari"))
    }

    func testCodexExecArgumentsMatchSupportedCLIOptions() {
        let args = ChatPromptBuilder.codexExecArguments(
            model: "gpt-test",
            workingDirectory: "/tmp",
            outputFile: "/tmp/out.txt",
            prompt: "hello"
        )

        XCTAssertEqual(args.prefix(2), ["exec", "--ignore-user-config"])
        XCTAssertTrue(args.contains("--skip-git-repo-check"))
        XCTAssertTrue(args.contains("--ephemeral"))
        XCTAssertTrue(args.contains("--ignore-rules"))
        XCTAssertTrue(args.contains("--output-last-message"))
        XCTAssertTrue(args.contains("gpt-test"))
        XCTAssertEqual(args.last, "hello")
    }

    func testClaudeSystemPromptCombinesPersonaAndCompanionRules() {
        let system = ChatPromptBuilder.claudeSystemPrompt(
            system: "짧게",
            languageCode: "ko"
        )

        XCTAssertTrue(system.hasPrefix("짧게\n\n"))
        XCTAssertTrue(system.contains("Claude CLI"))
        XCTAssertTrue(system.contains("Return only the final answer"))
    }

    func testClaudePrintArgumentsUseHeadlessTextMode() {
        let args = ChatPromptBuilder.claudePrintArguments(
            model: "sonnet",
            prompt: "안녕",
            system: "system"
        )

        XCTAssertEqual(Array(args.prefix(2)), ["--model", "sonnet"])
        XCTAssertTrue(args.contains("--safe-mode"))
        XCTAssertTrue(args.contains("--no-session-persistence"))
        XCTAssertTrue(args.contains("--output-format"))
        XCTAssertTrue(args.contains("text"))
        XCTAssertTrue(args.contains("--permission-mode"))
        XCTAssertTrue(args.contains("dontAsk"))
        XCTAssertTrue(args.contains("--tools"))
        XCTAssertTrue(args.contains("--system-prompt"))
        XCTAssertTrue(args.contains("system"))
        XCTAssertEqual(Array(args.suffix(2)), ["-p", "안녕"])
    }

    func testGeminiInlinePromptWrapsSystemAndHistory() {
        let prompt = ChatPromptBuilder.geminiInlinePrompt(
            history: [ChatMessage(role: .user, text: "요약해줘")],
            system: "짧게",
            languageCode: "ko"
        )

        XCTAssertTrue(prompt.contains("Gemini CLI"))
        XCTAssertTrue(prompt.contains("<system>\n짧게\n</system>"))
        XCTAssertTrue(prompt.hasSuffix("요약해줘"))
    }

    func testGeminiPromptArgumentsUseHeadlessPlanMode() {
        let args = ChatPromptBuilder.geminiPromptArguments(
            model: "gemini-test",
            prompt: "hello"
        )

        XCTAssertEqual(Array(args.prefix(2)), ["--model", "gemini-test"])
        XCTAssertTrue(args.contains("--prompt"))
        XCTAssertTrue(args.contains("hello"))
        XCTAssertTrue(args.contains("--output-format"))
        XCTAssertTrue(args.contains("text"))
        XCTAssertTrue(args.contains("--approval-mode"))
        XCTAssertTrue(args.contains("plan"))
        XCTAssertTrue(args.contains("--skip-trust"))
    }
}
