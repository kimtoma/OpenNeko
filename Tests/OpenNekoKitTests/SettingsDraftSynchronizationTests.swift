import XCTest
@testable import OpenNekoKit

final class SettingsDraftSynchronizationTests: XCTestCase {
    func testKeepsMatchingDraft() {
        let draft = SettingsDraftSynchronization.reconciledDraft("Mochi", storedValue: "Mochi")

        XCTAssertEqual(draft, "Mochi")
    }

    func testClearsStaleDraftWhenStoredValueChanges() {
        let draft = SettingsDraftSynchronization.reconciledDraft("Mochi", storedValue: "Nabi")

        XCTAssertNil(draft)
    }

    func testClearsStaleProfileDraftWhenStoredProfileChanges() {
        let draft = UserProfile(name: "Mochi", birthDate: "2024-01-01")
        let stored = UserProfile(name: "Nabi", birthDate: "2024-01-01")

        XCTAssertNil(SettingsDraftSynchronization.reconciledDraft(draft, storedValue: stored))
    }

    func testNilDraftRemainsNil() {
        let draft: String? = nil

        XCTAssertNil(SettingsDraftSynchronization.reconciledDraft(draft, storedValue: "Mochi"))
    }
}
