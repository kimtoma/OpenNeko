import XCTest
@testable import OpenNekoKit

final class NekoSkillCatalogTests: XCTestCase {
    func testDiscoverMergesBundledAndUserSkillsByID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-skill-catalog-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bundled = root.appendingPathComponent("bundled", isDirectory: true)
        let user = root.appendingPathComponent("user", isDirectory: true)
        try writeSkill(root: bundled, id: "translate", name: "번들 번역", input: "clipboard")
        try writeSkill(root: user, id: "translate", name: "사용자 번역", input: "prompt")
        try writeSkill(root: user, id: "explain", name: "설명", input: "prompt")

        let catalog = NekoSkillCatalog.discover(bundledRoot: bundled, userRoot: user)

        XCTAssertEqual(catalog.skills.count, 2)
        XCTAssertEqual(catalog.skill(id: "translate")?.name, "사용자 번역")
        XCTAssertEqual(catalog.skill(id: "translate")?.source, .user)
        XCTAssertEqual(catalog.enabled(disabledIDs: ["translate"]).map(\.id), ["explain"])
    }

    private func writeSkill(root: URL, id: String, name: String, input: String) throws {
        let directory = root.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let text = """
        ---
        name: \(name)
        description: \(name) 설명
        input: \(input)
        ---
        \(name) 본문
        """
        try text.write(to: directory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }
}

