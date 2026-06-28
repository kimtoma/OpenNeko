public enum InputMonitoringPermissionStatus: Equatable {
    case granted
    case missing
}

public struct InputMonitoringPermissionMenu: Equatable {
    public let status: InputMonitoringPermissionStatus
    public let accessibilityGranted: Bool
    public let inputMonitoringGranted: Bool

    public init(
        status: InputMonitoringPermissionStatus,
        accessibilityGranted: Bool? = nil,
        inputMonitoringGranted: Bool? = nil
    ) {
        self.status = status
        self.accessibilityGranted = accessibilityGranted ?? (status == .granted)
        self.inputMonitoringGranted = inputMonitoringGranted ?? (status == .granted)
    }

    public var statusTitle: String {
        statusTitle(languageCode: nil)
    }

    public func statusTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            status == .granted ? "Typing Reaction On" : "Typing Permission Needed"
        case "ja":
            status == .granted ? "入力反応オン" : "入力権限が必要"
        case "zh":
            status == .granted ? "输入反应已开启" : "需要输入权限"
        default:
            switch status {
            case .granted: "타이핑 반응 켜짐"
            case .missing: "타이핑 권한 필요"
            }
        }
    }

    public func accessibilityTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Accessibility"
        case "ja": "アクセシビリティ"
        case "zh": "辅助功能"
        default: "손쉬운 사용"
        }
    }

    public func inputMonitoringTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Input Monitoring"
        case "ja": "入力監視"
        case "zh": "输入监控"
        default: "입력 모니터링"
        }
    }

    public func permissionStateTitle(granted: Bool, languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": granted ? "Allowed" : "Needs permission"
        case "ja": granted ? "許可済み" : "許可が必要"
        case "zh": granted ? "已授权" : "需要授权"
        default: granted ? "허용됨" : "허용 필요"
        }
    }

    public func openAccessibilityTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Open Accessibility"
        case "ja": "アクセシビリティを開く"
        case "zh": "打开辅助功能"
        default: "손쉬운 사용 열기"
        }
    }

    public var openSettingsTitle: String {
        openSettingsTitle(languageCode: nil)
    }

    public func openSettingsTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Open Input Monitoring"
        case "ja": "入力監視を開く"
        case "zh": "打开输入监控"
        default: "입력 모니터링 설정 열기"
        }
    }

    public var retryTitle: String {
        retryTitle(languageCode: nil)
    }

    public func retryTitle(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "Retry Typing Reaction"
        case "ja": "入力反応を再試行"
        case "zh": "重试输入反应"
        default: "타이핑 반응 다시 시도"
        }
    }

    public var needsUserAction: Bool {
        !accessibilityGranted || !inputMonitoringGranted
    }
}
