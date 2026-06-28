import Foundation

public enum NekoSkillInput: String, Codable, Equatable, Sendable {
    case prompt
    case clipboard
    case none

    public var title: String {
        title(languageCode: nil)
    }

    public func title(languageCode: String?) -> String {
        switch self {
        case .prompt:
            switch AppLanguage.normalized(languageCode) ?? "ko" {
            case "en": return "Input"
            case "ja": return "入力"
            case "zh": return "输入"
            default: return "입력"
            }
        case .clipboard:
            switch AppLanguage.normalized(languageCode) ?? "ko" {
            case "en": return "Clipboard"
            case "ja": return "クリップボード"
            case "zh": return "剪贴板"
            default: return "클립보드"
            }
        case .none:
            switch AppLanguage.normalized(languageCode) ?? "ko" {
            case "en": return "Run"
            case "ja": return "実行"
            case "zh": return "运行"
            default: return "바로 실행"
            }
        }
    }
}

public enum NekoSkillSource: String, Codable, Equatable, Sendable {
    case bundled
    case user
}

public struct NekoSkill: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let input: NekoSkillInput
    public let body: String
    public let source: NekoSkillSource

    public init(
        id: String,
        name: String,
        description: String,
        input: NekoSkillInput,
        body: String,
        source: NekoSkillSource
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.input = input
        self.body = body
        self.source = source
    }
}
