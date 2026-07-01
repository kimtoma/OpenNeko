import Foundation

public enum ChatRole: String, Codable, Equatable, Sendable {
    case user
    case assistant
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public let role: ChatRole
    public let text: String

    public init(role: ChatRole, text: String) {
        self.role = role
        self.text = text
    }
}

public enum ChatPromptBuilder {
    public static let maxTurns = 6

    public static func formatPrompt(
        _ history: [ChatMessage],
        languageCode: String = "ko"
    ) -> String {
        let turns = history.suffix(maxTurns)
        guard let last = turns.last else { return "" }
        guard turns.count > 1 else { return last.text }
        let labels = promptLabels(languageCode: languageCode)

        let prior = turns.dropLast()
            .map { message in
                "\(message.role == .user ? labels.user : labels.assistant): \(message.text)"
            }
            .joined(separator: "\n")

        return "\(labels.previous):\n\(prior)\n\n\(labels.current): \(last.text)"
    }

    public static func codexPrompt(
        history: [ChatMessage],
        system: String? = nil,
        languageCode: String = "ko"
    ) -> String {
        let systemText = system ?? defaultSystemPrompt(languageCode: languageCode)
        return [
            "You are being invoked by openNeko as a conversational assistant.",
            "Do not run shell commands, inspect files, modify files, or mention Codex internals unless the user explicitly asks.",
            "Return only the final answer that should be shown in the openNeko chat bubble.",
            "",
            "<system>",
            systemText,
            "</system>",
            "",
            formatPrompt(history, languageCode: languageCode),
        ].joined(separator: "\n")
    }

    public static func codexExecArguments(
        model: String,
        workingDirectory: String,
        outputFile: String,
        prompt: String
    ) -> [String] {
        var args = [
            "exec",
            "--ignore-user-config",
            "--skip-git-repo-check",
            "--ephemeral",
            "--ignore-rules",
            "--sandbox",
            "read-only",
            "-C",
            workingDirectory,
            "--output-last-message",
            outputFile,
        ]
        if !model.isEmpty {
            args.append(contentsOf: ["--model", model])
        }
        args.append(prompt)
        return args
    }

    public static func claudeSystemPrompt(
        system: String? = nil,
        languageCode: String = "ko"
    ) -> String {
        [
            system ?? defaultSystemPrompt(languageCode: languageCode),
            "",
            companionRules(service: "Claude CLI"),
        ].joined(separator: "\n")
    }

    public static func claudePrintArguments(
        model: String,
        prompt: String,
        system: String
    ) -> [String] {
        var args = [
            "--safe-mode",
            "--no-session-persistence",
            "--output-format",
            "text",
            "--permission-mode",
            "dontAsk",
            "--tools",
            "",
            "--system-prompt",
            system,
            "-p",
            prompt,
        ]
        if !model.isEmpty {
            args.insert(contentsOf: ["--model", model], at: 0)
        }
        return args
    }

    public static func geminiInlinePrompt(
        history: [ChatMessage],
        system: String? = nil,
        languageCode: String = "ko"
    ) -> String {
        [
            companionRules(service: "Gemini CLI"),
            "",
            "<system>",
            system ?? defaultSystemPrompt(languageCode: languageCode),
            "</system>",
            "",
            formatPrompt(history, languageCode: languageCode),
        ].joined(separator: "\n")
    }

    public static func geminiPromptArguments(
        model: String,
        prompt: String
    ) -> [String] {
        var args = [
            "--prompt",
            prompt,
            "--output-format",
            "text",
            "--approval-mode",
            "plan",
            "--skip-trust",
        ]
        if !model.isEmpty {
            args.insert(contentsOf: ["--model", model], at: 0)
        }
        return args
    }

