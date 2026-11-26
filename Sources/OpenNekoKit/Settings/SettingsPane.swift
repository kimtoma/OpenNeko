/// Settings sections. The sidebar shows `sidebar`: one short topic per
/// pane, so no pane needs to scroll. The other cases are older section
/// names kept for deep links and map to a sidebar pane.
public enum SettingsPane: String, CaseIterable, Equatable, Identifiable {
    case cat
    case chat
    case tools
    case connectors
    case agents
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
    public static let sidebar: [SettingsPane] = [
        .cat, .chat, .memory, .ai,
        .tools, .skills, .connectors,
        .day, .agents, .neighbors, .permissions, .about,
    ]

    /// Which sidebar pane holds this section (for old links and tiles).
    public var sidebarPane: SettingsPane {
        switch self {
        case .cat, .start, .skins: .cat
        case .chat: .chat
        case .memory, .profile: .memory
        case .ai: .ai
        case .tools, .abilities: .tools
        case .skills: .skills
        case .connectors: .connectors
        case .day: .day
        case .agents, .bridge: .agents
        case .neighbors: .neighbors
        case .permissions: .permissions
        case .about, .advanced, .general: .about
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
            return pick("이름과 모습", "Name and look", "名前と見た目", "名字和外观")
        case .chat:
            return pick("언어, 수다 정도, 효과음", "Language, chattiness and sounds", "言語、おしゃべり度、効果音", "语言、话痨程度和音效")
        case .memory:
            return pick("고양이가 기억하는 나와 요즘 이야기", "What the cat remembers about you", "ねこが覚えているあなたのこと", "猫咪记住的关于你的事")
        case .ai:
            return pick("대화에 쓸 AI 연결", "The AI the cat talks with", "会話に使うAI", "聊天使用的 AI")
        case .tools:
            return pick("고양이가 직접 하는 일과 웹 검색", "What the cat does itself, and web search", "ねこが自分でできることとWeb検索", "猫咪自己能做的事和网页搜索")
        case .skills:
            return pick("정해 둔 일을 한 번에 실행", "Saved jobs you run in one click", "決めておいた作業をワンクリックで", "一键运行预设任务")
        case .connectors:
            return pick("대화에서 쓸 MCP 서버", "MCP servers to use in chat", "会話で使うMCPサーバー", "聊天中使用的 MCP 服务器")
        case .day:
            return pick("일정, 루틴, 쉬는 시간", "Calendar, routines and breaks", "予定、ルーティン、休憩", "日程、例程和休息")
        case .agents:
            return pick("Claude Code·Codex 감지와 알림", "Spot Claude Code and Codex, get notified", "Claude Code・Codexの検知と通知", "检测 Claude Code 和 Codex 并接收通知")
        case .neighbors:
            return pick("같은 네트워크의 다른 고양이", "Other cats on your network", "同じネットワークのねこ", "同一网络中的其他猫")
        case .permissions:
            return pick("타이핑 반응에 필요한 macOS 권한", "macOS permissions for typing reactions", "タイピング反応に必要なmacOS権限", "打字反应所需的 macOS 权限")
        default:
            return pick("로그인 시 시작, 버전, 업데이트", "Launch at login, version and updates", "ログイン時に起動、バージョン、アップデート", "登录时启动、版本和更新")
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
        case .chat: "대화"
        case .tools: "도구"
        case .connectors: "커넥터"
        case .agents: "에이전트"
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
        case .chat: "Chat"
        case .tools: "Tools"
        case .connectors: "Connectors"
        case .agents: "Agents"
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
        case .chat: "会話"
        case .tools: "ツール"
        case .connectors: "コネクタ"
        case .agents: "エージェント"
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
        case .chat: "聊天"
        case .tools: "工具"
        case .connectors: "连接器"
        case .agents: "智能体"
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
        case .chat: "bubble.left.and.bubble.right"
        case .tools: "hammer"
        case .connectors: "powerplug"
        case .agents: "terminal"
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
