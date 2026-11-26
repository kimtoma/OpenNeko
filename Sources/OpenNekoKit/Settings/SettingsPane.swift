/// Settings sections. The sidebar shows only `sidebar` (six panes); the
/// other cases name sections inside those panes and older deep links.
public enum SettingsPane: String, CaseIterable, Equatable, Identifiable {
    case cat
    case memory
    case abilities
    case day
    case advanced
    case start
    case skins
    case profile
    case general
    case ai
    case skills
    case about
    case neighbors
    case permissions
    case bridge

    public var id: String { rawValue }

    /// The panes in the sidebar, in order.
    public static let sidebar: [SettingsPane] = [.cat, .memory, .abilities, .day, .ai, .advanced]

    /// Which sidebar pane holds this section (for old links and tiles).
    public var sidebarPane: SettingsPane {
        switch self {
        case .cat, .start, .skins: .cat
        case .memory, .profile: .memory
        case .abilities, .skills, .permissions: .abilities
        case .day: .day
        case .ai: .ai
        case .advanced, .general, .neighbors, .bridge, .about: .advanced
        }
    }

    /// One line under a sidebar pane's title.
    public func subtitle(languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        func pick(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
            switch l {
            case "en": en
            case "ja": ja
            case "zh": zh
            default: ko
            }
        }
        switch sidebarPane {
        case .cat:
            return pick("이름, 모습, 말투와 수다 정도", "Name, look, voice and chattiness", "名前、見た目、話し方とおしゃべり度", "名字、外观、语气和话痨程度")
        case .memory:
            return pick("고양이가 기억하는 나와 요즘 이야기", "What the cat remembers about you", "ねこが覚えているあなたのこと", "猫咪记住的关于你的事")
        case .abilities:
            return pick("도구, 스킬, 검색, 권한", "Tools, skills, search and permissions", "ツール、スキル、検索、権限", "工具、技能、搜索和权限")
        case .day:
            return pick("루틴과 쉬는 시간", "Routines and breaks", "ルーティンと休憩", "例程和休息")
        case .ai:
            return pick("대화에 쓸 AI 연결", "The AI the cat talks with", "会話に使うAI", "聊天使用的 AI")
        default:
            return pick("에이전트 알림, 이웃 고양이, 앱 정보", "Agent hooks, neighbor cats, app info", "エージェント通知、近くのねこ、アプリ情報", "智能体通知、邻居猫、应用信息")
        }
    }

    public var title: String {
        title(languageCode: nil)
    }

    public func title(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            englishTitle
        case "ja":
            japaneseTitle
        case "zh":
            chineseTitle
        default:
            koreanTitle
        }
    }

    private var koreanTitle: String {
        switch self {
        case .cat: "고양이"
        case .memory: "기억"
        case .abilities: "능력"
        case .day: "하루"
        case .advanced: "고급"
        case .start: "네꼬 상태"
        case .general: "일반"
        case .neighbors: "이웃 고양이"
        case .profile: "내 프로필"
        case .ai: "AI"
        case .skills: "스킬"
        case .permissions: "권한"
        case .bridge: "브리지"
        case .skins: "외형"
        case .about: "앱 정보"
        }
    }

    private var englishTitle: String {
        switch self {
        case .cat: "Cat"
        case .memory: "Memory"
        case .abilities: "Abilities"
        case .day: "Day"
        case .advanced: "Advanced"
        case .start: "Neko Status"
        case .general: "General"
        case .neighbors: "Neighbor Cats"
        case .profile: "My Profile"
        case .ai: "AI"
        case .skills: "Skills"
        case .permissions: "Permissions"
        case .bridge: "Bridge"
        case .skins: "Appearance"
        case .about: "App Info"
        }
    }

    private var japaneseTitle: String {
        switch self {
        case .cat: "ねこ"
        case .memory: "記憶"
        case .abilities: "できること"
        case .day: "一日"
        case .advanced: "詳細"
        case .start: "ネコの状態"
        case .general: "一般"
        case .neighbors: "近くのねこ"
        case .profile: "自分のプロフィール"
        case .ai: "AI"
        case .skills: "スキル"
        case .permissions: "権限"
        case .bridge: "ブリッジ"
        case .skins: "見た目"
        case .about: "アプリ情報"
        }
    }

    private var chineseTitle: String {
        switch self {
        case .cat: "猫咪"
        case .memory: "记忆"
        case .abilities: "能力"
        case .day: "日常"
        case .advanced: "高级"
        case .start: "猫咪状态"
        case .general: "通用"
        case .neighbors: "邻居猫"
        case .profile: "我的资料"
        case .ai: "AI"
        case .skills: "技能"
        case .permissions: "权限"
        case .bridge: "桥接"
        case .skins: "外观"
        case .about: "应用信息"
        }
    }

    public var systemImage: String {
        switch self {
        case .cat: "pawprint"
        case .memory: "brain"
        case .abilities: "wand.and.stars"
        case .day: "sun.max"
        case .advanced: "slider.horizontal.3"
        case .start: "checklist"
        case .general: "gearshape"
        case .neighbors: "person.2.wave.2"
        case .profile: "person.crop.circle"
        case .ai: "sparkles"
        case .skills: "wand.and.stars"
        case .permissions: "hand.raised"
        case .bridge: "point.3.connected.trianglepath.dotted"
        case .skins: "paintpalette"
        case .about: "info.circle"
        }
    }
}
