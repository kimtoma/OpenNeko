public struct LaunchAtLoginSetting: Equatable, Sendable {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var title: String {
        title(languageCode: nil)
    }

    public func title(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Launch at Login"
        case "ja": "ログイン時に起動"
        case "zh": "登录时启动"
        default: "로그인 시 자동 실행"
        }
    }

    public var detail: String {
        detail(languageCode: nil)
    }

    public func detail(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Start openNeko automatically when you sign in to your Mac."
        case "ja": "MacにログインしたときopenNekoを自動で起動します。"
        case "zh": "登录 Mac 时自动启动 openNeko。"
        default: "Mac에 로그인하면 openNeko를 자동으로 시작합니다."
        }
    }
}
