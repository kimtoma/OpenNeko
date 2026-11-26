import Foundation

/// Notices when a plain chat message is really a job for one of the
/// person's skills ("이거 번역해줘" → the translate skill) so the cat can
/// offer it once. Model-free and conservative: the message has to contain
/// the skill name's keywords, not just share a topic.
public enum SkillSuggestion {
    public static let minimumMessageCharacters = 4

    public static func suggest(
        message: String,
        skills: [NekoSkill],
        disabledIDs: Set<String>,
        alreadySuggested: Set<String>
    ) -> NekoSkill? {
        let text = message.lowercased()
        guard text.count >= minimumMessageCharacters, !text.hasPrefix("/") else { return nil }
        var best: (skill: NekoSkill, matched: Int)?
        for skill in skills where !disabledIDs.contains(skill.id) && !alreadySuggested.contains(skill.id) {
            let keys = ConversationRecall.keywords(in: skill.name)
            guard !keys.isEmpty else { continue }
            let matched = keys.filter { text.contains($0) }.count
            guard matched >= required(keys.count) else { continue }
            if best == nil || matched > best!.matched {
                best = (skill, matched)
            }
        }
        return best?.skill
    }

    /// One keyword names need it; two-keyword names need both; longer names
    /// may miss one ("유튜브 요약" still finds "유튜브 링크 요약").
    static func required(_ count: Int) -> Int {
        count <= 2 ? count : count - 1
    }

    /// Connectors a skill uses that are not ready right now.
    public static func missingConnectors(for skill: NekoSkill, ready: Set<String>) -> [String] {
        skill.uses.filter { !ready.contains($0) }
    }

    /// Connector tools with the active skill's servers first.
    public static func prioritized(_ tools: [MCPTool], for skill: NekoSkill?) -> [MCPTool] {
        guard let uses = skill?.uses, !uses.isEmpty else { return tools }
        let preferred = tools.filter { uses.contains($0.server) }
        return preferred + tools.filter { !uses.contains($0.server) }
    }
}

/// en/ko/ja/zh copy for skill suggestions.
public enum SkillSuggestionCopy {
    public static func offer(_ skill: NekoSkill, languageCode: String?) -> String {
        pick(
            languageCode,
            ko: "✨ '\(skill.name)' 스킬로 해볼까냥? 눌러서 실행",
            en: "✨ Try the '\(skill.name)' skill for this? Click to run",
            ja: "✨ 「\(skill.name)」スキルでやってみるにゃ？クリックで実行",
            zh: "✨ 用“\(skill.name)”技能试试吗？点击运行"
        )
    }

    public static func needsConnectors(_ names: [String], languageCode: String?) -> String {
        let list = names.joined(separator: ", ")
        return pick(
            languageCode,
            ko: "이 스킬은 \(list) 커넥터가 있으면 더 잘한다냥 (설정 > 커넥터)",
            en: "This skill works best with the \(list) connector (Settings > Connectors)",
            ja: "このスキルは\(list)コネクタがあるともっと上手にできるにゃ（設定 > コネクタ）",
            zh: "这个技能配合 \(list) 连接器效果更好（设置 > 连接器）"
        )
    }

    private static func pick(_ languageCode: String?, ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
