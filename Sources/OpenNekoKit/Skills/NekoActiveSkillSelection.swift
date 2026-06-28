import Foundation

public struct NekoActiveSkillSelection: Equatable, Sendable {
    public private(set) var id: String?

    public init(id: String? = nil) {
        self.id = id
    }

    @discardableResult
    public mutating func activate(_ skill: NekoSkill) -> Bool {
        let shouldResetHistory = id != nil && id != skill.id
        id = skill.id
        return shouldResetHistory
    }

    public mutating func clear() {
        id = nil
    }

    public mutating func clearIfMatches(_ skillID: String) {
        if id == skillID {
            id = nil
        }
    }

    public mutating func reconcile(catalog: NekoSkillCatalog, disabledIDs: Set<String>) {
        guard let id else { return }
        if disabledIDs.contains(id) || catalog.skill(id: id) == nil {
            self.id = nil
        }
    }

    public mutating func resolve(catalog: NekoSkillCatalog, disabledIDs: Set<String>) -> NekoSkill? {
        reconcile(catalog: catalog, disabledIDs: disabledIDs)
        guard let id else { return nil }
        return catalog.skill(id: id)
    }
}
