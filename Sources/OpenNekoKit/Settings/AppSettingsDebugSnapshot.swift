import Foundation

public struct AppSettingsDebugSnapshot: Codable, Equatable, Sendable {
    public let selectedSkinID: String
    public let launchAtLoginEnabled: Bool
    public let hasCompletedFirstLaunch: Bool
    public let aiProviderPresetID: String
    public let aiProviderType: AIProviderType
    public let aiProviderBaseURL: String
    public let aiProviderModel: String
    public let disabledSkillIDs: [String]
    public let agentProcessDetectionEnabled: Bool
    public let languageCode: String?
    public let soundEffectsEnabled: Bool
    public let webSearchEnabled: Bool
    public let catName: String
    public let userProfileConfigured: Bool
    public let userProfileFields: [String]
    public let neighborEnabled: Bool
    public let neighborDisplayName: String
    public let peerIDConfigured: Bool

    public init(settings: AppSettings) {
        selectedSkinID = settings.selectedSkinID
        launchAtLoginEnabled = settings.launchAtLoginEnabled
        hasCompletedFirstLaunch = settings.hasCompletedFirstLaunch
        aiProviderPresetID = settings.aiProvider.presetID
        aiProviderType = settings.aiProvider.type
        aiProviderBaseURL = settings.aiProvider.baseURL
        aiProviderModel = settings.aiProvider.model
        disabledSkillIDs = settings.disabledSkillIDs.sorted()
        agentProcessDetectionEnabled = settings.agentProcessDetectionEnabled
        languageCode = settings.languageCode
        soundEffectsEnabled = settings.soundEffectsEnabled
        webSearchEnabled = settings.webSearchEnabled
        catName = settings.catName
        userProfileConfigured = settings.userProfile != .empty
        userProfileFields = Self.configuredProfileFields(settings.userProfile)
        neighborEnabled = settings.neighborSettings.enabled
        neighborDisplayName = settings.neighborSettings.displayName
        peerIDConfigured = !settings.peerID.isEmpty
    }

    public static func jsonString(settings: AppSettings) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(AppSettingsDebugSnapshot(settings: settings)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func configuredProfileFields(_ profile: UserProfile) -> [String] {
        var fields: [String] = []
        if !profile.name.isEmpty {
            fields.append("name")
        }
        if !profile.birthDate.isEmpty {
            fields.append("birthDate")
        }
        if !profile.birthTime.isEmpty {
            fields.append("birthTime")
        }
        if profile.calendar != UserProfile.empty.calendar {
            fields.append("calendar")
        }
        return fields
    }
}
