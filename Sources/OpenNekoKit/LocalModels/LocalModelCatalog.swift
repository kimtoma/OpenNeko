import Foundation

/// One downloadable model in the bundled local model catalog
/// (`App/Resources/local-models.json`).
public struct LocalModelEntry: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var downloadGB: Double
    public var supportsTools: Bool
    public var koreanTested: Bool

    public init(id: String, displayName: String, downloadGB: Double, supportsTools: Bool, koreanTested: Bool) {
        self.id = id
        self.displayName = displayName
        self.downloadGB = downloadGB
        self.supportsTools = supportsTools
        self.koreanTested = koreanTested
    }
}

/// A memory tier: Macs with at least `minMemoryGB` of unified memory get
/// `primary` by default, with optional lighter/smarter alternatives.
public struct LocalModelTier: Codable, Equatable, Sendable {
    public var minMemoryGB: Int
    public var primary: String
    public var lighter: String?
    public var smarter: String?

    public init(minMemoryGB: Int, primary: String, lighter: String? = nil, smarter: String? = nil) {
        self.minMemoryGB = minMemoryGB
        self.primary = primary
        self.lighter = lighter
        self.smarter = smarter
    }
}

public struct LocalModelCatalog: Codable, Equatable, Sendable {
    public var version: Int
    public var updated: String
    public var models: [LocalModelEntry]
    public var tiers: [LocalModelTier]

    public init(version: Int, updated: String, models: [LocalModelEntry], tiers: [LocalModelTier]) {
        self.version = version
        self.updated = updated
        self.models = models
        self.tiers = tiers
    }

    public static func decode(from data: Data) throws -> LocalModelCatalog {
        try JSONDecoder().decode(LocalModelCatalog.self, from: data)
    }

    public func model(id: String) -> LocalModelEntry? {
        models.first { $0.id == id }
    }

    /// The highest tier whose memory floor fits, or nil when the Mac has less
    /// memory than the smallest tier.
    public func tier(forMemoryGB memoryGB: Int) -> LocalModelTier? {
        tiers
            .filter { $0.minMemoryGB <= memoryGB }
            .max { $0.minMemoryGB < $1.minMemoryGB }
    }

    /// Model ids referenced by tiers that are missing from `models`.
    /// Used by tests to keep the bundled JSON consistent.
    public var danglingModelIDs: [String] {
        let known = Set(models.map(\.id))
        var missing: [String] = []
        for tier in tiers {
            for id in [tier.primary, tier.lighter, tier.smarter].compactMap({ $0 }) where !known.contains(id) {
                if !missing.contains(id) {
                    missing.append(id)
                }
            }
        }
        return missing
    }
}