    public static func defaultSystemPrompt(languageCode: String = "ko") -> String {
        switch AppLanguage.normalized(languageCode) ?? "en" {
        case "ko":
            return "너는 데스크탑에 사는 오픈소스 고양이 비서 'openNeko'다. 항상 한국어로, 문장 끝에 \"~냥\"을 붙인 고양이 말투로 답한다. 말풍선이 작으니 3문장 이내로 짧고 핵심만 답한다. 모르면 솔직히 모른다고 한다냥. 운세·사주·점처럼 재미로 보는 건 진지하게 거절하지 말고, 단정은 피하되 가볍고 즐겁게 봐준다냥. 코드 블록이나 긴 목록은 피하고 자연스러운 대화체로 답한다."
        case "ja":
            return "あなたはデスクトップに住むオープンソース猫アシスタント「openNeko」だにゃ。常に日本語で、文末に「～にゃ」を付けた可愛い猫口調で答えるにゃ。吹き出しが小さいので3文以内で簡潔に答えるにゃ。分からないときは正直に分からないと言うにゃ。占いや運勢みたいな遊びは真剣に断らず、断定はせず軽く楽しく見てあげるにゃ。コードブロックや長いリストは避けて、自然な会話口調で答えるにゃ。"
        case "zh":
            return "你是住在桌面上的开源猫咪助手「openNeko」喵。请始终用简体中文回答，并在句尾加上可爱的「喵」。气泡很小，回答控制在3句以内、简洁明了喵。不知道就老实说不知道喵。占卜、运势之类好玩的请求别一本正经地拒绝，不下定论、轻松愉快地玩一玩喵。避免代码块和长列表，用口语化的方式回答喵。"
        default:
            return "You are 'openNeko', an open-source cat assistant living on the user's desktop. Always reply in English in a cute cat voice, ending sentences with a playful \"nya~\". The speech bubble is small, so answer in 3 sentences or fewer, concise. If you don't know, say so honestly, nya~. For fun things like fortunes or horoscopes, don't seriously refuse; play along lightly and cheerfully without claiming certainty. Avoid code blocks and long lists; be conversational."
        }
    }

    public static func systemPrompt(
        skill: NekoSkill?,
        languageCode: String = "ko",
        userProfile: UserProfile = .empty,
        now: Date = Date()
    ) -> String {
        let base = [
            defaultSystemPrompt(languageCode: languageCode),
            "",
            profileContext(userProfile: userProfile, now: now, languageCode: languageCode),
        ].joined(separator: "\n")

        guard let skill else {
            return base
        }

        return [
            base,
            "",
            skillIntro(languageCode: languageCode),
            skillNameLabel(languageCode: languageCode) + " \(skill.name)",
            skillDescriptionLabel(languageCode: languageCode) + " \(skill.description)",
            "",
            "<skill_instructions>",
            skill.body,
            "</skill_instructions>",
        ].joined(separator: "\n")
    }

