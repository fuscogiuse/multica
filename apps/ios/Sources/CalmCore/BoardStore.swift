import Foundation
import Combine

/// The calls the store needs. `APIClient` implements them; tests use a fake.
public protocol BoardAPI: AnyObject {
    func config() async throws -> AppConfig
    func companies() async throws -> [Company]
    func projects() async throws -> [Project]
    func statuses() async throws -> [StatusEntry]
    func workflows() async throws -> [Workflow]
    func issues(includeClosed: Bool, maxPages: Int) async throws -> [Issue]
    func updateIssue(id: String, _ body: UpdateIssueBody) async throws -> Issue
    func createIssue(_ body: CreateIssueBody) async throws -> Issue
    func deleteIssue(id: String) async throws
}

extension APIClient: BoardAPI {}

/// Everything the screens read, plus the writes (move, create, edit).
@MainActor
public final class BoardStore: ObservableObject {
    @Published public private(set) var companies: [Company] = []
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var statuses: [StatusEntry] = []
    @Published public private(set) var workflows: [Workflow] = []
    @Published public private(set) var issues: [Issue] = [] { didSet { recomputeCounts() } }
    /// Open tasks per project, ready for the sidebar so it does no work while it animates.
    @Published public private(set) var openCounts: [String: Int] = [:]
    @Published public private(set) var todayCount = 0
    @Published public private(set) var allOpenCount = 0
    @Published public private(set) var workflowsEnabled = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasLoaded = false
    @Published public var errorMessage: String?

    private let api: BoardAPI

    public init(api: BoardAPI) { self.api = api }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let config = api.config()
            async let companies = api.companies()
            async let projects = api.projects()
            async let statuses = api.statuses()
            async let workflows = api.workflows()
            async let issues = api.issues(includeClosed: true, maxPages: 10)
            let (c, co, p, s, w, i) = try await (config, companies, projects, statuses, workflows, issues)
            workflowsEnabled = c.projectWorkflowsEnabled
            self.companies = co.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            self.projects = p
            self.statuses = s
            self.workflows = w
            self.issues = i
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func recomputeCounts() {
        var counts: [String: Int] = [:]
        for project in projects {
            let resolver = resolver(for: project)
            counts[project.id] = issues.filter { $0.projectId == project.id && resolver.column(for: $0) != nil }.count
        }
        openCounts = counts
        let catalog = resolver(for: nil)
        allOpenCount = issues.filter { catalog.column(for: $0) != nil }.count
        todayCount = Today.dueOrOverdue(issues, resolver: catalog, today: Today.dayString()).count
    }

    // MARK: Lookups

    public func project(_ id: String?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    public func company(of project: Project?) -> Company? {
        guard let id = project?.companyId else { return nil }
        return companies.first { $0.id == id }
    }

    public func projects(in company: Company?) -> [Project] {
        guard let company else { return projects.filter { $0.companyId == nil } }
        return projects.filter { $0.companyId == company.id }
    }

    public func workflow(for project: Project?) -> Workflow? {
        guard let project else { return nil }
        if let id = project.workflowId, let named = workflows.first(where: { $0.id == id }) { return named }
        return workflows.first { $0.isDefault }
    }

    /// Columns for a project, or for the catalog when no project is in view.
    public func resolver(for project: Project?) -> BoardResolver {
        BoardResolver(statuses: statuses, workflow: workflow(for: project), workflowsEnabled: workflowsEnabled && project != nil)
    }

    public func issues(in project: Project?) -> [Issue] {
        guard let project else { return issues }
        return issues.filter { $0.projectId == project.id }
    }

    public func issues(in company: Company) -> [Issue] {
        let ids = Set(projects(in: company).map(\.id))
        return issues.filter { $0.projectId.map(ids.contains) ?? false }
    }

    // MARK: Writes

    /// Moves an issue to a status, showing the change at once and undoing it on failure.
    public func move(_ issue: Issue, to statusKey: String) async {
        guard issue.status != statusKey, let index = issues.firstIndex(where: { $0.id == issue.id }) else { return }
        let before = issues[index]
        issues[index].status = statusKey
        do {
            let updated = try await api.updateIssue(id: issue.id, UpdateIssueBody(status: statusKey))
            if let i = issues.firstIndex(where: { $0.id == issue.id }) { issues[i] = updated }
        } catch {
            if let i = issues.firstIndex(where: { $0.id == issue.id }) { issues[i] = before }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func update(_ issue: Issue, _ body: UpdateIssueBody) async {
        do {
            let updated = try await api.updateIssue(id: issue.id, body)
            if let i = issues.firstIndex(where: { $0.id == issue.id }) { issues[i] = updated }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Deletes an issue, hiding it at once and putting it back if the server refuses.
    public func delete(_ issue: Issue) async {
        guard let index = issues.firstIndex(where: { $0.id == issue.id }) else { return }
        let removed = issues[index]
        issues.remove(at: index)
        do {
            try await api.deleteIssue(id: issue.id)
        } catch {
            issues.insert(removed, at: min(index, issues.count))
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @discardableResult
    public func create(_ body: CreateIssueBody) async -> Issue? {
        do {
            let created = try await api.createIssue(body)
            issues.insert(created, at: 0)
            return created
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}
