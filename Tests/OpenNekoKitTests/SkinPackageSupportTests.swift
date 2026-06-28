import XCTest
@testable import OpenNekoKit

final class SkinPackageSupportTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-skin-package-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testSanitizedSkinIDIsFilesystemFriendly() {
        XCTAssertEqual(SkinPackageSupport.sanitizedSkinID(from: "Nabi Cat 02!"), "nabi-cat-02")
        XCTAssertEqual(SkinPackageSupport.sanitizedSkinID(from: "나비"), "my-cat")
        XCTAssertEqual(SkinPackageSupport.sanitizedSkinID(from: "  Calico___Kitten  "), "calico-kitten")
    }

    func testChatGPTPromptIncludesPhotosAndExactFrameNames() throws {
        let manifest = try SpriteManifest(data: #"{"idle":["idle_0.png"],"walk":["walk_0.png","walk_1.png"]}"#.data(using: .utf8)!)
        let recipe = SkinPackageSupport.recipe(
            skinID: "nabi",
            displayName: "Nabi",
            catName: "Nabi",
            baseSkinID: "white",
            photoFilenames: ["photos/front.jpg", "photos/side.jpg"],
            rootManifest: manifest
        )

        let prompt = SkinPackageSupport.chatGPTPrompt(recipe: recipe, rootManifest: manifest)

        XCTAssertTrue(prompt.contains("transparent 128x128 PNG"))
        XCTAssertTrue(prompt.contains("idle_0.png"))
        XCTAssertTrue(prompt.contains("walk_1.png"))
        XCTAssertTrue(prompt.contains("photos/front.jpg"))
        XCTAssertTrue(prompt.contains("Nabi"))
    }

    func testValidateSkinPackageAcceptsCompletePackage() throws {
        let manifest = try writePackage(
            id: "nabi",
            displayName: "Nabi",
            frames: ["idle_0.png", "walk_0.png"],
            missingFrames: []
        )

        let validation = try SkinPackageSupport.validateSkinPackage(
            at: tmp,
            fallbackSkinID: nil,
            rootManifest: manifest
        )

        XCTAssertTrue(validation.isReady)
        XCTAssertEqual(validation.skinID, "nabi")
        XCTAssertEqual(validation.displayName, "Nabi")
        XCTAssertEqual(validation.frameCount, 2)
    }

    func testValidateSkinPackageRejectsMissingFrames() throws {
        let manifest = try writePackage(
            id: "nabi",
            displayName: "Nabi",
            frames: ["idle_0.png", "walk_0.png"],
            missingFrames: ["walk_0.png"]
        )

        XCTAssertThrowsError(
            try SkinPackageSupport.validateSkinPackage(
                at: tmp,
                fallbackSkinID: nil,
                rootManifest: manifest
            )
        ) { error in
            XCTAssertEqual(error as? SkinPackageError, .missingRequiredFrames(["walk_0.png"]))
        }
    }

    private func writePackage(
        id: String,
        displayName: String,
        frames: [String],
        missingFrames: Set<String>
    ) throws -> SpriteManifest {
        let manifestJSON = #"{"idle":["idle_0.png"],"walk":["walk_0.png"]}"#
        try manifestJSON.data(using: .utf8)!.write(to: tmp.appendingPathComponent("manifest.json"))

        let metadata = CustomSkinMetadata(id: id, displayName: displayName, catName: displayName, source: "test")
        let encoder = JSONEncoder()
        try encoder.encode(metadata).write(to: tmp.appendingPathComponent(SkinPackageSupport.metadataFilename))

        for frame in frames where !missingFrames.contains(frame) {
            try Data([0]).write(to: tmp.appendingPathComponent(frame))
        }

        return try SpriteManifest(data: manifestJSON.data(using: .utf8)!)
    }
}
