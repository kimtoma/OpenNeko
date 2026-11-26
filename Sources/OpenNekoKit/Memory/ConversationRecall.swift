import Foundation

/// One earlier exchange that looks related to the current message.
public struct RecallSnippet: Equatable, Sendable {
    public let user: String
    public let assistant: String?
    public let score: Int

    public init(user: String, assistant: String?, score: Int) {
        self.user = user
        self.assistant = assistant
        self.score = score
    }
}

/// Finds earlier exchanges in the local chat transcript that share keywords
/// with the new message, so "the golf course I mentioned" can resolve.
/// Local-only and model-free: plain keyword overlap, with Korean particles
/// trimmed and CJK text split into bigrams. Kept behind one function so a
/// local embedding search can replace it later.
public enum ConversationRecall {
    public static let maxSnippets = 3
    public static let snippetCharacters = 160

    public static func search(
        query: String,
        transcript: [ChatMessage],
        excludingRecent recentCount: Int = ChatPromptBuilder.maxTurns
    ) -> [RecallSnippet] {
        let keywords = Set(self.keywords(in: query))
        guard !keywords.isEmpty else { return [] }
        let searchable = transcript.dropLast(max(0, recentCount))
        guard !searchable.isEmpty else { return [] }

        var scored: [(index: Int, snippet: RecallSnippet)] = []
        let messages = Array(searchable)
        for (index, message) in messages.enumerated() where message.role == .user {
            let reply = messages.indices.contains(index + 1) && messages[index + 1].role == .assistant
                ? messages[index + 1].text
                : nil
            let haystack = (message.text + "\n" + (reply ?? "")).lowercased()
            let score = keywords.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
            guard score > 0 else { continue }
            scored.append((index, RecallSnippet(
                user: clipped(message.text),
                assistant: reply.map(clipped),
                score: score
            )))
        }

        return scored
            .sorted { lhs, rhs in
                lhs.snippet.score != rhs.snippet.score
                    ? lhs.snippet.score > rhs.snippet.score
                    : lhs.index > rhs.index
            }
            .prefix(maxSnippets)
            .sorted { $0.index < $1.index }
            .map(\.snippet)
    }

    public static func keywords(in text: String) -> [String] {
        var result: [String] = []
        let tokens = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for token in tokens {
            if token.unicodeScalars.contains(where: isHanOrKana) {
                result.append(contentsOf: bigrams(token))
                continue
            }
            let stem = isHangul(token) ? trimmingParticle(token) : token
            guard stem.count >= 2, !stopwords.contains(stem), !stopwords.contains(token) else { continue }
            result.append(stem)
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    static func clipped(_ text: String) -> String {
        let line = MemoryDocument.singleLine(text)
        guard line.count > snippetCharacters else { return line }
        return String(line.prefix(snippetCharacters)) + "…"
    }

    static func trimmingParticle(_ token: String) -> String {
        guard token.count >= 3 else { return token }
        for particle in particles where token.hasSuffix(particle) {
            let stem = String(token.dropLast(particle.count))
            if stem.count >= 2 { return stem }
        }
        return token
    }

    static func bigrams(_ token: String) -> [String] {
        let chars = Array(token)
        guard chars.count >= 2 else { return [] }
        return (0..<(chars.count - 1)).map { String(chars[$0...($0 + 1)]) }
    }

    static func isHangul(_ token: String) -> Bool {
        token.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }

    static func isHanOrKana(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x4E00...0x9FFF, 0x3400...0x4DBF: true
        default: false
        }
    }

    /// Longest first so "에서" wins over "서".
    static let particles: [String] = [
        "에서는", "으로는", "이라고", "에서", "으로", "에게", "한테", "까지", "부터", "보다", "처럼", "이랑", "이야", "이었", "였지",
        "은", "는", "이", "가", "을", "를", "에", "의", "도", "로", "와", "과", "랑", "야", "요",
    ]

    static let stopwords: Set<String> = [
        // ko
        "오늘", "내일", "어제", "지금", "그거", "이거", "저거", "뭐야", "뭐지", "그냥", "진짜", "정말", "너무", "우리",
        "그리고", "근데", "그래", "있어", "없어", "해줘", "알려줘", "어떻게", "무엇", "무슨", "이번", "저번", "그때",
        "하는", "했어", "했던", "말한", "말했던", "기억", "기억해", "기억나", "어디", "언제", "누구", "좋아", "그럼",
        "아까", "혹시", "있잖아", "생각", "같아", "같은", "이제", "다시", "어때",
        // en
        "the", "and", "but", "are", "was", "were", "does", "did", "you", "your", "this", "that", "what", "how", "why",
        "when", "where", "about", "please", "can", "could", "would", "tell", "remember", "said", "told", "with", "for",
        "me", "my", "it", "is", "to", "of", "in", "on", "do", "an", "or", "we", "us", "be", "so", "if", "at",
    ]
}
