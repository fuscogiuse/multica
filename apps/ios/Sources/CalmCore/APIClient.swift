import Foundation

public enum APIError: Error, Equatable, LocalizedError {
    case unauthorized
    case http(status: Int, message: String)
    case decoding(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Sessione scaduta. Accedi di nuovo."
        case .http(_, let message): return message
        case .decoding: return "Risposta del server non valida."
        case .network: return "Il Mac non risponde. Controlla Tailscale."
        }
    }
}

/// Minimal Multica API client. Sends the bearer token and the workspace id on every call.
public final class APIClient: @unchecked Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let lock = NSLock()
    private var _token: String?
    private var _workspaceId: String?

    public var token: String? {
        get { lock.lock(); defer { lock.unlock() }; return _token }
        set { lock.lock(); _token = newValue; lock.unlock() }
    }

    public var workspaceId: String? {
        get { lock.lock(); defer { lock.unlock() }; return _workspaceId }
        set { lock.lock(); _workspaceId = newValue; lock.unlock() }
    }

    public init(baseURL: URL, token: String? = nil, workspaceId: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self._token = token
        self._workspaceId = workspaceId
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    public func makeRequest(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil) -> URLRequest {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        parts.path = path
        parts.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: parts.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let workspaceId { request.setValue(workspaceId, forHTTPHeaderField: "X-Workspace-ID") }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network("no response") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, message: Self.errorMessage(from: data, status: http.statusCode))
        }
        return data
    }

    static func errorMessage(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["error"] as? String, !message.isEmpty { return message }
            if let message = object["message"] as? String, !message.isEmpty { return message }
        }
        return "Errore del server (\(status))."
    }

    public func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type = T.self) async throws -> T {
        let data = try await send(makeRequest("GET", path, query: query))
        return try decode(data)
    }

    public func post<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type = T.self) async throws -> T {
        let data = try await send(makeRequest("POST", path, body: try APIClient.encoder.encode(body)))
        return try decode(data)
    }

    public func put<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type = T.self) async throws -> T {
        let data = try await send(makeRequest("PUT", path, body: try APIClient.encoder.encode(body)))
        return try decode(data)
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try APIClient.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

// MARK: - Endpoints

public struct CreateIssueBody: Encodable, Sendable {
    public var title: String
    public var description: String?
    public var status: String
    public var priority: String
    public var projectId: String?
    public var dueDate: String?

    public init(title: String, description: String? = nil, status: String = "todo",
                priority: String = "none", projectId: String? = nil, dueDate: String? = nil) {
        self.title = title; self.description = description; self.status = status
        self.priority = priority; self.projectId = projectId; self.dueDate = dueDate
    }
}

public struct UpdateIssueBody: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var status: String?
    public var priority: String?
    public var dueDate: String?
    /// Sends `"due_date": null`, which removes the due date.
    public var clearDueDate = false

    public init(title: String? = nil, description: String? = nil, status: String? = nil,
                priority: String? = nil, dueDate: String? = nil, clearDueDate: Bool = false) {
        self.title = title; self.description = description; self.status = status
        self.priority = priority; self.dueDate = dueDate; self.clearDueDate = clearDueDate
    }

    private enum CodingKeys: String, CodingKey {
        case title, description, status, priority
        case dueDate = "due_date"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(priority, forKey: .priority)
        if clearDueDate {
            try c.encodeNil(forKey: .dueDate)
        } else {
            try c.encodeIfPresent(dueDate, forKey: .dueDate)
        }
    }
}

struct CommentBody: Encodable {
    var content: String
    var type: String = "comment"
}

struct SendCodeBody: Encodable { var email: String }
struct VerifyCodeBody: Encodable { var email: String; var code: String }

extension APIClient {
    public func config() async throws -> AppConfig { try await get("/api/config") }
    public func workspaces() async throws -> [Workspace] {
        try await get("/api/workspaces")
    }
    public func companies() async throws -> [Company] { (try await get("/api/companies", as: CompanyList.self)).companies }
    public func projects() async throws -> [Project] { (try await get("/api/projects", as: ProjectList.self)).projects }
    public func statuses() async throws -> [StatusEntry] {
        (try await get("/api/issue-statuses", query: [URLQueryItem(name: "include_archived", value: "true")], as: StatusList.self)).statuses
    }
    public func workflows() async throws -> [Workflow] { (try await get("/api/issue-workflows", as: WorkflowList.self)).workflows }

    /// All issues, paged 100 at a time, up to `maxPages` pages.
    public func issues(includeClosed: Bool = true, maxPages: Int = 10) async throws -> [Issue] {
        var all: [Issue] = []
        for page in 0..<maxPages {
            let query = [
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "offset", value: String(page * 100)),
                URLQueryItem(name: "include_closed", value: includeClosed ? "true" : "false"),
            ]
            let list: IssueList = try await get("/api/issues", query: query)
            all.append(contentsOf: list.issues)
            if list.issues.count < 100 { break }
        }
        return all
    }

    public func issue(id: String) async throws -> Issue { try await get("/api/issues/\(id)") }
    public func createIssue(_ body: CreateIssueBody) async throws -> Issue { try await post("/api/issues", body: body) }
    public func updateIssue(id: String, _ body: UpdateIssueBody) async throws -> Issue { try await put("/api/issues/\(id)", body: body) }
    public func deleteIssue(id: String) async throws {
        _ = try await send(makeRequest("DELETE", "/api/issues/\(id)"))
    }
    public func comments(issueId: String) async throws -> [Comment] { try await get("/api/issues/\(issueId)/comments") }
    public func addComment(issueId: String, content: String) async throws -> Comment {
        try await post("/api/issues/\(issueId)/comments", body: CommentBody(content: content))
    }
    public func sendCode(email: String) async throws {
        let body = try APIClient.encoder.encode(SendCodeBody(email: email))
        _ = try await send(makeRequest("POST", "/auth/send-code", body: body))
    }
    public func verifyCode(email: String, code: String) async throws -> String {
        let response: LoginResponse = try await post("/auth/verify-code", body: VerifyCodeBody(email: email, code: code))
        return response.token
    }
}
