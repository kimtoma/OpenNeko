import Foundation
import OpenNekoKit

enum SkinPackageServiceError: LocalizedError {
    case bundledManifestMissing
    case packageNotFound
    case archiveFailed(String)
    case extractionFailed(String)
    case invalidPackage(String)

    var errorDescription: String? {
        switch self {
        case .bundledManifestMissing:
            return "기본 스킨 manifest.json을 찾지 못했습니다."
        case .packageNotFound:
            return "스킨팩 안에서 manifest.json을 찾지 못했습니다."
        case .archiveFailed(let detail):
            return "요청 파일을 압축하지 못했습니다. \(detail)"
        case .extractionFailed(let detail):
            return "스킨팩을 열지 못했습니다. \(detail)"
        case .invalidPackage(let detail):
            return "스킨팩 형식이 올바르지 않습니다. \(detail)"
        }
    }
}

struct SkinRequestPackageResult {
    let packageURL: URL
    let recipe: SkinGenerationRecipe
}

struct SkinPackageImportResult {
    let installedURL: URL
    let validation: SkinPackageValidation
}

final class SkinPackageService {
    private let externalRoot: URL
    private let rootManifest: SpriteManifest
    private let rootManifestData: Data
    private let fm: FileManager

    init(externalRoot: URL, rootManifestURL: URL, fileManager: FileManager = .default) throws {
        self.externalRoot = externalRoot
        self.fm = fileManager
        guard let data = try? Data(contentsOf: rootManifestURL),
              let manifest = try? SpriteManifest(data: data)
        else {
            throw SkinPackageServiceError.bundledManifestMissing
        }
        self.rootManifest = manifest
        self.rootManifestData = data
    }

    func createRequestPackage(
        catName: String,
        displayName: String,
        baseSkinID: String,
        photoURLs: [URL],
        destinationURL: URL
    ) throws -> SkinRequestPackageResult {
        let tempRoot = temporaryDirectory(named: "skin-request")
        defer { try? fm.removeItem(at: tempRoot) }

        let rawID = displayName.isEmpty ? catName : displayName
        let skinID = SkinPackageSupport.sanitizedSkinID(from: rawID)
        let payload = tempRoot.appendingPathComponent(skinID, isDirectory: true)
        let photosDirectory = payload.appendingPathComponent(SkinPackageSupport.photosDirectoryName, isDirectory: true)
        try fm.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        let photoNames = try copyPhotos(photoURLs, to: photosDirectory)
        let recipe = SkinPackageSupport.recipe(
            skinID: skinID,
            displayName: displayName,
            catName: catName,
            baseSkinID: baseSkinID,
            photoFilenames: photoNames.map { "\(SkinPackageSupport.photosDirectoryName)/\($0)" },
            rootManifest: rootManifest
        )
        let metadata = SkinPackageSupport.metadata(for: recipe, source: "openNeko photo request")

        try writeJSON(metadata, to: payload.appendingPathComponent(SkinPackageSupport.metadataFilename))
        try writeJSON(recipe, to: payload.appendingPathComponent(SkinPackageSupport.recipeFilename))
        try rootManifestData.write(to: payload.appendingPathComponent("manifest.json"))
        try SkinPackageSupport
            .chatGPTPrompt(recipe: recipe, rootManifest: rootManifest)
            .write(
                to: payload.appendingPathComponent(SkinPackageSupport.promptFilename),
                atomically: true,
                encoding: .utf8
            )

        try archiveDirectory(payload, to: destinationURL)
        return SkinRequestPackageResult(packageURL: destinationURL, recipe: recipe)
    }

    func importSkinPackage(from sourceURL: URL) throws -> SkinPackageImportResult {
        let tempRoot = temporaryDirectory(named: "skin-import")
        defer { try? fm.removeItem(at: tempRoot) }

        let packageURL: URL
        if isDirectory(sourceURL) {
            packageURL = try resolvedPackageDirectory(in: sourceURL)
        } else {
            try extractArchive(sourceURL, to: tempRoot)
            packageURL = try resolvedPackageDirectory(in: tempRoot)
        }

        let fallbackID = SkinPackageSupport.sanitizedSkinID(
            from: sourceURL.deletingPathExtension().lastPathComponent
        )
        let validation = try SkinPackageSupport.validateSkinPackage(
            at: packageURL,
            fallbackSkinID: fallbackID,
            rootManifest: rootManifest
        )
        guard validation.isReady else {
            throw SkinPackageError.missingRequiredFrames(validation.missingFrames)
        }

        try fm.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        let destination = externalRoot.appendingPathComponent(validation.skinID, isDirectory: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: packageURL, to: destination)
        return SkinPackageImportResult(installedURL: destination, validation: validation)
    }

    private func copyPhotos(_ urls: [URL], to directory: URL) throws -> [String] {
        var copiedNames: [String] = []
        for (index, url) in urls.enumerated() {
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
            let base = SkinPackageSupport.sanitizedSkinID(
                from: url.deletingPathExtension().lastPathComponent
            )
            let filename = "photo-\(index + 1)-\(base).\(ext)"
            try fm.copyItem(at: url, to: directory.appendingPathComponent(filename))
            copiedNames.append(filename)
        }
        return copiedNames
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    private func archiveDirectory(_ directory: URL, to destination: URL) throws {
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.currentDirectoryURL = directory.deletingLastPathComponent()
        process.arguments = ["-c", "-k", "--keepParent", directory.lastPathComponent, destination.path]
        try run(process, error: SkinPackageServiceError.archiveFailed)
    }

    private func extractArchive(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, destination.path]
        try run(process, error: SkinPackageServiceError.extractionFailed)
    }

    private func run(_ process: Process, error makeError: (String) -> SkinPackageServiceError) throws {
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw makeError(detail)
        }
    }

    private func resolvedPackageDirectory(in url: URL) throws -> URL {
        if fm.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }

        let children = (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        if let direct = children.first(where: { isDirectory($0) && fm.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }) {
            return direct
        }

        throw SkinPackageServiceError.packageNotFound
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func temporaryDirectory(named name: String) -> URL {
        fm.temporaryDirectory
            .appendingPathComponent("openneko-\(name)-\(UUID().uuidString)", isDirectory: true)
    }
}