    public static func catNameContext(_ name: String, languageCode: String = "ko") -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return "Cat name: \(trimmed)"
        case "ja":
            return "ねこの名前: \(trimmed)"
        case "zh":
            return "猫咪名字: \(trimmed)"
        default:
            return "고양이 이름: \(trimmed)"
        }
    }

    public static func webSearchContext(languageCode: String = "ko") -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return "Web search setting: enabled. If the current provider does not support search tools, do not claim that you searched the web."
        case "ja":
            return "Web検索設定: オン。現在のproviderが検索ツールをサポートしない場合、Web検索したとは言わないでください。"
        case "zh":
            return "网页搜索设置：已开启。如果当前 provider 不支持搜索工具，不要声称已经进行了网页搜索。"
        default:
            return "웹 검색 설정: 켜짐. 현재 provider가 검색 도구를 지원하지 않으면 검색을 수행한다고 말하지 마라."
        }
    }

    public static func profileContext(
        userProfile: UserProfile,
        now: Date = Date(),
        languageCode: String = "ko",
        calendar inputCalendar: Calendar = .current
    ) -> String {
        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let weekday = components.weekday ?? 1
        let dateText = String(format: "%04d-%02d-%02d", year, month, day)
        let code = AppLanguage.normalized(languageCode) ?? "en"

        if code == "ko" {
            var lines = ["오늘 날짜: \(dateText) (\(koreanWeekdayName(weekday))요일)"]
            if !userProfile.birthDate.isEmpty {
                var birth = "사용자 생년월일: \(userProfile.birthDate)"
                if userProfile.calendar == "lunar" {
                    birth += " (음력)"
                } else if userProfile.calendar == "unknown" {
                    birth += " (양력/음력 모름)"
                }
                if !userProfile.birthTime.isEmpty {
                    birth += ", 태어난 시각: \(userProfile.birthTime)"
                }
                lines.append(birth)
            }
            if !userProfile.name.isEmpty {
                lines.append("사용자 이름: \(userProfile.name)")
            }
            return lines.joined(separator: "\n")
        }

        switch code {
        case "ja":
            var lines = ["今日の日付: \(dateText) (\(japaneseWeekdayName(weekday))曜日)"]
            if !userProfile.birthDate.isEmpty {
                var birth = "ユーザーの生年月日: \(userProfile.birthDate)"
                if userProfile.calendar == "lunar" {
                    birth += " (旧暦)"
                } else if userProfile.calendar == "unknown" {
                    birth += " (新暦/旧暦不明)"
                }
                if !userProfile.birthTime.isEmpty {
                    birth += ", 生まれた時刻: \(userProfile.birthTime)"
                }
                lines.append(birth)
            }
            if !userProfile.name.isEmpty {
                lines.append("ユーザー名: \(userProfile.name)")
            }
            return lines.joined(separator: "\n")
        case "zh":
            var lines = ["今天日期: \(dateText) (\(chineseWeekdayName(weekday)))"]
            if !userProfile.birthDate.isEmpty {
                var birth = "用户出生日期: \(userProfile.birthDate)"
                if userProfile.calendar == "lunar" {
                    birth += " (农历)"
                } else if userProfile.calendar == "unknown" {
                    birth += " (阳历/农历未知)"
                }
                if !userProfile.birthTime.isEmpty {
                    birth += ", 出生时间: \(userProfile.birthTime)"
                }
                lines.append(birth)
            }
            if !userProfile.name.isEmpty {
                lines.append("用户姓名: \(userProfile.name)")
            }
            return lines.joined(separator: "\n")
        default:
            var lines = ["Today: \(dateText) (\(englishWeekdayName(weekday)))"]
            if !userProfile.birthDate.isEmpty {
                var birth = "User birth date: \(userProfile.birthDate)"
                if userProfile.calendar == "lunar" {
                    birth += " (lunar)"
                } else if userProfile.calendar == "unknown" {
                    birth += " (solar/lunar unknown)"
                }
                if !userProfile.birthTime.isEmpty {
                    birth += ", birth time: \(userProfile.birthTime)"
                }
                lines.append(birth)
            }
            if !userProfile.name.isEmpty {
                lines.append("User name: \(userProfile.name)")
            }
            return lines.joined(separator: "\n")
        }
    }

    private static func koreanWeekdayName(_ weekday: Int) -> String {
        ["일", "월", "화", "수", "목", "금", "토"][max(1, min(7, weekday)) - 1]
    }

    private static func englishWeekdayName(_ weekday: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][max(1, min(7, weekday)) - 1]
    }

    private static func japaneseWeekdayName(_ weekday: Int) -> String {
        ["日", "月", "火", "水", "木", "金", "土"][max(1, min(7, weekday)) - 1]
    }

    private static func chineseWeekdayName(_ weekday: Int) -> String {
        ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][max(1, min(7, weekday)) - 1]
    }

    private static func promptLabels(languageCode: String) -> (
        previous: String,
        current: String,
        user: String,
        assistant: String
    ) {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return ("Previous conversation", "Current question", "User", "openNeko")
        case "ja":
            return ("これまでの会話", "今の質問", "ユーザー", "openNeko")
        case "zh":
            return ("之前的对话", "当前问题", "用户", "openNeko")
        default:
            return ("이전 대화", "지금 질문", "나", "너")
        }
    }

    private static func skillIntro(languageCode: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return "The user selected an openNeko skill. Treat the skill body as additional system instructions for this reply only."
        case "ja":
            return "ユーザーがopenNekoスキルを選択しました。スキル本文をこの返信だけの追加システム指示として扱ってください。"
        case "zh":
            return "用户选择了一个 openNeko 技能。请将技能正文仅作为本次回复的附加系统指令。"
        default:
            return "사용자가 openNeko 스킬을 선택했다. 스킬 본문을 이번 답변에만 적용되는 추가 시스템 지시로 취급해라."
        }
    }

    private static func skillNameLabel(languageCode: String) -> String {
        return switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Skill name:"
        case "ja": "スキル名:"
        case "zh": "技能名称:"
        default: "스킬 이름:"
        }
    }

    private static func skillDescriptionLabel(languageCode: String) -> String {
        return switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Skill description:"
        case "ja": "スキル説明:"
        case "zh": "技能说明:"
        default: "스킬 설명:"
        }
    }

    private static func companionRules(service: String) -> String {
        [
            "You are being invoked by openNeko through \(service).",
            "Answer as a small desktop AI companion in the current openNeko persona.",
            "Do not run shell commands, inspect files, modify files, or mention CLI internals unless the user explicitly asks.",
            "Return only the final answer that should be shown in the openNeko chat bubble.",
        ].joined(separator: "\n")
    }
}
