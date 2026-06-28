import Foundation

public enum NekoBubbleCopy {
    public static func stretch(languageCode: String?) -> String {
        localized(languageCode, ko: "스트레칭 시간이다냥! 기지개 쭉 펴라냥", en: "Stretch time, nya! Loosen up a little.", ja: "ストレッチ時間にゃ! ぐーっと伸びるにゃ", zh: "伸展时间喵! 起来舒展一下喵")
    }

    public static func lunch(languageCode: String?) -> String {
        localized(languageCode, ko: "점심 시간이다냥! 맛있는 거 먹고 오라냥", en: "Lunch time, nya! Go eat something nice.", ja: "ランチ時間にゃ! おいしいもの食べてくるにゃ", zh: "午餐时间喵! 去吃点好吃的喵")
    }

    public static func leaveWork(languageCode: String?) -> String {
        localized(languageCode, ko: "오늘 할 만큼 했다냥. 이제 쉬러 가라냥", en: "You did enough today, nya. Time to rest.", ja: "今日は十分がんばったにゃ。休むにゃ", zh: "今天已经很努力了喵。去休息吧喵")
    }

    public static func setupReady(languageCode: String?) -> String {
        localized(languageCode, ko: "준비 끝이다냥! 잘 부탁한다냥", en: "Ready, nya! Let's work together.", ja: "準備できたにゃ! よろしくにゃ", zh: "准备好了喵! 请多关照喵")
    }

    public static func updateRestart(languageCode: String?) -> String {
        localized(languageCode, ko: "업데이트 완료다냥! 다시 시작한다냥", en: "Update complete, nya! Restarting now.", ja: "更新完了にゃ! 再起動するにゃ", zh: "更新完成喵! 现在重启喵")
    }

    public static func missingRunScript(languageCode: String?) -> String {
        localized(languageCode, ko: "실행 스크립트를 못 찾았다냥", en: "I could not find the run script, nya.", ja: "実行スクリプトが見つからないにゃ", zh: "找不到运行脚本喵")
    }

    public static func restartFailed(languageCode: String?) -> String {
        localized(languageCode, ko: "다시 시작하지 못했다냥...", en: "I could not restart, nya...", ja: "再起動できなかったにゃ...", zh: "没能重启喵...")
    }

