import Foundation

/// Email-code login against the self-hosted server, then a saved session.
public final class AuthService {
    private let sessions: SessionStore
    public private(set) var client: APIClient?

    public init(sessions: SessionStore) { self.sessions = sessions }

    public func prepare(server: URL) {
        client = APIClient(baseURL: server)
        sessions.saveServer(server)
    }

    public func sendCode(email: String) async throws {
        guard let client else { throw APIError.network("no server") }
        try await client.sendCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Verifies the code, picks the workspace and saves the session.
    public func verify(email: String, code: String, preferredSlug: String? = nil) async throws -> Session {
        guard let client else { throw APIError.network("no server") }
        let token = try await client.verifyCode(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            code: code.trimmingCharacters(in: .whitespacesAndNewlines))
        client.token = token
        let all = try await client.workspaces()
        guard let workspace = all.first(where: { $0.slug == preferredSlug }) ?? all.first else {
            throw APIError.http(status: 404, message: "Nessun workspace trovato per questo account.")
        }
        let session = Session(serverURL: client.baseURL, token: token, workspaceId: workspace.id, workspaceSlug: workspace.slug)
        sessions.save(session)
        client.workspaceId = workspace.id
        return session
    }

    public func restore() -> Session? {
        guard let session = sessions.load() else { return nil }
        client = APIClient(baseURL: session.serverURL, token: session.token, workspaceId: session.workspaceId)
        return session
    }

    public func signOut() {
        sessions.clearToken()
        client?.token = nil
        client?.workspaceId = nil
    }
}
