import Foundation
import Security

enum KeychainStore {
    private static let service = "com.pdfaudiobookstudio.app"

    static func set(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)
        return value?.isEmpty == true ? nil : value
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var openaiAPIKey: String? {
        get { get(account: "openai_api_key") }
        set { setOrDelete(newValue, account: "openai_api_key") }
    }

    static var xaiAPIKey: String? {
        get { get(account: "xai_api_key") }
        set { setOrDelete(newValue, account: "xai_api_key") }
    }

    static var googleAPIKey: String? {
        get { get(account: "google_api_key") }
        set { setOrDelete(newValue, account: "google_api_key") }
    }

    private static func setOrDelete(_ value: String?, account: String) {
        if let value {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                delete(account: account)
            } else {
                set(trimmed, account: account)
            }
        } else {
            delete(account: account)
        }
    }
}