    public static func agentWorking(_ label: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "\(label) is working, nya~"
        case "ja": return "\(label) が作業中にゃ"
        case "zh": return "\(label) 正在工作喵"
        default: return "\(label) 작업 중이다냥"
        }
    }

    public static func skillMissing(languageCode: String?) -> String {
        localized(languageCode, ko: "그 스킬은 못 찾았다냥", en: "I could not find that skill, nya.", ja: "そのスキルは見つからないにゃ", zh: "找不到那个技能喵")
    }

    public static func skillDisabled(languageCode: String?) -> String {
        localized(languageCode, ko: "꺼진 스킬이다냥", en: "That skill is disabled, nya.", ja: "そのスキルはオフにゃ", zh: "那个技能已关闭喵")
    }

    public static func clipboardEmpty(languageCode: String?) -> String {
        localized(languageCode, ko: "클립보드가 비어 있다냥", en: "The clipboard is empty, nya.", ja: "クリップボードが空にゃ", zh: "剪贴板是空的喵")
    }

    public static func skillActivated(_ name: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "\(name) mode is on, nya~"
        case "ja": return "\(name) モードにしたにゃ"
        case "zh": return "\(name) 模式已开启喵"
        default: return "\(name) 모드다냥"
        }
    }

    public static func skillPlaceholder(_ name: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Ask with \(name), nya..."
        case "ja": return "\(name) で聞くにゃ..."
        case "zh": return "用 \(name) 问我喵..."
        default: return "\(name)로 물어보라냥..."
        }
    }

    public static func chatPlaceholder(languageCode: String?) -> String {
        localized(languageCode, ko: "무엇을 물어볼까냥?", en: "What shall I ask, nya?", ja: "何を聞くにゃ?", zh: "想问什么喵?")
    }

    public static func bgmStopped(languageCode: String?) -> String {
        localized(languageCode, ko: "내장 BGM은 멈췄다냥\nYouTube Music은 열린 탭에서 멈춰달라냥", en: "Built-in BGM stopped, nya.\nStop YouTube Music in its open tab.", ja: "内蔵BGMは止めたにゃ\nYouTube Musicは開いているタブで止めるにゃ", zh: "内置BGM已停止喵\nYouTube Music 请在打开的标签页里停止喵")
    }

    public static func bgmSearching(languageCode: String?) -> String {
        localized(languageCode, ko: "오늘의 BGM 찾는 중이다냥", en: "Finding today's BGM, nya~", ja: "今日のBGMを探してるにゃ", zh: "正在找今天的BGM喵")
    }

    public static func bgmOpened(title: String, query: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Opened today's BGM, nya:\n\(title)\n\(query)"
        case "ja": return "今日のBGMを開いたにゃ:\n\(title)\n\(query)"
        case "zh": return "已打开今天的BGM喵:\n\(title)\n\(query)"
        default: return "오늘의 BGM을 열었다냥:\n\(title)\n\(query)"
        }
    }

    public static func bgmOpenFailed(languageCode: String?) -> String {
        localized(languageCode, ko: "YouTube Music을 열지 못했다냥", en: "I could not open YouTube Music, nya.", ja: "YouTube Musicを開けなかったにゃ", zh: "没能打开 YouTube Music 喵")
    }

    public static func slashHelp(suffix: String, languageCode: String?) -> String {
        let base = localized(languageCode, ko: "사용 가능한 명령이다냥:", en: "Available commands, nya:", ja: "使えるコマンドにゃ:", zh: "可用命令喵:")
        return "\(base)\n/help /reset /skin /lang /sound\(suffix)"
    }

    public static func chatReset(languageCode: String?) -> String {
        localized(languageCode, ko: "대화를 초기화했다냥", en: "Chat reset, nya.", ja: "会話をリセットしたにゃ", zh: "对话已重置喵")
    }

    public static func skinList(_ ids: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Skins, nya: \(ids)"
        case "ja": return "スキンにゃ: \(ids)"
        case "zh": return "皮肤喵: \(ids)"
        default: return "스킨 목록이다냥: \(ids)"
        }
    }

    public static func skinMissing(languageCode: String?) -> String {
        localized(languageCode, ko: "그 스킨은 못 찾았다냥", en: "I could not find that skin, nya.", ja: "そのスキンは見つからないにゃ", zh: "找不到那个皮肤喵")
    }

    public static func skinChanged(_ label: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Skin changed to \(label), nya!"
        case "ja": return "スキンを \(label) にしたにゃ"
        case "zh": return "皮肤已切换为 \(label) 喵"
        default: return "스킨을 \(label)(으)로 바꿨다냥"
        }
    }

    public static func currentLanguage(_ name: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Current language is \(name), nya."
        case "ja": return "今の言語は \(name) にゃ"
        case "zh": return "当前语言是 \(name) 喵"
        default: return "지금은 \(name)로 말한다냥"
        }
    }

    public static func systemLanguage(languageCode: String?) -> String {
        localized(languageCode, ko: "시스템 언어를 따라간다냥", en: "Following the system language, nya.", ja: "システム言語に合わせるにゃ", zh: "跟随系统语言喵")
    }

    public static func supportedLanguages(languageCode: String?) -> String {
        localized(languageCode, ko: "지원 언어는 ko, en, ja, zh 다냥", en: "Supported languages are ko, en, ja, zh, nya.", ja: "対応言語は ko, en, ja, zh にゃ", zh: "支持语言是 ko, en, ja, zh 喵")
    }

    public static func soundUsage(languageCode: String?) -> String {
        localized(languageCode, ko: "사용법은 /sound on 또는 /sound off 다냥", en: "Use /sound on or /sound off, nya.", ja: "/sound on か /sound off を使うにゃ", zh: "请用 /sound on 或 /sound off 喵")
    }

    public static func soundEnabled(_ enabled: Bool, languageCode: String?) -> String {
        if enabled {
            return localized(languageCode, ko: "효과음 켰다냥", en: "Sound effects on, nya.", ja: "効果音オンにゃ", zh: "音效已开启喵")
        }
        return localized(languageCode, ko: "효과음 껐다냥", en: "Sound effects off, nya.", ja: "効果音オフにゃ", zh: "音效已关闭喵")
    }

    public static func unknownCommand(languageCode: String?) -> String {
        localized(languageCode, ko: "모르는 명령이다냥... /help 를 쳐보라냥", en: "Unknown command, nya... Try /help.", ja: "知らないコマンドにゃ... /help を試すにゃ", zh: "未知命令喵... 试试 /help 喵")
    }

    public static func thinking(skillName: String?, languageCode: String?) -> String {
        if let skillName {
            switch AppLanguage.normalized(languageCode) ?? "ko" {
            case "en": return "\(skillName) is thinking, nya~"
            case "ja": return "\(skillName) で考え中にゃ"
            case "zh": return "\(skillName) 正在思考喵"
            default: return "\(skillName) 생각 중이다냥"
            }
        }
        return StateBubbleText.text(
            for: StateBridgeEvent(state: .thinking, source: "openNeko", message: nil),
            languageCode: languageCode
        ) ?? localized(languageCode, ko: "생각 중이다냥", en: "Thinking, nya~", ja: "考え中にゃ", zh: "思考中喵")
    }

    public static func skillRunning(_ name: String, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": return "Running \(name), nya~"
        case "ja": return "\(name) 実行中にゃ"
        case "zh": return "正在运行 \(name) 喵"
        default: return "\(name) 실행 중이다냥"
        }
    }

    public static func genericChatError(languageCode: String?) -> String {
        localized(languageCode, ko: "지금은 대답을 만들지 못했다냥...", en: "I cannot answer right now, nya...", ja: "今は返事を作れないにゃ...", zh: "现在没法生成回答喵...")
    }

    public static func replyCopied(languageCode: String?) -> String {
        localized(languageCode, ko: "답변을 복사했다냥", en: "Reply copied, nya.", ja: "返事をコピーしたにゃ", zh: "回答已复制喵")
    }

    public static func copyReplyHelp(languageCode: String?) -> String {
        localized(languageCode, ko: "답변 복사", en: "Copy reply", ja: "返事をコピー", zh: "复制回答")
    }

    public static func styledChatReply(_ reply: String, languageCode: String?) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return appendCatSuffixIfNeeded(trimmed, markers: ["nya"], suffix: ", nya~")
        case "ja":
            return appendCatSuffixIfNeeded(trimmed, markers: ["にゃ"], suffix: "にゃ")
        case "zh":
            return appendCatSuffixIfNeeded(trimmed, markers: ["喵"], suffix: "喵")
        default:
            return appendCatSuffixIfNeeded(trimmed, markers: ["냥"], suffix: "냥")
        }
    }

    private static func localized(
        _ languageCode: String?,
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }

    private static func appendCatSuffixIfNeeded(_ text: String, markers: [String], suffix: String) -> String {
        let lowercased = text.lowercased()
        if markers.contains(where: { lowercased.contains($0.lowercased()) }) {
            return text
        }

        let terminalPunctuation = ".!?…。！？~"
        var body = text
        var punctuation = ""
        while let last = body.last, terminalPunctuation.contains(last) {
            punctuation.insert(last, at: punctuation.startIndex)
            body.removeLast()
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return text }
        return trimmedBody + suffix + punctuation
    }
}
