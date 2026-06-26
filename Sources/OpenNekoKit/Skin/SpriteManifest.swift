import Foundation

public enum SpriteManifestError: Error, Equatable {
    case invalidJSON
    case empty
}

public struct SpriteManifest: Equatable {
    public let states: [String: [String]]

    public init(data: Data) throws {
        let obj = try? JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw SpriteManifestError.invalidJSON
        }
        var parsed: [String: [String]] = [:]
        for (key, value) in dict {
            if let frames = value as? [String] { parsed[key] = frames }
        }
        guard !parsed.isEmpty else { throw SpriteManifestError.empty }
        self.states = parsed
    }

    public func frames(for state: String) -> [String] {
        states[state] ?? []
    }

    public var stateNames: [String] {
        states.keys.sorted()
    }
}
