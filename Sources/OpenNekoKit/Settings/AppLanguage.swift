import Foundation

public enum AppLanguage {
    public static let supportedCodes = ["ko", "en", "ja", "zh"]

    public static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let code = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        if supportedCodes.contains(code) {
            return code
        }
        if code.hasPrefix("zh") {
            return "zh"
        }
        guard let baseCode = code.split(separator: "-").first.map(String.init) else {
            return nil
        }
        return supportedCodes.contains(baseCode) ? baseCode : nil
    }

    public static func resolved(
        _ storedCode: String?,
        localeIdentifier: String = Locale.current.identifier
    ) -> String {
        if let code = normalized(storedCode) {
            return code
        }

        let lowercased = localeIdentifier.lowercased()
        if lowercased.hasPrefix("zh") {
            return "zh"
        }

        let language = Locale(identifier: localeIdentifier)
            .language
            .languageCode?
            .identifier
            .lowercased()
        if let language, supportedCodes.contains(language) {
            return language
        }

        return "en"
    }

    public static func displayName(for code: String?) -> String {
        switch normalized(code) {
        case "ko": "한국어"
        case "en": "English"
        case "ja": "日本語"
        case "zh": "简体中文"
        default: "시스템 기본"
        }
    }
}
