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
}
