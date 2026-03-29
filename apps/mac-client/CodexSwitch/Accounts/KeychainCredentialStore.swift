import Foundation
import Security

public struct KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "com.codex.switch.credentials") {
        self.service = service
    }

    public func saveSecret(_ secret: String, for accountID: String) throws {
        let data = Data(secret.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status != errSecItemNotFound {
            throw KeychainCredentialStoreError.unexpectedStatus(status)
        }

        var insertQuery = baseQuery
        insertQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    public func loadSecret(for accountID: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainCredentialStoreError.unexpectedStatus(status)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainCredentialStoreError.invalidValue
        }

        return value
    }
}

public enum KeychainCredentialStoreError: Error {
    case invalidValue
    case unexpectedStatus(OSStatus)
}
