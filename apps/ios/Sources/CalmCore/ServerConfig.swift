import Foundation

public enum ServerConfigError: Error, Equatable {
    case empty
    case invalid
    case insecure
}

/// The Multica server address. HTTPS is required except for localhost.
public enum ServerConfig {
    /// Turns what the user typed into a base URL, or throws.
    public static func normalize(_ input: String) throws -> URL {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw ServerConfigError.empty }
        if !text.contains("://") { text = "https://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), let host = url.host, !host.isEmpty else {
            throw ServerConfigError.invalid
        }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "https" { return url }
        if scheme == "http", isLocalhost(host) { return url }
        throw ServerConfigError.insecure
    }

    static func isLocalhost(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".localhost")
    }

    /// The WebSocket address for the same server.
    public static func webSocketURL(base: URL, workspaceId: String) -> URL? {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = (parts.scheme == "http") ? "ws" : "wss"
        parts.path = "/ws"
        parts.queryItems = [URLQueryItem(name: "workspace_id", value: workspaceId)]
        return parts.url
    }
}
