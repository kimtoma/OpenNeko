import XCTest
@testable import OpenNekoKit

final class LocalModelCatalogTests: XCTestCase {
    static var bundledCatalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Resources/local-models.json")
    }

    static func bundledCatalog() throws -> LocalModelCatalog {
        try LocalModelCatalog.decode(from: Data(contentsOf: bundledCatalogURL))
    }

    func testBundledCatalogDecodesAndIsConsistent() throws {
        let catalog = try Self.bundledCatalog()
        XCTAssertEqual(catalog.version, 1)
        XCTAssertFalse(catalog.models.isEmpty)
        XCTAssertFalse(catalog.tiers.isEmpty)
        XCTAssertEqual(catalog.danglingModelIDs, [])
        XCTAssertEqual(Set(catalog.models.map(\.id)).count, catalog.models.count, "model ids must be unique")
        XCTAssertTrue(catalog.models.allSatisfy { $0.downloadGB > 0 })
    }

    func testBundledCatalogDefaultsToKoreanTestedModelOn16GB() throws {
        let catalog = try Self.bundledCatalog()
        let tier = try XCTUnwrap(catalog.tier(forMemoryGB: 16))
        XCTAssertEqual(tier.primary, "gemma4:e2b")
        XCTAssertEqual(catalog.model(id: tier.primary)?.koreanTested, true)
    }

    func testTierPicksHighestFloorThatFits() {
        let catalog = LocalModelCatalog(
            version: 1,
            updated: "2026-11-26",
            models: [],
            tiers: [
                LocalModelTier(minMemoryGB: 16, primary: "b"),
                LocalModelTier(minMemoryGB: 8, primary: "a"),
                LocalModelTier(minMemoryGB: 32, primary: "c"),
            ]
        )
        XCTAssertNil(catalog.tier(forMemoryGB: 4))
        XCTAssertEqual(catalog.tier(forMemoryGB: 8)?.primary, "a")
        XCTAssertEqual(catalog.tier(forMemoryGB: 24)?.primary, "b")
        XCTAssertEqual(catalog.tier(forMemoryGB: 128)?.primary, "c")
    }

    func testDanglingModelIDsReportsMissingReferencesOnce() {
        let catalog = LocalModelCatalog(
            version: 1,
            updated: "",
            models: [LocalModelEntry(id: "a", displayName: "A", downloadGB: 1, supportsTools: true, koreanTested: false)],
            tiers: [
                LocalModelTier(minMemoryGB: 8, primary: "a", smarter: "x"),
                LocalModelTier(minMemoryGB: 16, primary: "x", lighter: "a"),
            ]
        )
        XCTAssertEqual(catalog.danglingModelIDs, ["x"])
    }
}
