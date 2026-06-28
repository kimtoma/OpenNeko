public enum SettingsPane: String, CaseIterable, Equatable, Identifiable {
    case start
    case ai
    case skins
    case skills
    case profile
    case general
    case neighbors
    case permissions
    case bridge
    case about

    public var id: String { rawValue }

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
        case .start: "시작"
        case .general: "일반"
        case .neighbors: "이웃 고양이"
        case .profile: "내 프로필"
        case .ai: "AI"
        case .skills: "스킬"
        case .permissions: "권한"
        case .bridge: "브리지"
        case .skins: "외형"
        case .about: "정보"
        }
    }

    private var englishTitle: String {
        switch self {
        case .start: "Start"
        case .general: "General"
        case .neighbors: "Neighbor Cats"
        case .profile: "My Profile"
        case .ai: "AI"
        case .skills: "Skills"
        case .permissions: "Permissions"
        case .bridge: "Bridge"
        case .skins: "Appearance"
        case .about: "About"
        }
    }

    private var japaneseTitle: String {
        switch self {
        case .start: "開始"
        case .general: "一般"
        case .neighbors: "近くのねこ"
        case .profile: "自分のプロフィール"
        case .ai: "AI"
        case .skills: "スキル"
        case .permissions: "権限"
        case .bridge: "ブリッジ"
        case .skins: "見た目"
        case .about: "情報"
        }
    }

    private var chineseTitle: String {
        switch self {
        case .start: "开始"
        case .general: "通用"
        case .neighbors: "邻居猫"
        case .profile: "我的资料"
        case .ai: "AI"
        case .skills: "技能"
        case .permissions: "权限"
        case .bridge: "桥接"
        case .skins: "外观"
        case .about: "关于"
        }
    }

    public var systemImage: String {
        switch self {
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
