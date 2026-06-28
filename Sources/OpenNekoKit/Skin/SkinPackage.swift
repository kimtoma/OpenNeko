import Foundation

public struct CustomSkinMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let catName: String
    public let createdWith: String
    public let source: String
    public let notes: String

    public init(
        schemaVersion: Int = 1,
        id: String,
        displayName: String,
        catName: String,
        createdWith: String = "openNeko",
        source: String,
        notes: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.catName = catName
        self.createdWith = createdWith
        self.source = source
        self.notes = notes
    }
}

public struct SkinGenerationRecipe: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let skinID: String
    public let displayName: String
    public let baseSkinID: String
    public let catName: String
    public let photoFilenames: [String]
    public let requiredStates: [String]
    public let framesPerState: Int
    public let canvasSize: Int
    public let sourceMethod: String
    public let paidServiceNote: String

    public init(
        schemaVersion: Int = 1,
        skinID: String,
        displayName: String,
        baseSkinID: String,
        catName: String,
        photoFilenames: [String],
        requiredStates: [String],
        framesPerState: Int,
        canvasSize: Int = 128,
        sourceMethod: String = "ChatGPT image generation",
        paidServiceNote: String = "Send this request package to the openNeko creator if you want a finished .openneko-skin file made for you."
    ) {
        self.schemaVersion = schemaVersion
        self.skinID = skinID
        self.displayName = displayName
        self.baseSkinID = baseSkinID
        self.catName = catName
        self.photoFilenames = photoFilenames
        self.requiredStates = requiredStates
        self.framesPerState = framesPerState
        self.canvasSize = canvasSize
        self.sourceMethod = sourceMethod
        self.paidServiceNote = paidServiceNote
    }
}

public struct SkinPackageValidation: Equatable, Sendable {
    public let skinID: String
    public let displayName: String
    public let frameCount: Int
    public let hasManifest: Bool
    public let missingFrames: [String]

    public var isReady: Bool {
        hasManifest && missingFrames.isEmpty
    }

    public init(
        skinID: String,
        displayName: String,
        frameCount: Int,
        hasManifest: Bool,
        missingFrames: [String]
    ) {
        self.skinID = skinID
        self.displayName = displayName
        self.frameCount = frameCount
        self.hasManifest = hasManifest
        self.missingFrames = missingFrames
    }
}

public enum SkinPackageError: Error, Equatable {
    case invalidSkinID
    case metadataMissing
    case manifestMissing
    case noFrames
    case missingRequiredFrames([String])
}

public enum SkinPackageSupport {
    public static let skinPackageExtension = "openneko-skin"
    public static let skinRequestExtension = "openneko-skin-request"
    public static let metadataFilename = "openneko-skin.json"
    public static let recipeFilename = "openneko-skin-recipe.json"
    public static let promptFilename = "chatgpt-prompt.md"
    public static let photosDirectoryName = "photos"

