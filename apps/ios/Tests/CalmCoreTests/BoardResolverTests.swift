import XCTest
@testable import CalmCore

final class BoardResolverTests: XCTestCase {
    private func statuses() throws -> [StatusEntry] {
        var list = try Fixture.decode("issue-statuses", as: StatusList.self).statuses
        list.append(StatusEntry(id: "bozza-id", key: "bozza", name: "Bozza", category: "unstarted", position: 9))
        return list
    }

    private func workflow() -> Workflow {
        Workflow(id: "wf1", name: "EMF Boutik", isDefault: false, steps: [
            WorkflowStep(statusKey: "todo"), WorkflowStep(statusKey: "bozza"),
            WorkflowStep(statusKey: "in_progress"), WorkflowStep(statusKey: "in_review"),
            WorkflowStep(statusKey: "done"), WorkflowStep(statusKey: "cancelled"),
        ])
    }

    func testCatalogColumnsWithoutWorkflow() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: nil, workflowsEnabled: true)
        XCTAssertEqual(resolver.columns.map(\.key).prefix(2), ["todo", "in_progress"])
        XCTAssertFalse(resolver.columns.contains { $0.key == "backlog" })
    }

    func testWorkflowColumnsFollowStepOrderAndDropCancelled() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: workflow(), workflowsEnabled: true)
        XCTAssertEqual(resolver.columns.map(\.key), ["todo", "bozza", "in_progress", "in_review", "done"])
    }

    func testDefaultWorkflowAndDisabledFlagUseCatalog() throws {
        let def = Workflow(id: "d", name: "Default", isDefault: true, steps: [WorkflowStep(statusKey: "done")])
        XCTAssertEqual(BoardResolver(statuses: try statuses(), workflow: def, workflowsEnabled: true).columns.first?.key, "todo")
        XCTAssertEqual(BoardResolver(statuses: try statuses(), workflow: workflow(), workflowsEnabled: false).columns.first?.key, "todo")
    }

    func testIssueOutsideColumnsFallsIntoSameCategory() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: workflow(), workflowsEnabled: true)
        // backlog is not a column of this workflow; it belongs to the unstarted category.
        let backlog = Issue(id: "1", title: "a", status: "backlog")
        XCTAssertEqual(resolver.column(for: backlog)?.key, "todo")
        // blocked is "started": first started column is in_progress.
        let blocked = Issue(id: "2", title: "b", status: "blocked")
        XCTAssertEqual(resolver.column(for: blocked)?.key, "in_progress")
    }

    func testClosedIssuesHaveNoColumn() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: workflow(), workflowsEnabled: true)
        XCTAssertNil(resolver.column(for: Issue(id: "3", title: "c", status: "cancelled")))
    }

    func testGroupSortsByPriority() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: nil, workflowsEnabled: false)
        let a = Issue(id: "a", title: "low", status: "todo", priority: "low")
        let b = Issue(id: "b", title: "urgent", status: "todo", priority: "urgent")
        XCTAssertEqual(resolver.group([a, b])["todo"]?.map(\.id), ["b", "a"])
    }

    func testTodayListsDueAndOverdueOpenIssues() throws {
        let resolver = BoardResolver(statuses: try statuses(), workflow: nil, workflowsEnabled: false)
        let issues = [
            Issue(id: "1", title: "late", status: "todo", dueDate: "2026-10-18"),
            Issue(id: "2", title: "today", status: "in_progress", dueDate: "2026-10-20"),
            Issue(id: "3", title: "future", status: "todo", dueDate: "2026-10-25"),
            Issue(id: "4", title: "done", status: "done", dueDate: "2026-10-19"),
            Issue(id: "5", title: "none", status: "todo"),
        ]
        XCTAssertEqual(Today.dueOrOverdue(issues, resolver: resolver, today: "2026-10-20").map(\.id), ["1", "2"])
    }
}
