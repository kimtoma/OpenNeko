import Foundation

/// Something the model wants the cat to remember.
public struct MemoryProposal: Equatable, Sendable {
    public let file: MemoryFile
    public let text: String

    public init(file: MemoryFile, text: String) {
        self.file = file
        self.text = text
    }
}

/// The text protocol for memory writes, the same shape as `NekoToolProtocol`:
/// `<neko-memory>{"file":"user","add":"Prefers green tea"}</neko-memory>`.
/// Only `user` and `memory` are writable; `soul` belongs to the user.
public enum MemoryProtocol {
    public static let openTag = "<neko-memory>"
    public static let closeTag = "</neko-memory>"
    public static let maxProposalsPerReply = 3
    public static let maxEntryCharacters = 200

    public struct Extraction: Equatable, Sendable {
        public let text: String
        public let proposals: [MemoryProposal]
        public let rejectedCount: Int
    }

    public static func extract(from reply: String) -> Extraction {
        var text = ""
        var proposals: [MemoryProposal] = []
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
               let proposal = validated(from: object),
               proposals.count < maxProposalsPerReply,
               !proposals.contains(proposal) {
                proposals.append(proposal)
            } else {
                rejected += 1
            }
            rest = afterOpen[close.upperBound...]
        }
        text += rest
        let collapsed = text
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Extraction(text: collapsed, proposals: proposals, rejectedCount: rejected)
    }

    /// Hides memory markup from a partially streamed reply.
    public static func stripPartial(_ partial: String) -> String {
        var result = extract(from: partial).text
        for length in stride(from: openTag.count - 1, through: 1, by: -1) {
            if result.hasSuffix(String(openTag.prefix(length))) {
                result = String(result.dropLast(length)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return result
    }

    public static func validated(from object: [String: Any]) -> MemoryProposal? {
        guard
            let raw = (object["file"] as? String)?.lowercased(),
            let file = MemoryFile(rawValue: raw),
            file.catCanWrite,
            let add = object["add"] as? String
        else {
            return nil
        }
        let text = MemoryDocument.singleLine(add)
        guard
            !text.isEmpty,
            text.count <= maxEntryCharacters,
            !MemoryGuard.looksSensitive(text)
        else {
            return nil
        }
        return MemoryProposal(file: file, text: text)
    }

    public static func instructions(languageCode: String?) -> String {
        let rules = """
        <neko-memory>{"file":"user","add":"..."}</neko-memory>
        <neko-memory>{"file":"memory","add":"..."}</neko-memory>
        """
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            return "Memory: when the user shares something worth keeping, add a block after your reply. Use \"user\" for lasting facts (work, family, tastes, habits) and \"memory\" for current context (ongoing tasks, plans, promises). One short line each, at most 3, rarely, and never something already in memory. Never store passwords, keys, card or ID numbers. The user approves \"user\" entries, so don't say it's saved.\n\(rules)"
        case "ja":
            return "記憶: ユーザーが覚えておく価値のあることを話したら、返事の後にブロックを付ける。長く続く事実(仕事、家族、好み、習慣)は\"user\"、今の文脈(進行中のこと、予定、約束)は\"memory\"。それぞれ短い1行、最大3つ、たまにだけ。すでに記憶にあることは書かない。パスワード、キー、カード番号や身分証番号は絶対に書かない。\"user\"はユーザーが承認するので、保存したとは言わない。\n\(rules)"
        case "zh":
            return "记忆：当用户说了值得记住的事，在回复后附上一个块。长期事实（工作、家人、喜好、习惯）用\"user\"，当前情况（进行中的事、计划、约定）用\"memory\"。每条一行、最多3条、偶尔才用，已在记忆里的不要再写。绝不记录密码、密钥、卡号或证件号。\"user\"需要用户批准，所以不要说已经保存。\n\(rules)"
        default:
            return "기억: 사용자가 기억해둘 만한 걸 말하면 답 뒤에 블록을 붙여라. 오래 가는 사실(일, 가족, 취향, 습관)은 \"user\", 요즘 맥락(진행 중인 일, 계획, 약속)은 \"memory\". 각각 짧은 한 줄, 최대 3개, 가끔만. 이미 기억에 있는 건 쓰지 마라. 비밀번호, 키, 카드번호, 주민번호는 절대 쓰지 마라. \"user\"는 사용자가 승인하니 저장했다고 말하지 마라.\n\(rules)"
        }
    }
}

/// Rejects entries that look like secrets before they reach a file.
public enum MemoryGuard {
    private static let patterns: [String] = [
        #"(?i)\b(sk|pk|rk)-[A-Za-z0-9_-]{16,}"#,
        #"\bAKIA[0-9A-Z]{16}\b"#,
        #"\bgh[pousr]_[A-Za-z0-9]{20,}"#,
        #"\bxox[abprs]-[A-Za-z0-9-]{10,}"#,
        #"\bAIza[0-9A-Za-z_-]{20,}"#,
        #"(?i)(password|passwd|passcode|api[ _-]?key|secret|access[ _-]?token|private[ _-]?key|비밀번호|비번|패스워드|パスワード|暗証番号|密码|口令)"#,
        #"\b\d{6}-?[1-4]\d{6}\b"#,
    ]

    public static func looksSensitive(_ text: String) -> Bool {
        for pattern in patterns where text.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
        // Card-like digit runs, allowing spaces or dashes between groups.
        let compact = text.replacingOccurrences(of: #"(?<=\d)[ -](?=\d)"#, with: "", options: .regularExpression)
        if compact.range(of: #"\d{13,19}"#, options: .regularExpression) != nil {
            return true
        }
        // Long opaque tokens that mix letters and digits.
        for token in text.split(whereSeparator: { $0.isWhitespace }) where token.count >= 32 {
            let word = String(token)
            if word.range(of: #"^[A-Za-z0-9+/=_.-]+$"#, options: .regularExpression) != nil,
               word.rangeOfCharacter(from: .decimalDigits) != nil,
               word.rangeOfCharacter(from: .letters) != nil {
                return true
            }
        }
        return false
    }
}
