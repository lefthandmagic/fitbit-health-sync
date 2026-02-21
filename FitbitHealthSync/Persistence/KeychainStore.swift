import Foundation
import Security

final class KeychainStore {
    enum Key: String {
        case accessToken = "fitbit.accessToken"
        case refreshToken = "fitbit.refreshToken"
        case expiresAt = "fitbit.expiresAt"
    }

    func set(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    func clearAll() {
        [Key.accessToken, .refreshToken, .expiresAt].forEach { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key.rawValue
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
