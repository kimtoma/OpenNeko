import Foundation

public enum AppUpdateReason: String, Codable, Equatable, Sendable {
    case notGit
    case dirty
    case behind
    case upToDate
}

public struct AppUpdateDecision: Codable, Equatable, Sendable {
    public let available: Bool
    public let reason: AppUpdateReason
    public let behind: Int

    public init(available: Bool, reason: AppUpdateReason, behind: Int) {
        self.available = available
        self.reason = reason
        self.behind = max(0, behind)
    }

    public static func parseBehind(_ revListCount: String) -> Int {
        let count = Int(revListCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return max(0, count)
    }

    public static func isDirty(_ statusPorcelain: String) -> Bool {
        !statusPorcelain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func decide(isGit: Bool, behind: Int, dirty: Bool) -> AppUpdateDecision {
        guard isGit else {
            return AppUpdateDecision(available: false, reason: .notGit, behind: 0)
        }
        if dirty {
            return AppUpdateDecision(available: false, reason: .dirty, behind: max(0, behind))
        }
        if behind > 0 {
            return AppUpdateDecision(available: true, reason: .behind, behind: behind)
        }
        return AppUpdateDecision(available: false, reason: .upToDate, behind: 0)
    }
}

public enum AppUpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case available(behind: Int, branch: String)
    case upToDate
    case notGit
    case dirty(behind: Int)
    case checkFailed
    case updating
    case failed

    public var isBusy: Bool {
        switch self {
        case .checking, .updating:
            true
        default:
            false
        }
    }

    public var isUpdateAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    public var menuTitle: String {
        menuTitle(languageCode: nil)
    }

    public func menuTitle(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch self {
        case .checking:
            return localized(language: language, ko: "업데이트 확인 중", en: "Checking Updates", ja: "更新確認中", zh: "正在检查更新")
        case .available(let behind, _):
            return localized(language: language, ko: "업데이트 (\(behind))", en: "Update (\(behind))", ja: "更新 (\(behind))", zh: "更新 (\(behind))")
        case .updating:
            return localized(language: language, ko: "업데이트 중", en: "Updating", ja: "更新中", zh: "正在更新")
        default:
            return localized(language: language, ko: "업데이트 확인", en: "Check for Updates", ja: "更新を確認", zh: "检查更新")
        }
    }

    public var menuIsEnabled: Bool {
        !isBusy
    }

    public var bubbleText: String {
        bubbleText(languageCode: nil)
    }

    public func bubbleText(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch self {
        case .idle:
            return ""
        case .checking:
            return localized(language: language, ko: "업데이트 확인 중이다냥...", en: "Checking for updates, nya~...", ja: "更新を確認中だにゃ...", zh: "正在检查更新喵...")
        case .available(let behind, _):
            return localized(language: language, ko: "새 버전이 있다냥! \(behind)개 업데이트다냥", en: "\(behind) update(s) available, nya~", ja: "\(behind)件の更新があるにゃ", zh: "有 \(behind) 个更新喵")
        case .upToDate:
            return localized(language: language, ko: "최신 버전이다냥 ✓", en: "You're on the latest, nya~ ✓", ja: "最新版だにゃ ✓", zh: "已是最新版本喵 ✓")
        case .notGit:
            return localized(language: language, ko: "git 설치본에서만 자동 업데이트할 수 있다냥", en: "Auto-update only works for git installs, nya~", ja: "自動更新はgit版のみだにゃ", zh: "自动更新仅适用于 git 安装版喵")
        case .dirty:
            return localized(language: language, ko: "로컬 변경이 있어 자동 업데이트를 못 한다냥", en: "Local changes blocked auto-update, nya~", ja: "ローカル変更で自動更新できないにゃ", zh: "有本地更改，不能自动更新喵")
        case .checkFailed:
            return localized(language: language, ko: "업데이트 확인을 못 했다냥... 네트워크를 확인해달라냥", en: "Could not check for updates, nya~... check the network.", ja: "更新を確認できなかったにゃ...ネットワークを確認してにゃ", zh: "没能检查更新喵...请检查网络喵")
        case .updating:
            return localized(language: language, ko: "업데이트 받는 중이다냥...", en: "Updating, nya~...", ja: "更新中だにゃ...", zh: "正在更新喵...")
        case .failed:
            return localized(language: language, ko: "업데이트 실패다냥... 잠시 후 다시 시도해달라냥", en: "Update failed, nya~... please try again later.", ja: "更新に失敗したにゃ...後でもう一度試してにゃ", zh: "更新失败喵...稍后再试喵")
        }
    }

    private func localized(language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
