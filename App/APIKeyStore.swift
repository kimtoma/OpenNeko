import Foundation
import Security

enum APIKeyStoreError: Error {
    case unexpectedStatus(OSStatus)
}

final class APIKeyStore {
    private let service = "com.kimtoma.openneko.api-key"

    func apiKey(for presetID: String) -> String? {
        var query = baseQuery(for: presetID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func hasAPIKey(for presetID: String) -> Bool {
        apiKey(for: presetID) != nil
    }

    func save(_ apiKey: String, for presetID: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var query = baseQuery(for: presetID)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = Data(trimmed.utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    func delete(for presetID: String) throws {
        let status = SecItemDelete(baseQuery(for: presetID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for presetID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: presetID,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
    }
}
