import Foundation

/// A native tool call the chat model asked for. Tools are declared here in
/// app code only (never loaded from skills or downloads) and every call runs
/// only after the user clicks the approval bubble.
public enum NekoToolCall: Equatable, Sendable {
    case timer(seconds: Int, label: String)
    case reminder(seconds: Int, message: String)
    case copyToClipboard(String)
    case openURL(URL)

    public static let maxDelaySeconds = 24 * 60 * 60
    public static let maxClipboardCharacters = 10_000

    public var name: String {
        switch self {
        case .timer: "timer"
        case .reminder: "reminder"
        case .copyToClipboard: "clipboard"
        case .openURL: "open_url"
        }
    }

    /// Short description for the activity log.
    public var logDetail: String {
        switch self {
        case let .timer(seconds, label): "\(seconds)s \(label)"
        case let .reminder(seconds, message): "\(seconds)s \(message)"
        case let .copyToClipboard(text): "\(text.count) chars"
        case let .openURL(url): url.absoluteString
        }
    }

    /// Validates one decoded JSON object. Returns nil for unknown tools or
    /// out-of-range / unsafe arguments.
    public static func validated(from object: [String: Any]) -> NekoToolCall? {
        guard let tool = (object["tool"] as? String)?.lowercased() else { return nil }
        switch tool {
        case "timer":
            guard let seconds = delaySeconds(object) else { return nil }
            return .timer(seconds: seconds, label: shortText(object["label"]))
        case "reminder":
            guard let seconds = delaySeconds(object) else { return nil }
            let message = shortText(object["message"])
            return message.isEmpty ? nil : .reminder(seconds: seconds, message: message)
        case "clipboard":
            guard let text = object["text"] as? String, !text.isEmpty, text.count <= maxClipboardCharacters else {
                return nil
            }
            return .copyToClipboard(text)
        case "open_url":
            guard
                let raw = (object["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                let url = URL(string: raw),
                let scheme = url.scheme?.lowercased(),
                ["http", "https"].contains(scheme),
                let host = url.host, !host.isEmpty,
                url.user == nil, url.password == nil
            else {
                return nil
            }
            return .openURL(url)
        default:
            return nil
        }
    }

    static func delaySeconds(_ object: [String: Any]) -> Int? {
        let seconds = number(object["seconds"]) ?? 0
        let minutes = number(object["minutes"]) ?? 0
        let total = Int((seconds + minutes * 60).rounded())
        guard total >= 1, total <= maxDelaySeconds else { return nil }
        return total
    }

    static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            // JSON booleans also bridge to NSNumber; reject them.
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.doubleValue
        }
        if let string = value as? String { return Double(string) }
        return nil
    }

    static func shortText(_ value: Any?) -> String {
        let text = (value as? String ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(80))
    }
}

/// The text protocol that lets every provider (CLI or HTTP) request a tool:
/// the model writes `<neko-tool>{"tool":"timer","minutes":5}</neko-tool>`.
public enum NekoToolProtocol {
    public static let openTag = "<neko-tool>"
    public static let closeTag = "</neko-tool>"
    public static let maxCallsPerReply = 1

    public struct Extraction: Equatable, Sendable {
        public let text: String
        public let calls: [NekoToolCall]
        public let rejectedCount: Int
    }

    /// Removes every tool block from the reply and returns the valid calls
    /// (at most `maxCallsPerReply`).
    public static func extract(from reply: String) -> Extraction {
        var text = ""
        var calls: [NekoToolCall] = []
        var rejected = 0
        var rest = Substring(reply)

        while let open = rest.range(of: openTag) {
            text += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: closeTag) else {
                rejected += 1
                rest = ""
                break
            }
            let body = afterOpen[..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = body.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let call = NekoToolCall.validated(from: object),
               calls.count < maxCallsPerReply {
                calls.append(call)
            } else {
                rejected += 1
            }
            rest = afterOpen[close.upperBound...]
        }
        text += rest
        return Extraction(text: collapse(text), calls: calls, rejectedCount: rejected)
    }

    /// Hides tool markup from a partially streamed reply.
    public static func stripPartial(_ partial: String) -> String {
        var result = extract(from: partial).text
        // A tag that has started streaming but is not complete yet.
        for length in stride(from: openTag.count - 1, through: 1, by: -1) {
            if result.hasSuffix(String(openTag.prefix(length))) {
                result = String(result.dropLast(length)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return result
    }

    static func collapse(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func instructions(languageCode: String?) -> String {
        let rules = """
        <neko-tool>{"tool":"timer","minutes":5,"label":"tea"}</neko-tool>
        <neko-tool>{"tool":"reminder","minutes":30,"message":"stand up"}</neko-tool>
        <neko-tool>{"tool":"clipboard","text":"..."}</neko-tool>
        <neko-tool>{"tool":"open_url","url":"https://..."}</neko-tool>
        """
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return "Tools: only when the user clearly asks for a timer, reminder, copying text, or opening a web page, add exactly one block like below after a short reply. The user approves it before it runs, so never say it is already done.\n\(rules)"
        case "ja":
            return "ツール: ユーザーがタイマー、リマインダー、テキストのコピー、Webページを開くことをはっきり頼んだときだけ、短い返事の後に次のようなブロックを1つだけ付ける。実行前にユーザーが承認するので、もう実行したとは言わない。\n\(rules)"
        case "zh":
            return "工具：只有当用户明确要求计时器、提醒、复制文字或打开网页时，在简短回复后附上一个如下的块。执行前需要用户批准，所以不要说已经完成。\n\(rules)"
        default:
            return "도구: 사용자가 타이머, 리마인더, 텍스트 복사, 웹페이지 열기를 분명히 요청할 때만 짧은 답 뒤에 아래 같은 블록을 딱 하나 붙여라. 실행 전에 사용자가 승인하니 이미 했다고 말하지 마라.\n\(rules)"
        }
    }
}
