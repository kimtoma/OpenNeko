import XCTest
@testable import OpenNekoKit

final class LocalModelSetupCopyTests: XCTestCase {
    func testEveryKeyIsTranslatedInEveryLanguage() {
        for key in LocalModelSetupCopyKey.allCases {
            let texts = ["ko", "en", "ja", "zh"].map { LocalModelSetupCopy.text(key, languageCode: $0) }
            XCTAssertTrue(texts.allSatisfy { !$0.isEmpty }, "\(key) has an empty translation")
            XCTAssertEqual(Set(texts).count, 4, "\(key) should differ per language")
        }
    }

    func testDefaultsToKorean() {
        XCTAssertEqual(LocalModelSetupCopy.text(.entryTitle, languageCode: nil), "로컬 모델 설치")
        XCTAssertEqual(LocalModelSetupCopy.text(.entryTitle, languageCode: "en-US"), "Local model setup")
    }

    func testFormattedStrings() {
        let hardware = HardwareProfile(
            memoryBytes: 16 * HardwareProfile.bytesPerGB,
            isAppleSilicon: true,
            freeDiskBytes: 2_900_000_000
        )
        XCTAssertEqual(LocalModelSetupCopy.hardwareSummary(hardware, languageCode: "en"), "16 GB memory · 2 GB free")
        let model = LocalModelEntry(id: "m", displayName: "M", downloadGB: 7.5, supportsTools: true, koreanTested: true)
        XCTAssertEqual(LocalModelSetupCopy.downloadSize(model, languageCode: "ko"), "7.5GB 다운로드")
        XCTAssertEqual(LocalModelSetupCopy.unsupported(.notEnoughMemory(minimumGB: 8), languageCode: "en"), "Needs at least 8 GB of memory")
        XCTAssertEqual(LocalModelSetupCopy.unsupported(.notEnoughDisk(neededGB: 4.5), languageCode: "en"), "Needs at least 5 GB of free space")
        XCTAssertEqual(LocalModelSetupCopy.unsupported(.notAppleSilicon, languageCode: "ja"), "Apple Silicon搭載Macのみ対応です")
    }
}