    public static func sanitizedSkinID(from value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        var result = ""
        var didAppendDash = false

        for scalar in folded.unicodeScalars {
            let isASCIIAlphanumeric = (65...90).contains(Int(scalar.value))
                || (97...122).contains(Int(scalar.value))
                || (48...57).contains(Int(scalar.value))
            if isASCIIAlphanumeric {
                result.unicodeScalars.append(scalar)
                didAppendDash = false
            } else if !didAppendDash {
                result.append("-")
                didAppendDash = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "my-cat" : trimmed
    }

    public static func requiredFrameNames(from manifest: SpriteManifest) -> [String] {
        manifest.stateNames.flatMap { manifest.frames(for: $0) }
    }

    public static func recipe(
        skinID rawSkinID: String,
        displayName rawDisplayName: String,
        catName rawCatName: String,
        baseSkinID: String,
        photoFilenames: [String],
        rootManifest: SpriteManifest,
        canvasSize: Int = 128
    ) -> SkinGenerationRecipe {
        let skinID = sanitizedSkinID(from: rawSkinID)
        let catName = rawCatName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let states = rootManifest.stateNames
        let framesPerState = states
            .map { rootManifest.frames(for: $0).count }
            .max() ?? 0

        return SkinGenerationRecipe(
            skinID: skinID,
            displayName: displayName.isEmpty ? skinID : displayName,
            baseSkinID: baseSkinID,
            catName: catName.isEmpty ? "my cat" : catName,
            photoFilenames: photoFilenames,
            requiredStates: states,
            framesPerState: framesPerState,
            canvasSize: canvasSize
        )
    }

    public static func metadata(for recipe: SkinGenerationRecipe, source: String) -> CustomSkinMetadata {
        CustomSkinMetadata(
            id: recipe.skinID,
            displayName: recipe.displayName,
            catName: recipe.catName,
            source: source,
            notes: recipe.paidServiceNote
        )
    }

    public static func validateSkinPackage(
        at packageURL: URL,
        fallbackSkinID: String? = nil,
        rootManifest: SpriteManifest
    ) throws -> SkinPackageValidation {
        let metadata = try loadMetadata(at: packageURL)
        let skinID = sanitizedSkinID(from: metadata?.id ?? fallbackSkinID ?? packageURL.deletingPathExtension().lastPathComponent)
        guard !skinID.isEmpty else { throw SkinPackageError.invalidSkinID }

        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? SpriteManifest(data: data)
        else {
            throw SkinPackageError.manifestMissing
        }

        let expectedFrames = requiredFrameNames(from: manifest)
        guard !expectedFrames.isEmpty else { throw SkinPackageError.noFrames }

        let missing = expectedFrames.filter { name in
            !FileManager.default.fileExists(atPath: packageURL.appendingPathComponent(name).path)
        }
        if !missing.isEmpty {
            throw SkinPackageError.missingRequiredFrames(missing)
        }

        let rootRequired = Set(requiredFrameNames(from: rootManifest))
        let packageFrames = Set(expectedFrames)
        let missingRootFrames = rootRequired.subtracting(packageFrames).sorted()

        return SkinPackageValidation(
            skinID: skinID,
            displayName: metadata?.displayName ?? skinID,
            frameCount: expectedFrames.count,
            hasManifest: true,
            missingFrames: missingRootFrames
        )
    }

    public static func chatGPTPrompt(recipe: SkinGenerationRecipe, rootManifest: SpriteManifest) -> String {
        let frameList = rootManifest.stateNames
            .map { state in
                let files = rootManifest.frames(for: state).joined(separator: ", ")
                return "- \(state): \(files)"
            }
            .joined(separator: "\n")

        let photos = recipe.photoFilenames.isEmpty
            ? "No photo filenames were included."
            : recipe.photoFilenames.map { "- \($0)" }.joined(separator: "\n")

        return """
        # openNeko custom skin request

        Create a pixel-art macOS desktop cat skin for openNeko using the attached cat photos.

        Cat name: \(recipe.catName)
        Skin ID: \(recipe.skinID)
        Display name: \(recipe.displayName)
        Canvas: transparent \(recipe.canvasSize)x\(recipe.canvasSize) PNG per frame
        Style: cute pixel art, nearest-neighbor edges, no blur, no background, no shadow, no text, centered cat, consistent size across all frames

        Important likeness rules:
        - Preserve the real cat's coat color, face pattern, eye color, tail shape, and any distinctive marks.
        - Keep the silhouette readable at small desktop size.
        - Make all frames feel like the same cat, not different cats.
        - Export individual transparent PNG files using the exact filenames below.

        Required animation states and filenames:
        \(frameList)

        Photos included in this request:
        \(photos)

        Workflow:
        1. Use the photos as the visual reference.
        2. Generate the frames state by state if one image cannot include all frames cleanly.
        3. Keep every frame on a transparent canvas.
        4. Return the PNG files with the exact filenames from the list.
        5. Put the PNG files next to the provided manifest.json and openneko-skin.json, then compress that folder as \(recipe.skinID).openneko-skin.

        If the result is being made as a paid service, use this package as the source request and send back only the finished .openneko-skin file.
        """
    }

    private static func loadMetadata(at packageURL: URL) throws -> CustomSkinMetadata? {
        let url = packageURL.appendingPathComponent(metadataFilename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CustomSkinMetadata.self, from: data)
    }
}
