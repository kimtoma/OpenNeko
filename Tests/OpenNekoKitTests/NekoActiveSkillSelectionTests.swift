import XCTest
@testable import OpenNekoKit

final class NekoActiveSkillSelectionTests: XCTestCase {
    func testActivatingFirstSkillDoesNotRequireHistoryReset() {
        var selection = NekoActiveSkillSelection()

        let shouldReset = selection.activate(makeSkill(id: "explain"))

        XCTAssertFalse(shouldReset)
        XCTAssertEqual(selection.id, "explain")
    }

    func testSwitchingActiveSkillRequiresHistoryReset() {
        var selection = NekoActiveSkillSelection()
        _ = selection.activate(makeSkill(id: "explain"))

        let shouldReset = selection.activate(makeSkill(id: "translate"))

        XCTAssertTrue(shouldReset)
        XCTAssertEqual(selection.id, "translate")
    }

    func testReactivatingSameSkillKeepsHistory() {
        var selection = NekoActiveSkillSelection()
        _ = selection.activate(makeSkill(id: "explain"))

        let shouldReset = selection.activate(makeSkill(id: "explain"))

        XCTAssertFalse(shouldReset)
    }

    func testDisabledOrMissingSkillClearsSelection() {
        var disabled = NekoActiveSkillSelection(id: "translate")
        let catalog = NekoSkillCatalog(skills: [makeSkill(id: "translate")])

        disabled.reconcile(catalog: catalog, disabledIDs: ["translate"])

        XCTAssertNil(disabled.id)

        var missing = NekoActiveSkillSelection(id: "explain")
        missing.reconcile(catalog: catalog, disabledIDs: [])

        XCTAssertNil(missing.id)
    }

    func testResolveReturnsCurrentCatalogSkill() {
        var selection = NekoActiveSkillSelection(id: "explain")
        let skill = makeSkill(id: "explain", name: "Updated")
        let catalog = NekoSkillCatalog(skills: [skill])

        XCTAssertEqual(selection.resolve(catalog: catalog, disabledIDs: []), skill)
    }

    private func makeSkill(id: String, name: String = "Skill") -> NekoSkill {
        NekoSkill(
            id: id,
            name: name,
            description: "Description",
            input: .prompt,
            body: "Body",
            source: .bundled
        )
    }
}
