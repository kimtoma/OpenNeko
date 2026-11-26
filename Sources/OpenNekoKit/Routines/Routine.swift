import Foundation

/// Which days a routine runs on.
public enum RoutineDays: String, Codable, CaseIterable, Equatable, Sendable {
    case everyday
    case weekdays
    case weekends

    /// `weekday` uses `Calendar` numbering: 1 = Sunday ... 7 = Saturday.
    public func includes(weekday: Int) -> Bool {
        switch self {
        case .everyday: true
        case .weekdays: (2...6).contains(weekday)
        case .weekends: weekday == 1 || weekday == 7
        }
    }
}

/// A scheduled job the cat runs on its own, such as a morning briefing.
/// Without a folder it is a chat prompt sent to the current AI provider.
/// With a folder it runs as a read-only Claude Code task inside that folder.
public struct Routine: Codable, Equatable, Identifiable, Sendable {
    public static let titleLimit = 40
    public static let promptLimit = 1_500

    public var id: String
    public var title: String
    public var prompt: String
    public var hour: Int
    public var minute: Int
    public var days: RoutineDays
    public var enabled: Bool
    public var folder: String?
    /// Day key (`yyyy-MM-dd`, local calendar) of the last run, so a routine
    /// runs at most once per day.
    public var lastRunDay: String?

    public init(
        id: String,
        title: String,
        prompt: String,
        hour: Int,
        minute: Int,
        days: RoutineDays = .everyday,
        enabled: Bool = true,
        folder: String? = nil,
        lastRunDay: String? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.hour = hour
        self.minute = minute
        self.days = days
        self.enabled = enabled
        self.folder = folder
        self.lastRunDay = lastRunDay
        self = normalized()
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, prompt, hour, minute, days, enabled, folder, lastRunDay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString,
            title: (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "",
            prompt: (try? c.decodeIfPresent(String.self, forKey: .prompt)) ?? "",
            hour: (try? c.decodeIfPresent(Int.self, forKey: .hour)) ?? 9,
            minute: (try? c.decodeIfPresent(Int.self, forKey: .minute)) ?? 0,
            days: (try? c.decodeIfPresent(RoutineDays.self, forKey: .days)) ?? .everyday,
            enabled: (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true,
            folder: try? c.decodeIfPresent(String.self, forKey: .folder),
            lastRunDay: try? c.decodeIfPresent(String.self, forKey: .lastRunDay)
        )
    }

    public var isRunnable: Bool {
        enabled && !prompt.isEmpty
    }

    public func normalized() -> Routine {
        var copy = self
        copy.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit))
        copy.prompt = String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.promptLimit))
        copy.hour = min(max(hour, 0), 23)
        copy.minute = min(max(minute, 0), 59)
        let trimmedFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        copy.folder = trimmedFolder.isEmpty ? nil : trimmedFolder
        return copy
    }

    /// "08:30"
    public var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public enum RoutineScheduler {
    /// A routine missed while the Mac slept still runs if the Mac wakes
    /// within this window; later than that it waits for the next day.
    public static let catchUpWindow: TimeInterval = 2 * 60 * 60
    public static let maxRoutines = 12

    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The routine's time on the same calendar day as `day`.
    public static func scheduledDate(for routine: Routine, onDayOf day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: day)
    }

    /// Routines that should run now: enabled, scheduled for today, time has
    /// come (within the catch-up window), and not yet run today.
    public static func due(_ routines: [Routine], now: Date, calendar: Calendar) -> [Routine] {
        let today = dayKey(now, calendar: calendar)
        let weekday = calendar.component(.weekday, from: now)
        return routines.filter { routine in
            guard routine.isRunnable,
                  routine.days.includes(weekday: weekday),
                  routine.lastRunDay != today,
                  let scheduled = scheduledDate(for: routine, onDayOf: now, calendar: calendar)
            else { return false }
            let late = now.timeIntervalSince(scheduled)
            return late >= 0 && late <= catchUpWindow
        }
    }

    /// The next time this routine will run, for display.
    public static func nextRun(for routine: Routine, after now: Date, calendar: Calendar) -> Date? {
        guard routine.isRunnable else { return nil }
        let today = dayKey(now, calendar: calendar)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  routine.days.includes(weekday: calendar.component(.weekday, from: day)),
                  let scheduled = scheduledDate(for: routine, onDayOf: day, calendar: calendar)
            else { continue }
            if offset == 0 && (scheduled <= now || routine.lastRunDay == today) { continue }
            return scheduled
        }
        return nil
    }

    public static func markingRan(_ id: String, in routines: [Routine], now: Date, calendar: Calendar) -> [Routine] {
        let today = dayKey(now, calendar: calendar)
        return routines.map { routine in
            var copy = routine
            if copy.id == id { copy.lastRunDay = today }
            return copy
        }
    }

    /// Applies edits from the routines window. A new or rescheduled routine
    /// whose time already passed today waits until its next day instead of
    /// firing the moment it is saved.
    public static func reconcile(
        edited: [Routine],
        previous: [Routine],
        now: Date,
        calendar: Calendar
    ) -> [Routine] {
        let today = dayKey(now, calendar: calendar)
        let byID = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        return edited.prefix(maxRoutines).compactMap { raw -> Routine? in
            var routine = raw.normalized()
            guard seen.insert(routine.id).inserted else { return nil }
            let old = byID[routine.id]
            let scheduleChanged = old.map {
                $0.hour != routine.hour || $0.minute != routine.minute || $0.days != routine.days
                    || (!$0.enabled && routine.enabled)
            } ?? true
            routine.lastRunDay = old?.lastRunDay
            if scheduleChanged,
               let scheduled = scheduledDate(for: routine, onDayOf: now, calendar: calendar),
               scheduled <= now {
                routine.lastRunDay = today
            }
            return routine
        }
    }

    /// The message sent to the chat provider for a chat routine.
    public static func chatPrompt(for routine: Routine, now: Date, languageCode: String?, calendar: Calendar) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: RoutineCopy.localeIdentifier(l))
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMdEEEEjmm")
        let when = formatter.string(from: now)
        let header: String
        switch l {
        case "en": header = "[Scheduled routine \"\(routine.title)\" · \(when)] Keep the answer short enough for a speech bubble."
        case "ja": header = "[定期ルーティン「\(routine.title)」· \(when)] 吹き出しに収まるよう短く答えて。"
        case "zh": header = "[定时例程“\(routine.title)” · \(when)] 回答要简短，适合气泡显示。"
        default: header = "[정기 루틴 \"\(routine.title)\" · \(when)] 말풍선에 들어갈 만큼 짧게 답해줘."
        }
        return header + "\n" + routine.prompt
    }
}

