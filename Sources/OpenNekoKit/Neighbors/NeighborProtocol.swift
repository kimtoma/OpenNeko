import Foundation

public enum NeighborPresence: String, CaseIterable, Codable, Equatable, Sendable {
    case idle
    case coding
    case typing
    case away

    public static func coarse(for state: CatState) -> NeighborPresence {
        switch state {
        case .typing:
            .typing
        case .coding, .thinking:
            .coding
        case .nap, .yawn:
            .away
        default:
            .idle
        }
    }
}

public struct NeighborPeer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var skin: String
    public var presence: NeighborPresence
    public var lastSeen: TimeInterval

    public init(
        id: String,
        name: String = "",
        skin: String = SkinManager.defaultID,
        presence: NeighborPresence = .idle,
        lastSeen: TimeInterval = 0
    ) {
        self.id = UserProfile.sanitized(id, limit: 64)
        self.name = UserProfile.sanitized(name, limit: 64)
        self.skin = UserProfile.sanitized(skin, limit: 32)
        self.presence = presence
        self.lastSeen = lastSeen
    }
}

public enum NeighborEvent: Equatable, Sendable {
    case joined(NeighborPeer)
    case left(NeighborPeer)
    case presence(NeighborPeer)
    case wave(NeighborPeer)
    case greeting(NeighborPeer, key: Int)
}

public struct NeighborPeerBook: Equatable, Sendable {
    private var storage: [String: NeighborPeer] = [:]

    public init() {}

    public var peers: [NeighborPeer] {
        storage.keys.sorted().compactMap { storage[$0] }
    }

    public mutating func addOrUpdate(_ peer: NeighborPeer) -> (peer: NeighborPeer, isNew: Bool)? {
        guard !peer.id.isEmpty else { return nil }
        let previous = storage[peer.id]
        let merged = NeighborPeer(
            id: peer.id,
            name: peer.name,
            skin: peer.skin,
            presence: peer.presence,
            lastSeen: peer.lastSeen
        )
        storage[peer.id] = merged
        return (merged, previous == nil)
    }

    public mutating func remove(id: String) -> NeighborPeer? {
        storage.removeValue(forKey: id)
    }

    public mutating func touch(id: String, lastSeen: TimeInterval) -> NeighborPeer? {
        guard var peer = storage[id] else { return nil }
        peer.lastSeen = lastSeen
        storage[id] = peer
        return peer
    }

    public mutating func setPresence(id: String, _ presence: NeighborPresence, lastSeen: TimeInterval) -> NeighborPeer? {
        guard var peer = storage[id] else { return nil }
        peer.presence = presence
        peer.lastSeen = lastSeen
        storage[id] = peer
        return peer
    }

    public mutating func prune(now: TimeInterval, ttl: TimeInterval) -> [NeighborPeer] {
        let expired = storage.values.filter { now - $0.lastSeen > ttl }
        for peer in expired {
            storage.removeValue(forKey: peer.id)
        }
        return expired.sorted { $0.id < $1.id }
    }

    public func peer(id: String) -> NeighborPeer? {
        storage[id]
    }
}

public struct NeighborMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case hello
        case presence
        case wave
        case greeting
        case bye
    }

    public let kind: Kind
    public let id: String?
    public let name: String?
    public let skin: String?
    public let presence: NeighborPresence?
    public let greetingKey: Int?

    private enum CodingKeys: String, CodingKey {
        case kind = "t"
        case id
        case name
        case skin
        case state
        case key
    }

    public static func hello(id: String, name: String, skin: String) -> NeighborMessage? {
        let id = UserProfile.sanitized(id, limit: 64)
        guard !id.isEmpty else { return nil }
        return NeighborMessage(
            kind: .hello,
            id: id,
            name: UserProfile.sanitized(name, limit: 64),
            skin: UserProfile.sanitized(skin, limit: 32).nilIfEmpty ?? SkinManager.defaultID,
            presence: nil,
            greetingKey: nil
        )
    }

    public static func presence(_ presence: NeighborPresence) -> NeighborMessage {
        NeighborMessage(kind: .presence, id: nil, name: nil, skin: nil, presence: presence, greetingKey: nil)
    }

    public static func wave() -> NeighborMessage {
        NeighborMessage(kind: .wave, id: nil, name: nil, skin: nil, presence: nil, greetingKey: nil)
    }

    public static func greeting(key: Int) -> NeighborMessage? {
        guard key >= 0, key < 100 else { return nil }
        return NeighborMessage(kind: .greeting, id: nil, name: nil, skin: nil, presence: nil, greetingKey: key)
    }

    public static func bye() -> NeighborMessage {
        NeighborMessage(kind: .bye, id: nil, name: nil, skin: nil, presence: nil, greetingKey: nil)
    }

    private init(
        kind: Kind,
        id: String?,
        name: String?,
        skin: String?,
        presence: NeighborPresence?,
        greetingKey: Int?
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.skin = skin
        self.presence = presence
        self.greetingKey = greetingKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .hello:
            let id = UserProfile.sanitized((try? container.decode(String.self, forKey: .id)) ?? "", limit: 64)
            guard !id.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing peer id")
            }
            self.kind = .hello
            self.id = id
            self.name = UserProfile.sanitized((try? container.decode(String.self, forKey: .name)) ?? "", limit: 64)
            self.skin = UserProfile.sanitized((try? container.decode(String.self, forKey: .skin)) ?? "", limit: 32)
                .nilIfEmpty ?? SkinManager.defaultID
            self.presence = nil
            self.greetingKey = nil
        case .presence:
            let presence = try container.decode(NeighborPresence.self, forKey: .state)
            self.kind = .presence
            self.id = nil
            self.name = nil
            self.skin = nil
            self.presence = presence
            self.greetingKey = nil
        case .wave:
            self.kind = .wave
            self.id = nil
            self.name = nil
            self.skin = nil
            self.presence = nil
            self.greetingKey = nil
        case .greeting:
            let key = try container.decode(Int.self, forKey: .key)
            guard key >= 0, key < 100 else {
                throw DecodingError.dataCorruptedError(forKey: .key, in: container, debugDescription: "Invalid greeting key")
            }
            self.kind = .greeting
            self.id = nil
            self.name = nil
            self.skin = nil
            self.presence = nil
            self.greetingKey = key
        case .bye:
            self.kind = .bye
            self.id = nil
            self.name = nil
            self.skin = nil
            self.presence = nil
            self.greetingKey = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch kind {
        case .hello:
            try container.encode(id, forKey: .id)
            try container.encode(name ?? "", forKey: .name)
            try container.encode(skin ?? SkinManager.defaultID, forKey: .skin)
        case .presence:
            try container.encode(presence, forKey: .state)
        case .wave, .bye:
            break
        case .greeting:
            try container.encode(greetingKey, forKey: .key)
        }
    }
}

public enum NeighborMessageCodec {
    public static let maxRawBytes = 2_048

    public static func encode(_ message: NeighborMessage) throws -> Data {
        var data = try JSONEncoder().encode(message)
        data.append(0x0A)
        return data
    }

    public static func decodeLine(_ line: String) -> NeighborMessage? {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let data = text.data(using: .utf8), data.count <= maxRawBytes else {
            return nil
        }
        return try? JSONDecoder().decode(NeighborMessage.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
