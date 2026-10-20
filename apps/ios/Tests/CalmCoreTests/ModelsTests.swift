import XCTest
@testable import CalmCore

final class ModelsTests: XCTestCase {
    func testIssuesDecode() throws {
        let list: IssueList = try Fixture.decode("issues")
        XCTAssertFalse(list.issues.isEmpty)
        XCTAssertTrue(list.issues.contains { $0.identifier.hasPrefix("SLD-") })
    }

    func testProjectsAndCompaniesDecode() throws {
        let projects: ProjectList = try Fixture.decode("projects")
        XCTAssertFalse(projects.projects.isEmpty)
        let companies: CompanyList = try Fixture.decode("companies")
        XCTAssertEqual(companies.companies.first?.name, "SOLID")
    }

    func testStatusesDecodeWithItalianNames() throws {
        let list: StatusList = try Fixture.decode("issue-statuses")
        XCTAssertEqual(list.statuses.first { $0.key == "todo" }?.name, "Da fare")
        XCTAssertEqual(list.statuses.first { $0.key == "in_progress" }?.name, "In corso")
    }

    func testWorkflowsDecode() throws {
        let list: WorkflowList = try Fixture.decode("issue-workflows")
        let def = list.workflows.first { $0.isDefault }
        XCTAssertNotNil(def)
        XCTAssertEqual(def?.steps.first?.statusKey, "backlog")
    }

    func testWorkspacesDecodeAsPlainArray() throws {
        let data = try Fixture.data("workspaces")
        let list = try APIClient.decoder.decode([Workspace].self, from: data)
        XCTAssertEqual(list.first?.slug, "solid")
    }

    func testIssueToleratesMissingAndExtraKeys() throws {
        let json = #"{"id":"x1","title":"Hello","status":"todo","brand_new_field":{"a":1}}"#.data(using: .utf8)!
        let issue = try APIClient.decoder.decode(Issue.self, from: json)
        XCTAssertEqual(issue.id, "x1")
        XCTAssertEqual(issue.priority, "none")
        XCTAssertNil(issue.dueDay)
    }

    func testDueDayAcceptsDateAndTimestamp() {
        XCTAssertEqual(Issue(id: "1", title: "a", status: "todo", dueDate: "2026-10-21").dueDay, "2026-10-21")
        XCTAssertEqual(Issue(id: "1", title: "a", status: "todo", dueDate: "2026-10-21T00:00:00Z").dueDay, "2026-10-21")
    }

    func testConfigFlag() throws {
        let json = #"{"feature_flags":{"project_workflows_v1":true}}"#.data(using: .utf8)!
        XCTAssertTrue(try APIClient.decoder.decode(AppConfig.self, from: json).projectWorkflowsEnabled)
        let off = #"{}"#.data(using: .utf8)!
        XCTAssertFalse(try APIClient.decoder.decode(AppConfig.self, from: off).projectWorkflowsEnabled)
    }
}