/// Starter routines offered in the routines window.
public enum RoutineTemplate: String, CaseIterable, Sendable {
    case morningBriefing
    case endOfDay
    case repoDigest

    public func routine(id: String, languageCode: String?) -> Routine {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch self {
        case .morningBriefing:
            return Routine(
                id: id,
                title: RoutineCopy.pick(l, ko: "아침 브리핑", en: "Morning briefing", ja: "朝のブリーフィング", zh: "早间简报"),
                prompt: RoutineCopy.pick(l,
                    ko: "오늘 날짜와 요일에 맞춰 짧게 아침 인사를 해줘. 그리고 오늘 가장 먼저 집중할 일 하나를 정하자고 물어봐줘.",
                    en: "Greet me briefly for today's date and weekday, then ask me to pick the one thing to focus on first today.",
                    ja: "今日の日付と曜日に合わせて短く朝のあいさつをして、今日まず集中することを一つ決めようと聞いて。",
                    zh: "根据今天的日期和星期简短地道早安，然后问我今天最先专注的一件事是什么。"),
                hour: 8, minute: 30, days: .weekdays
            )
        case .endOfDay:
            return Routine(
                id: id,
                title: RoutineCopy.pick(l, ko: "하루 마무리", en: "End of day", ja: "一日の締め", zh: "下班收尾"),
                prompt: RoutineCopy.pick(l,
                    ko: "오늘 하루 수고했다고 짧게 말해주고, 내일 아침 첫 번째로 할 일을 하나 적어두자고 제안해줘.",
                    en: "Briefly tell me I did well today and suggest writing down the first thing to do tomorrow morning.",
                    ja: "今日一日おつかれさまと短く伝えて、明日の朝いちばんにやることを一つメモしようと提案して。",
                    zh: "简短地说今天辛苦了，并建议我记下明天早上要做的第一件事。"),
                hour: 18, minute: 0, days: .weekdays
            )
        case .repoDigest:
            return Routine(
                id: id,
                title: RoutineCopy.pick(l, ko: "어제 커밋 요약", en: "Yesterday's commits", ja: "昨日のコミット要約", zh: "昨日提交摘要"),
                prompt: RoutineCopy.pick(l,
                    ko: "git log로 지난 24시간 동안의 커밋을 확인해서 무엇이 바뀌었는지 3줄로 요약해줘. 파일은 수정하지 마.",
                    en: "Check the commits from the last 24 hours with git log and summarize what changed in 3 lines. Do not modify files.",
                    ja: "git logで直近24時間のコミットを確認して、何が変わったかを3行で要約して。ファイルは変更しないで。",
                    zh: "用 git log 查看过去24小时的提交，用三行总结改了什么。不要修改文件。"),
                hour: 9, minute: 0, days: .weekdays
            )
        }
    }

    /// The repo digest needs a project folder to be useful.
    public var needsFolder: Bool { self == .repoDigest }
}
