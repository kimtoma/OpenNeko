import Foundation

public enum SkinError: Error, Equatable {
    case manifestMissing
    case skinNotFound
}

public final class SkinManager {
    public static let defaultID = "default"

    private let bundledRoot: URL
    private let externalRoot: URL?
    private let fm = FileManager.default

    public init(bundledRoot: URL, externalRoot: URL? = nil) {
        self.bundledRoot = bundledRoot
        self.externalRoot = externalRoot
    }

    /// "default" + 번들/외부 루트의 하위 폴더 id들 (정렬)
    public func availableSkinIDs() -> [String] {
        var ids: Set<String> = [Self.defaultID]
        for root in [bundledRoot, externalRoot].compactMap({ $0 }) {
            let subdirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for url in subdirs {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    ids.insert(url.lastPathComponent)
                }
            }
        }
        return ids.sorted()
    }

    /// 루트 manifest를 읽어 반환. 없으면 throw.
    private func rootManifest() throws -> SpriteManifest {
        let url = bundledRoot.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { throw SkinError.manifestMissing }
        return try SpriteManifest(data: data)
    }

    /// id가 가리키는 스킨 디렉터리 URL (default면 루트)
    private func directory(for id: String) -> URL? {
        if id == Self.defaultID { return bundledRoot }
        for root in [bundledRoot, externalRoot].compactMap({ $0 }) {
            let dir = root.appendingPathComponent(id)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue { return dir }
        }
        return nil
    }

    public func loadSkin(id: String) throws -> Skin {
        guard let dir = directory(for: id) else { throw SkinError.skinNotFound }
        // 해당 스킨 폴더에 manifest.json이 있으면 사용, 없으면 루트 manifest 공유
        let ownManifestURL = dir.appendingPathComponent("manifest.json")
        let manifest: SpriteManifest
        if let data = try? Data(contentsOf: ownManifestURL), let m = try? SpriteManifest(data: data) {
            manifest = m
        } else {
            manifest = try rootManifest()
        }
        return Skin(id: id, directory: dir, manifest: manifest)
    }

    /// 실패해도 throw하지 않는 안전 로더 (폴백).
    public func loadDefault() -> Skin {
        if let skin = try? loadSkin(id: Self.defaultID) { return skin }
        // 루트 manifest조차 깨졌으면 빈 manifest로 안전 스킨 구성
        let empty = (try? SpriteManifest(data: #"{"idle":[]}"#.data(using: .utf8)!))
        return Skin(id: Self.defaultID, directory: bundledRoot, manifest: empty ?? Self.safeEmptyManifest())
    }

    private static func safeEmptyManifest() -> SpriteManifest {
        // {"idle":[]} 는 SpriteManifest.empty 규칙에 걸리지 않음(키 1개 존재)
        return try! SpriteManifest(data: #"{"idle":[]}"#.data(using: .utf8)!)
    }
}
