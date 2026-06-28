import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public static let defaults = AppSettings(
        selectedSkinID: SkinManager.defaultID,
        launchAtLoginEnabled: false,
        hasCompletedFirstLaunch: false,
        aiProvider: AIProviderPreset.defaultConfig,
        disabledSkillIDs: [],
        agentProcessDetectionEnabled: true,
        languageCode: nil,
        soundEffectsEnabled: true,
        webSearchEnabled: false,
        catName: "",
        userProfile: .empty,
        neighborSettings: .defaults,
        peerID: ""
    )

    public var selectedSkinID: String
    public var launchAtLoginEnabled: Bool
    public var hasCompletedFirstLaunch: Bool
    public var aiProvider: AIProviderConfig
    public var disabledSkillIDs: Set<String>
    public var agentProcessDetectionEnabled: Bool
    public var languageCode: String?
    public var soundEffectsEnabled: Bool
    public var webSearchEnabled: Bool
    public var catName: String
    public var userProfile: UserProfile
    public var neighborSettings: NeighborSettings
    public var peerID: String

    public init(
        selectedSkinID: String,
        launchAtLoginEnabled: Bool,
        hasCompletedFirstLaunch: Bool = false,
        aiProvider: AIProviderConfig = AIProviderPreset.defaultConfig,
        disabledSkillIDs: Set<String> = [],
        agentProcessDetectionEnabled: Bool = true,
        languageCode: String? = nil,
        soundEffectsEnabled: Bool = true,
        webSearchEnabled: Bool = false,
        catName: String = "",
        userProfile: UserProfile = .empty,
        neighborSettings: NeighborSettings = .defaults,
        peerID: String = ""
    ) {
        self.selectedSkinID = selectedSkinID
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.hasCompletedFirstLaunch = hasCompletedFirstLaunch
        self.aiProvider = aiProvider
        self.disabledSkillIDs = disabledSkillIDs
        self.agentProcessDetectionEnabled = agentProcessDetectionEnabled
        self.languageCode = AppLanguage.normalized(languageCode)
        self.soundEffectsEnabled = soundEffectsEnabled
        self.webSearchEnabled = webSearchEnabled
        self.catName = UserProfile.sanitized(catName, limit: 64)
        self.userProfile = userProfile.normalized()
        self.neighborSettings = neighborSettings.normalized()
        self.peerID = UserProfile.sanitized(peerID, limit: 64)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedSkinID
        case launchAtLoginEnabled
        case hasCompletedFirstLaunch
        case aiProvider
        case disabledSkillIDs
        case agentProcessDetectionEnabled
        case languageCode
        case soundEffectsEnabled
        case webSearchEnabled
        case catName
        case userProfile
        case neighborSettings
        case peerID
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case skin
        case launchAtLogin
        case onboarded
        case provider
        case disabledSkills
        case lang
        case sound
        case webSearch
        case profile
        case neighbor
        case peerId
        case catName
    }

    private struct LegacyAIProviderConfig: Decodable {
        let preset: String?
        let type: AIProviderType?
        let baseURL: String?
        let model: String?
    }

    private struct LegacySound: Decodable {
        let enabled: Bool?
    }

    private struct LegacyNeighbor: Decodable {
        let enabled: Bool?
        let displayName: String?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self)

        selectedSkinID = (try? container.decodeIfPresent(String.self, forKey: .selectedSkinID))
            ?? Self.normalizedLegacySkinID(try? legacy?.decodeIfPresent(String.self, forKey: .skin))
            ?? Self.defaults.selectedSkinID
        launchAtLoginEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled))
            ?? (try? legacy?.decodeIfPresent(Bool.self, forKey: .launchAtLogin))
            ?? Self.defaults.launchAtLoginEnabled
        hasCompletedFirstLaunch = (try? container.decodeIfPresent(Bool.self, forKey: .hasCompletedFirstLaunch))
            ?? (try? legacy?.decodeIfPresent(Bool.self, forKey: .onboarded))
            ?? Self.defaults.hasCompletedFirstLaunch
        aiProvider = (try? container.decodeIfPresent(AIProviderConfig.self, forKey: .aiProvider))
            ?? Self.migratedLegacyProvider(try? legacy?.decodeIfPresent(LegacyAIProviderConfig.self, forKey: .provider))
            ?? Self.defaults.aiProvider
        disabledSkillIDs = Set(
            (try? container.decodeIfPresent([String].self, forKey: .disabledSkillIDs))
                ?? (try? legacy?.decodeIfPresent([String].self, forKey: .disabledSkills))
                ?? []
        )
        agentProcessDetectionEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .agentProcessDetectionEnabled))
            ?? Self.defaults.agentProcessDetectionEnabled
        languageCode = AppLanguage.normalized(
            (try? container.decodeIfPresent(String.self, forKey: .languageCode))
                ?? (try? legacy?.decodeIfPresent(String.self, forKey: .lang))
        )
        let legacySound = try? legacy?.decodeIfPresent(LegacySound.self, forKey: .sound)
        soundEffectsEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .soundEffectsEnabled))
            ?? legacySound?.enabled
            ?? Self.defaults.soundEffectsEnabled
        webSearchEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .webSearchEnabled))
            ?? (try? legacy?.decodeIfPresent(Bool.self, forKey: .webSearch))
            ?? Self.defaults.webSearchEnabled
        let legacyNeighbor = try? legacy?.decodeIfPresent(LegacyNeighbor.self, forKey: .neighbor)
        catName = UserProfile.sanitized(
            (try? container.decodeIfPresent(String.self, forKey: .catName))
                ?? (try? legacy?.decodeIfPresent(String.self, forKey: .catName))
                ?? legacyNeighbor?.displayName
                ?? Self.defaults.catName,
            limit: 64
        )
        userProfile = ((try? container.decodeIfPresent(UserProfile.self, forKey: .userProfile))
            ?? (try? legacy?.decodeIfPresent(UserProfile.self, forKey: .profile))
            ?? Self.defaults.userProfile)
            .normalized()
        neighborSettings = ((try? container.decodeIfPresent(NeighborSettings.self, forKey: .neighborSettings))
            ?? legacyNeighbor.map { legacy in
                NeighborSettings(
                    enabled: legacy.enabled ?? NeighborSettings.defaults.enabled,
                    displayName: legacy.displayName ?? ""
                )
            }
            ?? Self.defaults.neighborSettings)
            .normalized()
        peerID = UserProfile.sanitized(
            (try? container.decodeIfPresent(String.self, forKey: .peerID))
                ?? (try? legacy?.decodeIfPresent(String.self, forKey: .peerId))
                ?? Self.defaults.peerID,
            limit: 64
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedSkinID, forKey: .selectedSkinID)
        try container.encode(launchAtLoginEnabled, forKey: .launchAtLoginEnabled)
        try container.encode(hasCompletedFirstLaunch, forKey: .hasCompletedFirstLaunch)
        try container.encode(aiProvider, forKey: .aiProvider)
        try container.encode(disabledSkillIDs.sorted(), forKey: .disabledSkillIDs)
        try container.encode(agentProcessDetectionEnabled, forKey: .agentProcessDetectionEnabled)
        try container.encodeIfPresent(languageCode, forKey: .languageCode)
        try container.encode(soundEffectsEnabled, forKey: .soundEffectsEnabled)
        try container.encode(webSearchEnabled, forKey: .webSearchEnabled)
        try container.encode(catName, forKey: .catName)
        try container.encode(userProfile, forKey: .userProfile)
        try container.encode(neighborSettings, forKey: .neighborSettings)
        try container.encode(peerID, forKey: .peerID)
    }

    private static func normalizedLegacySkinID(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        return id == "white" ? SkinManager.defaultID : id
    }

    private static func migratedLegacyProvider(_ legacy: LegacyAIProviderConfig?) -> AIProviderConfig? {
        guard
            let legacy,
            let presetID = legacy.preset,
            let preset = AIProviderPreset.preset(for: presetID)
        else {
            return nil
        }

        return AIProviderPreset.config(
            for: presetID,
            overrides: AIProviderConfig(
                presetID: presetID,
                type: legacy.type ?? preset.type,
                baseURL: legacy.baseURL,
                model: legacy.model
            )
        )
    }
}

public final class AppSettingsStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public convenience init(fileManager: FileManager = .default) {
        self.init(fileURL: Self.defaultFileURL(fileManager: fileManager))
    }

    public static func defaultFileURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["OPENNEKO_SETTINGS_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return baseURL
            .appendingPathComponent("openNeko", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    public func load() -> AppSettings {
        guard
            let data = try? Data(contentsOf: fileURL),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
