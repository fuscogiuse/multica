import Foundation
import CalmCore

/// Sample data for screenshots and previews. Launch with `-demo`.
final class DemoAPI: BoardAPI {
    private var issueList: [Issue]

    init() {
        let today = Today.dayString()
        let past = DateText.day(from: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        let later = DateText.day(from: Calendar.current.date(byAdding: .day, value: 5, to: Date())!)
        issueList = [
            Issue(id: "i1", identifier: "SLD-1", title: "Rivedere le descrizioni dei prodotti", status: "todo", priority: "high", projectId: "p1", dueDate: today),
            Issue(id: "i2", identifier: "SLD-2", title: "Bozza newsletter di novembre", status: "bozza", priority: "medium", projectId: "p1"),
            Issue(id: "i3", identifier: "SLD-3", title: "Aggiornare le immagini della home", status: "in_progress", priority: "urgent", assigneeType: "agent", projectId: "p1", dueDate: past),
            Issue(id: "i4", identifier: "SLD-4", title: "Controllare il checkout su mobile", status: "in_review", priority: "low", projectId: "p1", dueDate: later),
            Issue(id: "i5", identifier: "SLD-5", title: "Configurare il pixel", status: "done", projectId: "p1"),
            Issue(id: "i6", identifier: "SLD-6", title: "Nuovo logo per il sito vetrina", status: "todo", priority: "medium", projectId: "p2"),
            Issue(id: "i7", identifier: "SLD-7", title: "Testi della pagina contatti", status: "in_progress", projectId: "p2", dueDate: today),
            Issue(id: "i8", identifier: "SLD-8", title: "Prenotare il dominio", status: "backlog", projectId: "p2"),
        ]
    }

    func config() async throws -> AppConfig {
        try APIClient.decoder.decode(AppConfig.self, from: Data(#"{"feature_flags":{"project_workflows_v1":true}}"#.utf8))
    }

    func companies() async throws -> [Company] {
        [Company(id: "c1", name: "SOLID", color: "#dc4c3e", position: 0),
         Company(id: "c2", name: "NewTarget", color: "#eb8909", position: 1)]
    }

    func projects() async throws -> [Project] {
        [Project(id: "p1", title: "EMF Boutik", workflowId: "w1", companyId: "c1"),
         Project(id: "p2", title: "Sito vetrina", companyId: "c2")]
    }

    func statuses() async throws -> [StatusEntry] {
        [
            StatusEntry(id: "s1", key: "todo", name: "Da fare", category: "todo", color: "#6b7280", isSystem: true, position: 1),
            StatusEntry(id: "s2", key: "in_progress", name: "In corso", category: "in_progress", color: "#eb8909", isSystem: true, position: 2),
            StatusEntry(id: "s3", key: "in_review", name: "In revisione", category: "in_review", color: "#058527", isSystem: true, position: 3),
            StatusEntry(id: "s4", key: "done", name: "Fatto", category: "done", color: "#246fe0", isSystem: true, position: 4),
            StatusEntry(id: "s5", key: "backlog", name: "Backlog", category: "backlog", color: "#6b7280", isSystem: true, position: 5, boardHidden: true),
            StatusEntry(id: "s6", key: "blocked", name: "Bloccato", category: "blocked", color: "#d1453b", isSystem: true, position: 6, boardHidden: true),
            StatusEntry(id: "s7", key: "cancelled", name: "Annullato", category: "cancelled", color: "#6b7280", isSystem: true, position: 7, boardHidden: true),
            StatusEntry(id: "s8", key: "bozza", name: "Bozza", category: "unstarted", color: "#8b5cf6", isSystem: false, position: 8),
        ]
    }

    func workflows() async throws -> [Workflow] {
        [
            Workflow(id: "w0", name: "Default", isDefault: true, steps: [WorkflowStep(statusKey: "todo")]),
            Workflow(id: "w1", name: "EMF Boutik", isDefault: false, steps: [
                WorkflowStep(statusKey: "todo"), WorkflowStep(statusKey: "bozza"), WorkflowStep(statusKey: "in_progress"),
                WorkflowStep(statusKey: "in_review"), WorkflowStep(statusKey: "done"), WorkflowStep(statusKey: "cancelled"),
            ]),
        ]
    }

    func issues(includeClosed: Bool, maxPages: Int) async throws -> [Issue] { issueList }

    func updateIssue(id: String, _ body: UpdateIssueBody) async throws -> Issue {
        guard let index = issueList.firstIndex(where: { $0.id == id }) else { throw APIError.http(status: 404, message: "Non trovato") }
        if let status = body.status { issueList[index].status = status }
        if let title = body.title { issueList[index].title = title }
        if let priority = body.priority { issueList[index].priority = priority }
        return issueList[index]
    }

    func createIssue(_ body: CreateIssueBody) async throws -> Issue {
        let issue = Issue(id: UUID().uuidString, identifier: "SLD-\(issueList.count + 1)", title: body.title,
                          status: body.status, priority: body.priority, projectId: body.projectId, dueDate: body.dueDate)
        issueList.insert(issue, at: 0)
        return issue
    }
}
