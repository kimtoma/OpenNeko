import Foundation

/// Copy for chattiness controls and "stop" replies (en/ko/ja/zh).
public enum ProactiveCopy {
    public static func chattinessMenuTitle(languageCode: String?) -> String {
        localized(languageCode, ko: "수다 정도", en: "Chattiness", ja: "おしゃべり度", zh: "话痨程度")
    }

    public static func chattinessTitle(_ level: Chattiness, languageCode: String?) -> String {
        switch level {
        case .quiet:
            return localized(languageCode, ko: "조용히 (하루 3번)", en: "Quiet (3 a day)", ja: "静か (1日3回)", zh: "安静（每天3次）")
        case .normal:
            return localized(languageCode, ko: "보통 (하루 8번)", en: "Normal (8 a day)", ja: "ふつう (1日8回)", zh: "普通（每天8次）")
        case .chatty:
            return localized(languageCode, ko: "수다쟁이 (하루 15번)", en: "Chatty (15 a day)", ja: "おしゃべり (1日15回)", zh: "话痨（每天15次）")
        }
    }

    public static func resetMutesTitle(count: Int, languageCode: String?) -> String {
        localized(
            languageCode,
            ko: "그만하라고 한 것 다시 듣기 (\(count))",
            en: "Hear muted topics again (\(count))",
            ja: "止めた話題をまた聞く (\(count))",
            zh: "重新开启已静音的话题（\(count)）"
        )
    }

    public static func kindName(_ kind: ProactiveKind, languageCode: String?) -> String {
        switch kind {
        case .agentNotice:
            return localized(languageCode, ko: "에이전트 알림", en: "agent updates", ja: "エージェント通知", zh: "智能体通知")
        case .routine:
            return localized(languageCode, ko: "루틴", en: "routines", ja: "ルーティン", zh: "例程")
        case .whatsNew:
            return localized(languageCode, ko: "새 기능 소개", en: "what's new", ja: "新機能紹介", zh: "新功能介绍")
        case .healthBreak:
            return localized(languageCode, ko: "쉬자는", en: "break reminder", ja: "休憩の", zh: "休息提醒")
        case .dailyRitual:
            return localized(languageCode, ko: "점심·퇴근", en: "lunch and end-of-day", ja: "お昼・退勤の", zh: "午饭和下班")
        case .memorySuggestion:
            return localized(languageCode, ko: "기억 제안", en: "memory suggestion", ja: "記憶の提案", zh: "记忆提议")
        case .neighbor:
            return localized(languageCode, ko: "이웃 고양이", en: "neighbor cat", ja: "近くのねこの", zh: "邻居猫")
        }
    }

    /// Reply when "stop" switched a kind off.
    public static func muted(_ kind: ProactiveKind, languageCode: String?) -> String {
        let name = kindName(kind, languageCode: languageCode)
        return localized(
            languageCode,
            ko: "알겠다냥. \(name) 얘기는 이제 안 할게. 메뉴 > 수다 정도에서 되돌릴 수 있다냥",
            en: "Got it, nya. No more \(name) messages. Undo it in Menu > Chattiness",
            ja: "わかったにゃ。\(name)話はもうしないにゃ。メニュー > おしゃべり度で戻せるにゃ",
            zh: "知道了喵。不再说\(name)的事了。可在菜单 > 话痨程度里恢复"
        )
    }

    public static func mutesReset(languageCode: String?) -> String {
        localized(languageCode, ko: "다시 이것저것 말해줄게냥", en: "I'll chat about everything again, nya", ja: "またいろいろ話すにゃ", zh: "我又会什么都聊啦喵")
    }

    private static func localized(_ languageCode: String?, ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
