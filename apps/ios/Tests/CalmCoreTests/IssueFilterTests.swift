import XCTest
@testable import CalmCore

final class IssueFilterTests: XCTestCase {
    private let projects = [
        Project(id: "p1", title: "A", companyId: "c1"),
        Project(id: "p2", title: "B", companyId: "c2"),
    ]
    private let issues = [
        Issue(id: "1", title: "a", status: "todo", projectId: "p1"),
        Issue(id: "2", title: "b", status: "todo", projectId: "p2"),
        Issue(id: "3", title: "c", status: "todo"),
    ]

    func testNoFilterKeepsEverything() {
        XCTAssertEqual(IssueFilter().apply(issues, projects: projects).count, 3)
        XCTAssertFalse(IssueFilter().isActive)
    }

    func testCompanyFilter() {
        XCTAssertEqual(IssueFilter(companyId: "c1").apply(issues, projects: projects).map(\.id), ["1"])
    }

    func testProjectFilter() {
        XCTAssertEqual(IssueFilter(projectId: "p2").apply(issues, projects: projects).map(\.id), ["2"])
    }

    func testCompanyAndProjectMustAgree() {
        XCTAssertTrue(IssueFilter(companyId: "c1", projectId: "p2").apply(issues, projects: projects).isEmpty)
    }

    func testResolverRestrictingToOneStatus() throws {
        let statuses = try Fixture.decode("issue-statuses", as: StatusList.self).statuses
        let resolver = BoardResolver(statuses: statuses, workflow: nil, workflowsEnabled: false)
        XCTAssertEqual(resolver.restricting(to: "in_progress").columns.map(\.key), ["in_progress"])
        XCTAssertEqual(resolver.restricting(to: nil).columns.count, resolver.columns.count)
        XCTAssertEqual(resolver.restricting(to: "nope").columns.count, resolver.columns.count)
    }

    func testDueFilters() {
        let list = [
            Issue(id: "a", title: "late", status: "todo", dueDate: "2026-10-18"),
            Issue(id: "b", title: "today", status: "todo", dueDate: "2026-10-20"),
            Issue(id: "c", title: "soon", status: "todo", dueDate: "2026-10-24"),
            Issue(id: "d", title: "far", status: "todo", dueDate: "2026-11-30"),
            Issue(id: "e", title: "none", status: "todo"),
        ]
        func ids(_ due: DueFilter) -> [String] {
            IssueFilter(due: due).apply(list, projects: [], today: "2026-10-20").map(\.id)
        }
        XCTAssertEqual(ids(.overdue), ["a"])
        XCTAssertEqual(ids(.today), ["b"])
        XCTAssertEqual(ids(.week), ["b", "c"])
        XCTAssertEqual(ids(.undated), ["e"])
    }

    func testFiltersCombine() {
        let list = [
            Issue(id: "1", title: "a", status: "todo", projectId: "p1", dueDate: "2026-10-20"),
            Issue(id: "2", title: "b", status: "todo", projectId: "p1"),
            Issue(id: "3", title: "c", status: "todo", projectId: "p2", dueDate: "2026-10-20"),
        ]
        let filter = IssueFilter(companyId: "c1", due: .today)
        XCTAssertEqual(filter.apply(list, projects: projects, today: "2026-10-20").map(\.id), ["1"])
        XCTAssertTrue(filter.isActive)
    }
}
