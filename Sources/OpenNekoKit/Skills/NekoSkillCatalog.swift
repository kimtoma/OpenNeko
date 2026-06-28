import Foundation

public struct NekoSkillCatalog: Equatable, Sendable {
    public let skills: [NekoSkill]

    public init(skills: [NekoSkill]) {
        self.skills = skills.sorted { lhs, rhs in
            if lhs.source != rhs.source {
                return lhs.source == .bundled
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public static func discover(
        bundledRoot: URL?,
        userRoot: URL?,
        fileManager: FileManager = .default
    ) -> NekoSkillCatalog {
        var byID: [String: NekoSkill] = [:]

        for skill in discover(root: bundledRoot, source: .bundled, fileManager: fileManager) {
            byID[skill.id] = skill
        }
        for skill in discover(root: userRoot, source: .user, fileManager: fileManager) {
            byID[skill.id] = skill
        }

        return NekoSkillCatalog(skills: Array(byID.values))
    }

    public func enabled(disabledIDs: Set<String>) -> [NekoSkill] {
        skills.filter { !disabledIDs.contains($0.id) }
    }

    public func skill(id: String) -> NekoSkill? {
        skills.first { $0.id == id }
    }

    private static func discover(
        root: URL?,
        source: NekoSkillSource,
        fileManager: FileManager
    ) -> [NekoSkill] {
        guard let root else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.compactMap { directory in
            let values = try? directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            let manifest = directory.appendingPathComponent("SKILL.md", isDirectory: false)
            guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
            return try? NekoSkillManifestParser.parse(
                id: directory.lastPathComponent,
                source: source,
                text: text
            )
        }
    }
}

