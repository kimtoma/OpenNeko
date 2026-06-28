import Foundation

public struct AppLaunchOptions: Equatable, Sendable {
    public let opensSettingsOnLaunch: Bool
    public let settingsSnapshotPath: String?
    public let debugSettingsMutationEnabled: Bool

    public init(environment: [String: String]) {
        let rawValue = environment["OPENNEKO_OPEN_SETTINGS"]?.lowercased()
        opensSettingsOnLaunch = rawValue == "1" || rawValue == "true"
        let snapshotPath = environment["OPENNEKO_SETTINGS_SNAPSHOT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsSnapshotPath = snapshotPath?.isEmpty == false ? snapshotPath : nil
        let debugMutation = environment["OPENNEKO_DEBUG_SETTINGS_MUTATION"]?.lowercased()
        debugSettingsMutationEnabled = debugMutation == "1" || debugMutation == "true"
    }
}
