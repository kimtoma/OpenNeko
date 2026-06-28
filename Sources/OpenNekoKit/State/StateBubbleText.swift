public enum StateBubbleText {
    public static let maxDisplayLength = 48

    public static func wakeText(languageCode: String? = nil) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        return switch language {
        case "en": "...I'm awake, nya!"
        case "ja": "...起きたにゃ!"
        case "zh": "...我醒了喵!"
        default: "...깼다냥!"
        }
    }

    public static func text(for event: StateBridgeEvent, languageCode: String? = nil) -> String? {
        if let message = event.message, !message.isEmpty {
            return String(message.prefix(maxDisplayLength))
        }

        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch event.state {
        case .coding:
            return localized(coding: language)
        case .thinking:
            return localized(thinking: language)
        case .typing:
            return localized(typing: language)
        case .success:
            return localized(success: language)
        case .error:
            return localized(error: language)
        case .lunch:
            return localized(lunch: language)
        case .nap:
            return localized(nap: language)
        case .walk:
            return localized(walk: language)
        case .jump:
            return localized(jump: language)
        case .yawn:
            return localized(yawn: language)
        default:
            return nil
        }
    }

    private static func localized(coding language: String) -> String {
        switch language {
        case "en": "Coding, nya~"
        case "ja": "コーディング中にゃ"
        case "zh": "编码中喵"
        default: "코딩 중이다냥"
        }
    }

    private static func localized(thinking language: String) -> String {
        switch language {
        case "en": "Thinking, nya~"
        case "ja": "考え中にゃ"
        case "zh": "思考中喵"
        default: "생각 중이다냥"
        }
    }

    private static func localized(typing language: String) -> String {
        switch language {
        case "en": "Tap tap, working, nya~"
        case "ja": "カタカタ作業中にゃ"
        case "zh": "噼啪工作中喵"
        default: "타닥타닥 일하는 중이다냥"
        }
    }

    private static func localized(success language: String) -> String {
        switch language {
        case "en": "Done, nya!"
        case "ja": "完了にゃ!"
        case "zh": "完成喵!"
        default: "작업 완료다냥!"
        }
    }

    private static func localized(error language: String) -> String {
        switch language {
        case "en": "Something went wrong, nya..."
        case "ja": "問題が起きたにゃ..."
        case "zh": "出了点问题喵..."
        default: "에러가 났다냥..."
        }
    }

    private static func localized(lunch language: String) -> String {
        switch language {
        case "en": "Lunch time, nya!"
        case "ja": "ランチ時間にゃ!"
        case "zh": "午餐时间喵!"
        default: "점심 시간이다냥!"
        }
    }

    private static func localized(nap language: String) -> String {
        switch language {
        case "en": "Taking a tiny nap, nya..."
        case "ja": "少し休憩中にゃ..."
        case "zh": "短暂休息中喵..."
        default: "쿨쿨 낮잠 자는 중이다냥"
        }
    }

    private static func localized(walk language: String) -> String {
        switch language {
        case "en": "Taking a stroll, nya~"
        case "ja": "お散歩中にゃ"
        case "zh": "散步中喵"
        default: "산책하는 중이다냥"
        }
    }

    private static func localized(jump language: String) -> String {
        switch language {
        case "en": "Hop, nya!"
        case "ja": "ぴょんにゃ!"
        case "zh": "跳一下喵!"
        default: "폴짝 뛰었다냥!"
        }
    }

    private static func localized(yawn language: String) -> String {
        switch language {
        case "en": "Yaaawn, nya..."
        case "ja": "ふわぁ、にゃ..."
        case "zh": "哈欠喵..."
        default: "하품 나온다냥..."
        }
    }
}
