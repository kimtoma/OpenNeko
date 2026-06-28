import Foundation

public enum NekoSkillManifestError: Error, Equatable {
    case missingFrontMatter
    case missingName
    case missingBody
}

public enum NekoSkillManifestParser {
    public static func parse(
        id: String,
        source: NekoSkillSource,
        text: String
    ) throws -> NekoSkill {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n---")
        guard normalized.hasPrefix("---\n"), parts.count >= 2 else {
            throw NekoSkillManifestError.missingFrontMatter
        }

        let frontMatter = String(parts[0].dropFirst(4))
        let body = parts.dropFirst().joined(separator: "\n---")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            throw NekoSkillManifestError.missingBody
        }

        let fields = parseFrontMatter(frontMatter)
        guard let name = fields["name"], !name.isEmpty else {
            throw NekoSkillManifestError.missingName
        }

        return NekoSkill(
            id: id,
            name: name,
            description: fields["description"] ?? "",
            input: NekoSkillInput(rawValue: fields["input"] ?? "") ?? .prompt,
            body: body,
            source: source
        )
    }

    private static func parseFrontMatter(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let pair = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                fields[key] = value
            }
        }
        return fields
    }
}

