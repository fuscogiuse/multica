import SwiftUI
import CalmCore

/// App-wide state: login, the board store and the live socket.
@MainActor
final class AppModel: ObservableObject {
    enum Phase { case onboarding, ready }

    @Published var phase: Phase = .onboarding
    @Published var store: BoardStore?
    @Published var session: Session?

    let auth: AuthService
    private var socket: LiveSocket?
    private var refreshTask: Task<Void, Never>?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            auth = AuthService(sessions: SessionStore(store: InMemorySecretStore()))
            let demo = BoardStore(api: DemoAPI())
            store = demo
            phase = .ready
            Task { await demo.refresh() }
            return
        }
        auth = AuthService(sessions: SessionStore(store: KeychainSecretStore()))
        if let restored = auth.restore(), let client = auth.client {
            session = restored
            store = BoardStore(api: client)
            phase = .ready
            Task { await self.refresh() }
            startSocket()
        }
    }

    var savedServer: String { SessionStoreAccess.savedServer() }

    var webBase: URL? { session?.serverURL }

    /// Link to the web workflow editor for a project's workflow.
    func workflowEditorURL(workflowId: String?) -> URL? {
        guard let session, let slug = session.workspaceSlug else { return nil }
        var parts = URLComponents(url: session.serverURL, resolvingAgainstBaseURL: false)
        parts?.path = "/\(slug)/settings"
        var items = [URLQueryItem(name: "tab", value: "workflows")]
        if let workflowId { items.append(URLQueryItem(name: "workflow", value: workflowId)) }
        parts?.queryItems = items
        return parts?.url
    }

    func prepare(server: String) throws {
        let url = try ServerConfig.normalize(server)
        auth.prepare(server: url)
    }

    func sendCode(email: String) async throws { try await auth.sendCode(email: email) }

    func verify(email: String, code: String) async throws {
        let session = try await auth.verify(email: email, code: code)
        guard let client = auth.client else { return }
        self.session = session
        store = BoardStore(api: client)
        phase = .ready
        await refresh()
        startSocket()
    }

    func refresh() async {
        guard let store else { return }
        await store.refresh()
        if store.errorMessage == APIError.unauthorized.errorDescription { signOut() }
    }

    /// Several socket events in a row become one refresh.
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            await self?.refresh()
        }
    }

    private func startSocket() {
        socket?.stop()
        guard let session, let url = ServerConfig.webSocketURL(base: session.serverURL, workspaceId: session.workspaceId) else { return }
        let socket = LiveSocket(url: url, token: session.token) { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        socket.start()
        self.socket = socket
    }

    func stopSocket() { socket?.stop() }
    func resumeSocket() {
        guard session != nil else { return }
        startSocket()
        Task { await refresh() }
    }

    func signOut() {
        socket?.stop()
        socket = nil
        auth.signOut()
        store = nil
        session = nil
        phase = .onboarding
    }
}

/// Reads the saved server for the onboarding field.
enum SessionStoreAccess {
    static func savedServer() -> String {
        SessionStore(store: KeychainSecretStore()).savedServer() ?? ""
    }
}
