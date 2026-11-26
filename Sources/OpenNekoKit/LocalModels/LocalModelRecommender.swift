import Foundation

/// What the setup wizard knows about the Mac it runs on.
public struct HardwareProfile: Equatable, Sendable {
    public var memoryBytes: UInt64
    public var isAppleSilicon: Bool
    public var freeDiskBytes: UInt64

    public init(memoryBytes: UInt64, isAppleSilicon: Bool, freeDiskBytes: UInt64) {
        self.memoryBytes = memoryBytes
        self.isAppleSilicon = isAppleSilicon
        self.freeDiskBytes = freeDiskBytes
    }

    /// Unified memory in whole GB, rounded to the nearest GB so a 16 GB Mac
    /// that reports slightly less still lands in the 16 GB tier.
    public var memoryGB: Int {
        Int((Double(memoryBytes) / Double(HardwareProfile.bytesPerGB)).rounded())
    }

    public var freeDiskGB: Double {
        Double(freeDiskBytes) / Double(HardwareProfile.bytesPerGB)
    }

    public static let bytesPerGB: UInt64 = 1_073_741_824
}

public enum LocalModelUnsupportedReason: Equatable, Sendable {
    case notAppleSilicon
    case notEnoughMemory(minimumGB: Int)
    case notEnoughDisk(neededGB: Double)
}

public enum LocalModelRecommendation: Equatable, Sendable {
    case recommended(primary: LocalModelEntry, lighter: LocalModelEntry?, smarter: LocalModelEntry?)
    case unsupported(LocalModelUnsupportedReason)

    /// All selectable models, lighter first, for a picker.
    public var choices: [LocalModelEntry] {
        guard case let .recommended(primary, lighter, smarter) = self else {
            return []
        }
        return [lighter, primary, smarter].compactMap { $0 }
    }
}

public enum LocalModelRecommender {
    /// Free space kept beyond the download itself, so Ollama can unpack and
    /// the system does not run dry.
    public static let diskHeadroomGB: Double = 2

    public static func recommend(
        catalog: LocalModelCatalog,
        hardware: HardwareProfile
    ) -> LocalModelRecommendation {
        guard hardware.isAppleSilicon else {
            return .unsupported(.notAppleSilicon)
        }
        guard let tier = catalog.tier(forMemoryGB: hardware.memoryGB),
              let tierPrimary = catalog.model(id: tier.primary)
        else {
            let minimum = catalog.tiers.map(\.minMemoryGB).min() ?? 0
            return .unsupported(.notEnoughMemory(minimumGB: minimum))
        }

        let lighter = tier.lighter.flatMap { catalog.model(id: $0) }
        let smarter = tier.smarter.flatMap { catalog.model(id: $0) }

        if fitsOnDisk(tierPrimary, hardware: hardware) {
            return .recommended(
                primary: tierPrimary,
                lighter: lighter.flatMap { fitsOnDisk($0, hardware: hardware) ? $0 : nil },
                smarter: smarter.flatMap { fitsOnDisk($0, hardware: hardware) ? $0 : nil }
            )
        }

        // The tier's default does not fit on disk: fall back to the lighter
        // model when it does, and offer nothing heavier.
        if let lighter, fitsOnDisk(lighter, hardware: hardware) {
            return .recommended(primary: lighter, lighter: nil, smarter: nil)
        }

        let smallest = [tierPrimary, lighter].compactMap { $0 }.map(\.downloadGB).min() ?? tierPrimary.downloadGB
        return .unsupported(.notEnoughDisk(neededGB: smallest + diskHeadroomGB))
    }

    public static func fitsOnDisk(_ model: LocalModelEntry, hardware: HardwareProfile) -> Bool {
        hardware.freeDiskGB >= model.downloadGB + diskHeadroomGB
    }
}
