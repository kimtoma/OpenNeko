import Foundation

/// Bubble copy for native tools (en/ko/ja/zh).
public enum NekoToolCopy {
    public static func approval(_ call: NekoToolCall, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch call {
        case let .timer(seconds, label):
            let d = duration(seconds, l)
            let what = label.isEmpty ? "" : " (\(label))"
            return localized(l, ko: "⏱ \(d) 타이머\(what) 맞출까냥? 눌러서 허락", en: "⏱ Set a \(d) timer\(what)? Click to allow", ja: "⏱ \(d)のタイマー\(what)をセットするにゃ？クリックで許可", zh: "⏱ 设置\(d)计时器\(what)吗？点击允许")
        case let .reminder(seconds, message):
            let d = duration(seconds, l)
            return localized(l, ko: "🔔 \(d) 뒤에 \"\(message)\" 알려줄까냥? 눌러서 허락", en: "🔔 Remind you \"\(message)\" in \(d)? Click to allow", ja: "🔔 \(d)後に「\(message)」を知らせるにゃ？クリックで許可", zh: "🔔 \(d)后提醒“\(message)”吗？点击允许")
        case .copyToClipboard:
            return localized(l, ko: "📋 클립보드에 복사할까냥? 눌러서 허락", en: "📋 Copy it to the clipboard? Click to allow", ja: "📋 クリップボードにコピーするにゃ？クリックで許可", zh: "📋 复制到剪贴板吗？点击允许")
        case let .openURL(url):
            let host = url.host ?? url.absoluteString
            return localized(l, ko: "🌐 \(host) 열까냥? 눌러서 허락", en: "🌐 Open \(host)? Click to allow", ja: "🌐 \(host)を開くにゃ？クリックで許可", zh: "🌐 打开 \(host) 吗？点击允许")
        case let .mcp(server, tool, _):
            return localized(l, ko: "🔌 \(server)의 \(tool) 실행할까냥? 눌러서 허락", en: "🔌 Run \(tool) on \(server)? Click to allow", ja: "🔌 \(server)の\(tool)を実行するにゃ？クリックで許可", zh: "🔌 运行 \(server) 的 \(tool) 吗？点击允许")
        }
    }

    public static func done(_ call: NekoToolCall, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch call {
        case let .timer(seconds, _), let .reminder(seconds, _):
            let d = duration(seconds, l)
            return localized(l, ko: "\(d) 뒤에 알려준다냥", en: "I'll ping you in \(d), nya", ja: "\(d)後に知らせるにゃ", zh: "\(d)后提醒你喵")
        case .copyToClipboard:
            return localized(l, ko: "복사했다냥", en: "Copied, nya", ja: "コピーしたにゃ", zh: "已复制喵")
        case .openURL:
            return localized(l, ko: "열었다냥", en: "Opened it, nya", ja: "開いたにゃ", zh: "打开了喵")
        case .mcp:
            return localized(l, ko: "실행 중이다냥…", en: "Running it, nya…", ja: "実行中にゃ…", zh: "正在运行喵…")
        }
    }

    public static func fired(_ call: NekoToolCall, languageCode: String?) -> String? {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch call {
        case let .timer(_, label):
            let what = label.isEmpty ? "" : " \(label)"
            return localized(l, ko: "⏰ 시간 다 됐다냥!\(what)", en: "⏰ Time's up, nya!\(what)", ja: "⏰ 時間だにゃ！\(what)", zh: "⏰ 时间到了喵！\(what)")
        case let .reminder(_, message):
            return localized(l, ko: "🔔 \(message) 할 시간이다냥", en: "🔔 Reminder: \(message), nya", ja: "🔔 \(message)の時間にゃ", zh: "🔔 提醒：\(message) 喵")
        case .copyToClipboard, .openURL, .mcp:
            return nil
        }
    }

    static func duration(_ seconds: Int, _ language: String) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        var parts: [String] = []
        switch language {
        case "en":
            if hours > 0 { parts.append("\(hours)h") }
            if minutes > 0 { parts.append("\(minutes)m") }
            if secs > 0 { parts.append("\(secs)s") }
            return parts.joined(separator: " ")
        case "ja":
            if hours > 0 { parts.append("\(hours)時間") }
            if minutes > 0 { parts.append("\(minutes)分") }
            if secs > 0 { parts.append("\(secs)秒") }
            return parts.joined()
        case "zh":
            if hours > 0 { parts.append("\(hours)小时") }
            if minutes > 0 { parts.append("\(minutes)分钟") }
            if secs > 0 { parts.append("\(secs)秒") }
            return parts.joined()
        default:
            if hours > 0 { parts.append("\(hours)시간") }
            if minutes > 0 { parts.append("\(minutes)분") }
            if secs > 0 { parts.append("\(secs)초") }
            return parts.joined(separator: " ")
        }
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
