import XCTest
@testable import OpenNekoKit

final class SkinManagerTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("neko-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeManifest(_ dir: URL, _ json: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.data(using: .utf8)!.write(to: dir.appendingPathComponent("manifest.json"))
    }

    func testLoadDefaultUsesRootManifest() throws {
        try writeManifest(tmp, #"{ "idle": ["idle_0.png"] }"#)
        let mgr = SkinManager(bundledRoot: tmp, externalRoot: nil)
        let skin = mgr.loadDefault()
        XCTAssertEqual(skin.id, "default")
        XCTAssertEqual(skin.frameURLs(for: "idle").map { $0.lastPathComponent }, ["idle_0.png"])
        XCTAssertEqual(skin.frameURLs(for: "idle").first?.deletingLastPathComponent().path, tmp.path)
    }

    func testAvailableSkinIDsIncludesSubfolders() throws {
        try writeManifest(tmp, #"{ "idle": ["idle_0.png"] }"#)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("black"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("calico"), withIntermediateDirectories: true)
        let mgr = SkinManager(bundledRoot: tmp, externalRoot: nil)
        XCTAssertEqual(mgr.availableSkinIDs(), ["default", "black", "calico"].sorted())
    }

    func testSubfolderWithoutManifestSharesRoot() throws {
        try writeManifest(tmp, #"{ "idle": ["idle_0.png"] }"#)
        let black = tmp.appendingPathComponent("black")
        try FileManager.default.createDirectory(at: black, withIntermediateDirectories: true)
        let mgr = SkinManager(bundledRoot: tmp, externalRoot: nil)
        let skin = try mgr.loadSkin(id: "black")
        // 프레임 파일은 black 폴더에서 찾고, manifest 구조는 루트 것을 공유
        XCTAssertEqual(skin.frameURLs(for: "idle").first?.lastPathComponent, "idle_0.png")
        XCTAssertEqual(skin.frameURLs(for: "idle").first?.deletingLastPathComponent().lastPathComponent, "black")
    }

    func testLoadUnknownSkinThrows() throws {
        try writeManifest(tmp, #"{ "idle": ["idle_0.png"] }"#)
        let mgr = SkinManager(bundledRoot: tmp, externalRoot: nil)
        XCTAssertThrowsError(try mgr.loadSkin(id: "ghost"))
    }

    func testLoadDefaultFallsBackWhenManifestBroken() throws {
        // manifest.json 없음 → loadDefault는 throw하지 않고 빈 스킨 반환
        let mgr = SkinManager(bundledRoot: tmp, externalRoot: nil)
        let skin = mgr.loadDefault()
        XCTAssertEqual(skin.id, "default")
        XCTAssertEqual(skin.frameURLs(for: "idle"), [])
    }
}
