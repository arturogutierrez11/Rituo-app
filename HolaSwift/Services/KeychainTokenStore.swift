import Foundation
import Security

enum KeychainTokenStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            return "Keychain respondio con status \(status)."
        }
    }
}

final class KeychainTokenStore {
    static let shared = KeychainTokenStore()

    private let service = "io.rituo.app.auth"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    private let authProviderAccount = "authProvider"
    private let authUserAccount = "authUser"
    private let profileDisplayNameAccount = "profileDisplayName"
    private let profileImageURLAccount = "profileImageURL"
    private let syncSecretPrefix = "syncOperation."

    private init() {}

    func save(accessToken: String, refreshToken: String) throws {
        try save(value: accessToken, account: accessTokenAccount)
        try save(value: refreshToken, account: refreshTokenAccount)
    }

    func saveSession(
        accessToken: String,
        refreshToken: String,
        user: AuthUser,
        provider: AuthProvider,
        profileDisplayName: String?,
        profileImageURL: URL?
    ) throws {
        try save(accessToken: accessToken, refreshToken: refreshToken)
        try saveAuthUser(user)
        try save(value: provider.rawValue, account: authProviderAccount)
        try saveOptional(value: profileDisplayName, account: profileDisplayNameAccount)
        try saveOptional(value: profileImageURL?.absoluteString, account: profileImageURLAccount)
    }

    func loadAccessToken() -> String? {
        load(account: accessTokenAccount)
    }

    func loadRefreshToken() -> String? {
        load(account: refreshTokenAccount)
    }

    func loadAuthProvider() -> AuthProvider? {
        load(account: authProviderAccount).flatMap(AuthProvider.init(rawValue:))
    }

    func loadAuthUser() -> AuthUser? {
        guard let stored = load(account: authUserAccount),
              let data = stored.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    func loadProfileDisplayName() -> String? {
        load(account: profileDisplayNameAccount)
    }

    func loadProfileImageURL() -> URL? {
        load(account: profileImageURLAccount).flatMap(URL.init(string:))
    }

    func clear() {
        delete(account: accessTokenAccount)
        delete(account: refreshTokenAccount)
        delete(account: authProviderAccount)
        delete(account: authUserAccount)
        delete(account: profileDisplayNameAccount)
        delete(account: profileImageURLAccount)
    }

    func saveSyncSecret(_ value: String, operationID: UUID) throws {
        try save(value: value, account: syncSecretAccount(operationID))
    }

    func loadSyncSecret(operationID: UUID) -> String? {
        load(account: syncSecretAccount(operationID))
    }

    func deleteSyncSecret(operationID: UUID) {
        delete(account: syncSecretAccount(operationID))
    }

    func clearSyncSecrets() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return
        }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(syncSecretPrefix) else {
                continue
            }
            delete(account: account)
        }
    }

    private func syncSecretAccount(_ operationID: UUID) -> String {
        "\(syncSecretPrefix)\(operationID.uuidString)"
    }

    private func saveOptional(value: String?, account: String) throws {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            delete(account: account)
            return
        }

        try save(value: value, account: account)
    }

    private func saveAuthUser(_ user: AuthUser) throws {
        let data = try JSONEncoder().encode(user)
        guard let encoded = String(data: data, encoding: .utf8) else { return }
        try save(value: encoded, account: authUserAccount)
    }

    private func save(value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var insertQuery = query
            attributes.forEach { insertQuery[$0.key] = $0.value }

            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw KeychainTokenStoreError.unexpectedStatus(insertStatus)
            }
            return
        }

        throw KeychainTokenStoreError.unexpectedStatus(status)
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
