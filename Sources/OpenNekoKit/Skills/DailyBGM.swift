import Foundation

public struct DailyBGMPreset: Equatable, Sendable {
    public let id: String
    public let title: String
    public let terms: [String]

    public init(id: String, title: String, terms: [String]) {
        self.id = id
        self.title = title
        self.terms = terms
    }
}

public struct DailyBGM: Equatable, Sendable {
    public let id: String
    public let title: String
    public let dateKey: String
    public let query: String
    public let url: URL
    public let service: String
    public let personalized: Bool
}

public enum DailyBGMSelector {
    public static let presets: [DailyBGMPreset] = [
        DailyBGMPreset(id: "lofi-coding", title: "Lo-fi coding playlist", terms: ["lofi", "coding", "focus"]),
        DailyBGMPreset(id: "cafe-jazz", title: "Cafe jazz work playlist", terms: ["cafe jazz", "work", "instrumental"]),
        DailyBGMPreset(id: "rainy-focus", title: "Rainy focus playlist", terms: ["rain sounds", "ambient", "study"]),
        DailyBGMPreset(id: "city-pop-work", title: "City pop work playlist", terms: ["city pop", "work", "upbeat"]),
        DailyBGMPreset(id: "piano-deep-work", title: "Piano deep work playlist", terms: ["piano", "deep work", "instrumental"]),
        DailyBGMPreset(id: "synthwave-night", title: "Synthwave night drive playlist", terms: ["synthwave", "night drive", "focus"]),
        DailyBGMPreset(id: "chillhop-desk", title: "Chillhop desk playlist", terms: ["chillhop", "desk work", "beats"]),
        DailyBGMPreset(id: "game-ost-study", title: "Game OST study playlist", terms: ["game ost", "study", "relaxing"]),
        DailyBGMPreset(id: "ambient-coding", title: "Ambient coding playlist", terms: ["ambient", "coding", "no vocals"]),
        DailyBGMPreset(id: "k-indie-focus", title: "K-indie focus playlist", terms: ["korean indie", "focus", "playlist"]),
    ]

    public static func pick(
        date: Date = Date(),
        preference rawPreference: String? = nil,
        profile: UserProfile = .empty,
        languageCode: String? = "en",
        presets rawPresets: [DailyBGMPreset] = DailyBGMSelector.presets,
        calendar: Calendar = .current
    ) -> DailyBGM {
        let list = rawPresets.isEmpty ? presets : rawPresets
        let key = dateKey(date, calendar: calendar)
        let language = AppLanguage.normalized(languageCode) ?? "en"
        let preference = normalizePreference(rawPreference)
        let seed = [
            key,
            language,
            preference,
            profile.name,
            profile.birthDate,
            profile.calendar,
        ].joined(separator: "|")
        let preset = list[Int(hashString(seed) % UInt32(list.count))]
        let query = buildQuery(
            preset: preset,
            preference: preference,
            languageCode: language,
            date: date,
            calendar: calendar
        )

        return DailyBGM(
            id: preset.id,
            title: preset.title,
            dateKey: key,
            query: query,
            url: buildYouTubeMusicSearchURL(query: query),
            service: "YouTube Music",
            personalized: !preference.isEmpty || !profile.name.isEmpty || !profile.birthDate.isEmpty
        )
    }

    public static func dateKey(_ date: Date, calendar rawCalendar: Calendar = .current) -> String {
        let calendar = rawCalendar
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    public static func isStopCommand(_ text: String) -> Bool {
        ["stop", "off", "pause", "정지", "중지", "끄기"].contains(text.lowercased())
    }

    public static func normalizePreference(_ value: String?) -> String {
        String((value ?? "").prefix(80))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func buildYouTubeMusicSearchURL(query: String) -> URL {
        var components = URLComponents(string: "https://music.youtube.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    private static func buildQuery(
        preset: DailyBGMPreset,
        preference: String,
        languageCode: String,
        date: Date,
        calendar: Calendar
    ) -> String {
        uniqueTerms(
            [preference]
                + preset.terms
                + [timeTerm(date, languageCode: languageCode, calendar: calendar)]
                + languageTerms(languageCode)
        ).joined(separator: " ")
    }

    private static func languageTerms(_ languageCode: String) -> [String] {
        switch AppLanguage.normalized(languageCode) ?? "en" {
        case "ko":
            ["BGM", "플레이리스트"]
        case "ja":
            ["BGM", "プレイリスト"]
        case "zh":
            ["BGM", "播放列表"]
        default:
            ["BGM", "playlist"]
        }
    }

    private static func timeTerm(_ date: Date, languageCode: String, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let bucket: String
        if hour < 11 {
            bucket = "morning"
        } else if hour < 17 {
            bucket = "afternoon"
        } else if hour < 21 {
            bucket = "evening"
        } else {
            bucket = "night"
        }

        switch (AppLanguage.normalized(languageCode) ?? "en", bucket) {
        case ("ko", "morning"): return "아침"
        case ("ko", "afternoon"): return "오후"
        case ("ko", "evening"): return "저녁"
        case ("ko", "night"): return "밤"
        case ("ja", "morning"): return "朝"
        case ("ja", "afternoon"): return "午後"
        case ("ja", "evening"): return "夕方"
        case ("ja", "night"): return "夜"
        case ("zh", "morning"): return "早晨"
        case ("zh", "afternoon"): return "下午"
        case ("zh", "evening"): return "傍晚"
        case ("zh", "night"): return "夜晚"
        default: return bucket
        }
    }

    private static func uniqueTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in terms {
            let term = normalizePreference(raw)
            let key = term.lowercased()
            guard !term.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(term)
        }
        return result
    }

    private static func hashString(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for scalar in text.unicodeScalars {
            hash ^= scalar.value
            hash = hash &* 16_777_619
        }
        return hash
    }
}
