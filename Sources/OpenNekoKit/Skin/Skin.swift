import Foundation

public struct Skin: Equatable {
    public let id: String
    public let directory: URL
    public let manifest: SpriteManifest

    public init(id: String, directory: URL, manifest: SpriteManifest) {
        self.id = id
        self.directory = directory
        self.manifest = manifest
    }

    /// 프레임 PNG 절대 URL 목록. 파일은 이 스킨의 directory에서 찾는다.
    public func frameURLs(for state: String) -> [URL] {
        manifest.frames(for: state).map { directory.appendingPathComponent($0) }
    }
}
