import Foundation

public enum SettingsDraftSynchronization {
    public static func reconciledDraft<Value: Equatable>(
        _ draft: Value?,
        storedValue: Value
    ) -> Value? {
        guard let draft else { return nil }
        return draft == storedValue ? draft : nil
    }
}
