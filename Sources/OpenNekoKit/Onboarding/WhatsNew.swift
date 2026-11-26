import Foundation

/// Features the cat introduces in its "what's new" tour after an update.
/// Most new features are opt-in or hidden in menus, so the tour is how people
/// find them. Each feature records the tour revision it first appeared in;
/// bump `WhatsNew.currentRevision` when adding features to a new tour.
public enum WhatsNewFeature: String, CaseIterable, Equatable, Sendable {
    case selectedText
    case voiceInput
    case taskDelegation
    case catTools
    case routines
    case agentHooks
    case healthCompanion
    case localModels
    case appleIntelligence

    public var revision: Int {
        switch self {
        case .selectedText, .voiceInput, .taskDelegation, .catTools, .routines, .agentHooks,
             .healthCompanion, .localModels, .appleIntelligence:
            1
        }
    }
}

public enum WhatsNew {
    public static let currentRevision = 1

    public struct Context: Equatable, Sendable {
        public var onDeviceModelAvailable: Bool

        public init(onDeviceModelAvailable: Bool) {
            self.onDeviceModelAvailable = onDeviceModelAvailable
        }
    }

    /// Features worth showing on this Mac, in tour order.
    public static func features(context: Context) -> [WhatsNewFeature] {
        WhatsNewFeature.allCases.filter { feature in
            switch feature {
            case .appleIntelligence: context.onDeviceModelAvailable
            default: true
            }
        }
    }

    /// Features newer than the last tour the person saw.
    public static func pendingFeatures(lastSeenRevision: Int, context: Context) -> [WhatsNewFeature] {
        features(context: context).filter { $0.revision > lastSeenRevision }
    }

    /// The tour starts on its own only after first-launch setup is done, so a
    /// brand-new user meets it on the next launch instead of on top of setup.
    public static func shouldOfferTour(
        hasCompletedFirstLaunch: Bool,
        lastSeenRevision: Int,
        context: Context
    ) -> Bool {
        hasCompletedFirstLaunch && !pendingFeatures(lastSeenRevision: lastSeenRevision, context: context).isEmpty
    }
}

/// Step-by-step tour state: intro bubble, one bubble per feature, outro.
public struct WhatsNewTour: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        case intro(count: Int)
        case feature(WhatsNewFeature, index: Int, count: Int)
        case outro
    }

    public let features: [WhatsNewFeature]
    public private(set) var position = 0

    public init(features: [WhatsNewFeature]) {
        self.features = features
    }

    public var isEmpty: Bool { features.isEmpty }

    /// The current step, or nil once the tour is over.
    public var current: Step? {
        guard !features.isEmpty else { return nil }
        switch position {
        case 0: return .intro(count: features.count)
        case 1...features.count: return .feature(features[position - 1], index: position, count: features.count)
        case features.count + 1: return .outro
        default: return nil
        }
    }

    /// Moves to the next step and returns it (nil when finished).
    @discardableResult
    public mutating func advance() -> Step? {
        if current != nil { position += 1 }
        return current
    }
}

/// Bubble copy for the what's new tour (en/ko/ja/zh). Keep lines short.
public enum WhatsNewCopy {
    public static func text(_ step: WhatsNewTour.Step, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch step {
        case let .intro(count):
            return localized(l,
                ko: "✨ 새로 생긴 게 \(count)개 있다냥! 눌러서 볼래?",
                en: "✨ \(count) new things, nya! Click to see them",
                ja: "✨ 新しいことが\(count)個あるにゃ！クリックで見る？",
                zh: "✨ 有\(count)个新功能喵！点击看看")
        case let .feature(feature, index, count):
            return "\(index)/\(count) " + featureText(feature, l)
        case .outro:
            return localized(l,
                ko: "끝이다냥! 메뉴 막대의 \"새 기능 보기\"로 다시 볼 수 있다냥",
                en: "That's all, nya! Replay it from \"What's New\" in the menu bar",
                ja: "以上にゃ！メニューバーの「新機能」でもう一度見られるにゃ",
                zh: "就这些喵！可在菜单栏“新功能”里再看一次")
        }
    }

    /// Hint shown on hover while the tour waits for a click.
    public static func nextHint(languageCode: String?) -> String {
        localized(AppLanguage.normalized(languageCode) ?? "ko", ko: "다음", en: "Next", ja: "次へ", zh: "下一个")
    }

    public static func menuTitle(languageCode: String?) -> String {
        localized(AppLanguage.normalized(languageCode) ?? "ko", ko: "새 기능 보기", en: "What's New", ja: "新機能", zh: "新功能")
    }

