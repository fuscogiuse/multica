import Foundation
import Security

/// Where the login token and server address live.
public protocol SecretStore: AnyObject {
    func get(_ key: String) -> String?
    func set(_ value: String?, for key: String)
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: String] = [:]
    public init() {}
    public func get(_ key: String) -> String? { values[key] }
    public func set(_ value: String?, for key: String) { values[key] = value }
}

/// Keychain-backed store, device only.
public final class KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "it.calmtasks.app") {
        self.service = service
    }

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    public func get(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func set(_ value: String?, for key: String) {
        SecItemDelete(query(key) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var q = query(key)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

/// Saved session: server, token, workspace.
public struct Session: Equatable, Sendable {
    public var serverURL: URL
    public var token: String
    public var workspaceId: String

    public init(serverURL: URL, token: String, workspaceId: String) {
        self.serverURL = serverURL; self.token = token; self.workspaceId = workspaceId
    }
}

public final class SessionStore {
    private let store: SecretStore
    public init(store: SecretStore) { self.store = store }

    public func load() -> Session? {
        guard let server = store.get("server"), let url = URL(string: server),
              let token = store.get("token"), let workspace = store.get("workspace") else { return nil }
        return Session(serverURL: url, token: token, workspaceId: workspace)
    }

    public func save(_ session: Session) {
        store.set(session.serverURL.absoluteString, for: "server")
        store.set(session.token, for: "token")
        store.set(session.workspaceId, for: "workspace")
    }

    public func savedServer() -> String? { store.get("server") }
    public func saveServer(_ url: URL) { store.set(url.absoluteString, for: "server") }

    public func clearToken() {
        store.set(nil, for: "token")
        store.set(nil, for: "workspace")
    }
}
