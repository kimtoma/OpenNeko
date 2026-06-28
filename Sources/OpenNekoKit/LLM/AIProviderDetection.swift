import Foundation

public enum AIProviderDetectionSource: String, Equatable, Sendable {
    case environment
    case oauth
    case local

    public func label(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch self {
        case .environment:
            switch language {
            case "en": return "Environment"
            case "ja": return "環境変数"
            case "zh": return "环境变量"
            default: return "환경 변수"
            }
        case .oauth:
            switch language {
            case "en": return "Login"
            case "ja": return "ログイン"
            case "zh": return "登录"
            default: return "로그인"
            }
        case .local:
            switch language {
            case "en": return "Local"
            case "ja": return "ローカル"
            case "zh": return "本地"
            default: return "로컬"
            }
        }
    }
}

public struct AIProviderDetection: Equatable, Identifiable, Sendable {
    public let presetID: String
    public let source: AIProviderDetectionSource
    public let detail: String
    public let models: [String]
    public let model: String

    public init(
        presetID: String,
        source: AIProviderDetectionSource,
        detail: String = "",
        models: [String] = [],
        model: String = ""
    ) {
        self.presetID = presetID
        self.source = source
        self.detail = detail
        self.models = models
        self.model = model
    }

    public var id: String {
        presetID
    }

    public var isRecommended: Bool {
        AIProviderPreset.preset(for: presetID)?.isRecommended == true
    }

    public func title(languageCode: String?) -> String {
        AIProviderPreset.preset(for: presetID)?.title(languageCode: languageCode) ?? presetID
    }

    public func subtitle(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch source {
        case .environment:
            return Self.localized(
                language,
                ko: "\(detail)에서 키를 찾았습니다.",
                en: "Found a key in \(detail).",
                ja: "\(detail)でキーを見つけました。",
                zh: "已在 \(detail) 中找到密钥。"
            )
        case .oauth:
            return Self.localized(
                language,
                ko: "\(detail)가 설치되어 바로 사용할 수 있습니다.",
                en: "\(detail) is installed and ready.",
                ja: "\(detail)がインストール済みですぐ使えます。",
                zh: "\(detail) 已安装，可直接使用。"
            )
        case .local:
            if models.isEmpty {
                return Self.localized(
                    language,
                    ko: "\(detail) 로컬 서버를 찾았습니다.",
                    en: "Found local server at \(detail).",
                    ja: "\(detail)のローカルサーバーを見つけました。",
                    zh: "已找到 \(detail) 本地服务器。"
                )
            }
            let preview = models.prefix(2).joined(separator: ", ")
            return Self.localized(
                language,
                ko: "\(detail) · \(preview)",
                en: "\(detail) · \(preview)",
                ja: "\(detail) · \(preview)",
                zh: "\(detail) · \(preview)"
            )
        }
    }

    public func config() -> AIProviderConfig {
        if model.isEmpty {
            return AIProviderPreset.config(for: presetID)
        }
        return AIProviderPreset.config(
            for: presetID,
            overrides: AIProviderConfig(model: model)
        )
    }

    public static func environmentDetections(
        environment: [String: String],
        presets: [AIProviderPreset] = AIProviderPreset.all
    ) -> [AIProviderDetection] {
        presets.compactMap { preset in
            if let key = preset.environmentKey, environment[key]?.isEmpty == false {
                return AIProviderDetection(presetID: preset.id, source: .environment, detail: key)
            }
            if let key = preset.alternateEnvironmentKey, environment[key]?.isEmpty == false {
                return AIProviderDetection(presetID: preset.id, source: .environment, detail: key)
            }
            return nil
        }
    }

    public static func cliDetection(
        presetID: String,
        executable: String,
        executableAvailable: Bool,
        codexLoginStatusOutput: String? = nil
    ) -> AIProviderDetection? {
        guard executableAvailable else {
            return nil
        }
        if presetID == AIProviderPreset.defaultID,
           !codexLoginStatusLooksReady(codexLoginStatusOutput ?? "") {
            return nil
        }
        return AIProviderDetection(presetID: presetID, source: .oauth, detail: executable)
    }

    public static func codexLoginStatusLooksReady(_ output: String) -> Bool {
        output.range(of: #"Logged in using ChatGPT"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    public static func ollamaModels(from data: Data) -> [String] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawModels = object["models"] as? [[String: Any]]
        else {
            return []
        }

        return rawModels.compactMap { model in
            let name = (model["name"] as? String) ?? (model["model"] as? String)
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    public static func ollamaDetection(models: [String]) -> AIProviderDetection? {
        guard !models.isEmpty else {
            return nil
        }
        return AIProviderDetection(
            presetID: "ollama",
            source: .local,
            detail: "127.0.0.1:11434",
            models: models,
            model: models[0]
        )
    }

    public static func uniqueReady(_ detections: [AIProviderDetection]) -> [AIProviderDetection] {
        var seen = Set<String>()
        var result: [AIProviderDetection] = []
        for detection in detections {
            guard AIProviderPreset.preset(for: detection.presetID) != nil else {
                continue
            }
            guard !seen.contains(detection.presetID) else {
                continue
            }
            seen.insert(detection.presetID)
            result.append(detection)
        }
        return result
    }

    private static func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": return en
        case "ja": return ja
        case "zh": return zh
        default: return ko
        }
    }
}