    private static func featureText(_ feature: WhatsNewFeature, _ l: String) -> String {
        switch feature {
        case .selectedText:
            return localized(l,
                ko: "글자를 선택하고 우클릭 → 서비스 → openNeko. 설명·번역·요약해준다냥",
                en: "Select text, right-click → Services → openNeko to explain, translate or summarize",
                ja: "文字を選んで右クリック → サービス → openNeko。説明・翻訳・要約するにゃ",
                zh: "选中文字，右键 → 服务 → openNeko，帮你解释、翻译、总结喵")
        case .voiceInput:
            return localized(l,
                ko: "채팅창의 🎤를 누르고 있는 동안 말하면 글자로 바꿔준다냥. 맥 안에서만 인식한다냥",
                en: "Hold 🎤 in the chat box and talk: I type it for you, recognized on this Mac only",
                ja: "チャット欄の🎤を押しながら話すと文字にするにゃ。認識はこのMac内だけにゃ",
                zh: "按住聊天框里的🎤说话，我帮你转成文字。只在本机识别喵")
        case .taskDelegation:
            return localized(l,
                ko: "채팅에 /task 할 일 → 폴더를 고르면 Claude Code에 맡긴다냥. 위험한 건 먼저 묻는다냥",
                en: "Type /task <job> in chat and pick a folder: Claude Code does it, and I ask before risky steps",
                ja: "チャットで /task やること → フォルダを選ぶとClaude Codeに任せるにゃ。危ないことは先に聞くにゃ",
                zh: "在聊天里输入 /task 任务并选文件夹，交给 Claude Code。危险操作会先问你喵")
        case .catTools:
            return localized(l,
                ko: "\"3분 타이머\"처럼 부탁하면 타이머·알림·복사·링크 열기를 해준다냥. 누르기 전엔 안 한다냥",
                en: "Ask for a timer, reminder, copy or link (\"3 minute timer\"). Nothing runs until you click",
                ja: "「3分タイマー」のように頼むとタイマー・通知・コピー・リンクを開くにゃ。クリックするまで動かないにゃ",
                zh: "说“3分钟计时器”之类，我能计时、提醒、复制、开链接。你点了才执行喵")
        case .routines:
            return localized(l,
                ko: "설정 > AI > 루틴에서 아침 브리핑처럼 정한 시간에 할 일을 맡길 수 있다냥",
                en: "Settings > AI > Routines: give me jobs for set times, like a morning briefing",
                ja: "設定 > AI > ルーティンで、朝のブリーフィングなど決まった時間の仕事を任せられるにゃ",
                zh: "在设置 > AI > 例程里，可以让我在固定时间做事，比如早间简报喵")
        case .agentHooks:
            return localized(l,
                ko: "설정 > 일반 > 에이전트 알림을 붙이면 Claude Code·Codex가 끝날 때 알려준다냥",
                en: "Add Settings > General > Agent notifications and I'll tell you when Claude Code or Codex is done",
                ja: "設定 > 一般 > エージェント通知を入れるとClaude Code・Codexの完了を知らせるにゃ",
                zh: "在设置 > 通用 > 智能体通知里配置后，Claude Code、Codex 完成时我会提醒喵")
        case .healthCompanion:
            return localized(l,
                ko: "50분 넘게 계속 일하면 쉬자고 말해준다냥. 설정 > 일반에서 끌 수 있다냥",
                en: "After 50 minutes of nonstop work I'll suggest a break. Turn it off in Settings > General",
                ja: "50分以上働き続けたら休憩を勧めるにゃ。設定 > 一般でオフにできるにゃ",
                zh: "连续工作超过50分钟我会提醒休息。可在设置 > 通用里关闭喵")
        case .localModels:
            return localized(l,
                ko: "구독 없이도 된다냥! 설정 > AI에서 이 맥에 맞는 무료 모델을 골라준다냥",
                en: "No subscription needed: Settings > AI picks a free local model for this Mac",
                ja: "サブスクなしでもOKにゃ！設定 > AIでこのMacに合う無料モデルを選ぶにゃ",
                zh: "不订阅也行喵！在设置 > AI 里为这台 Mac 挑选免费本地模型")
        case .appleIntelligence:
            return localized(l,
                ko: "이 맥은 Apple Intelligence로 키 없이 대화할 수 있다냥. 설정 > AI에서 고르면 된다냥",
                en: "This Mac can chat with Apple Intelligence, no key needed. Choose it in Settings > AI",
                ja: "このMacはApple Intelligenceでキーなしで話せるにゃ。設定 > AIで選んでにゃ",
                zh: "这台 Mac 可用 Apple Intelligence 免密钥聊天。在设置 > AI 里选择喵")
        }
    }

    private static func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
