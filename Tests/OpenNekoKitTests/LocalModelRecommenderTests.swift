import XCTest
@testable import OpenNekoKit

final class LocalModelRecommenderTests: XCTestCase {
    private let gb = HardwareProfile.bytesPerGB

    private let catalog = LocalModelCatalog(
        version: 1,
        updated: "2026-11-26",
        models: [
            LocalModelEntry(id: "small", displayName: "Small", downloadGB: 2.5, supportsTools: true, koreanTested: false),
            LocalModelEntry(id: "mid", displayName: "Mid", downloadGB: 7.5, supportsTools: true, koreanTested: true),
            LocalModelEntry(id: "big", displayName: "Big", downloadGB: 9.5, supportsTools: true, koreanTested: true),
        ],
        tiers: [
            LocalModelTier(minMemoryGB: 8, primary: "small", smarter: "mid"),
            LocalModelTier(minMemoryGB: 16, primary: "mid", lighter: "small", smarter: "big"),
        ]
    )

    private func hardware(memoryGB: Double, diskGB: Double, appleSilicon: Bool = true) -> HardwareProfile {
        HardwareProfile(
            memoryBytes: UInt64(memoryGB * Double(gb)),
            isAppleSilicon: appleSilicon,
            freeDiskBytes: UInt64(diskGB * Double(gb))
        )
    }

    func testMemoryGBRoundsToNearestGB() {
        XCTAssertEqual(hardware(memoryGB: 15.8, diskGB: 0).memoryGB, 16)
        XCTAssertEqual(hardware(memoryGB: 8, diskGB: 0).memoryGB, 8)
    }

    func testRecommendsTierWithAlternatives() {
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 16, diskGB: 100))
        guard case let .recommended(primary, lighter, smarter) = result else {
            return XCTFail("expected recommendation, got \(result)")
        }
        XCTAssertEqual(primary.id, "mid")
        XCTAssertEqual(lighter?.id, "small")
        XCTAssertEqual(smarter?.id, "big")
        XCTAssertEqual(result.choices.map(\.id), ["small", "mid", "big"])
    }

    func testIntelMacIsUnsupported() {
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 32, diskGB: 100, appleSilicon: false))
        XCTAssertEqual(result, .unsupported(.notAppleSilicon))
        XCTAssertEqual(result.choices, [])
    }

    func testTooLittleMemoryReportsSmallestTier() {
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 4, diskGB: 100))
        XCTAssertEqual(result, .unsupported(.notEnoughMemory(minimumGB: 8)))
    }

    func testDropsAlternativesThatDoNotFitOnDisk() {
        // 10 GB free: mid (7.5 + 2 headroom) fits, big (9.5 + 2) does not.
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 16, diskGB: 10))
        guard case let .recommended(primary, lighter, smarter) = result else {
            return XCTFail("expected recommendation, got \(result)")
        }
        XCTAssertEqual(primary.id, "mid")
        XCTAssertEqual(lighter?.id, "small")
        XCTAssertNil(smarter)
    }

    func testFallsBackToLighterModelWhenPrimaryDoesNotFit() {
        // 5 GB free: only small (2.5 + 2) fits.
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 16, diskGB: 5))
        XCTAssertEqual(result, .recommended(primary: catalog.model(id: "small")!, lighter: nil, smarter: nil))
    }

    func testReportsDiskNeededWhenNothingFits() {
        let result = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware(memoryGB: 16, diskGB: 3))
        XCTAssertEqual(result, .unsupported(.notEnoughDisk(neededGB: 4.5)))
    }
}
