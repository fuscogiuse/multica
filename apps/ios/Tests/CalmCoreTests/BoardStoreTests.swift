import XCTest
@testable import CalmCore

final class FakeAPI: BoardAPI {
    var issuesToReturn: [Issue] = []
    var failUpdate = false
    var statusesToReturn: [StatusEntry] = []

    func config() async throws -> AppConfig { AppConfig(featureFlags: ["project_workflows_v1": true]) }
    func companies() async throws -> [Company] { [] }
    func projects() async throws -> [Project] { [] }
    func statuses() async throws -> [StatusEntry] { statusesToReturn }
    func workflows() async throws -> [Workflow] { [] }
    func issues(includeClosed: Bool, maxPages: Int) async throws -> [Issue] { issuesToReturn }
    func updateIssue(id: String, _ body: UpdateIssueBody) async throws -> Issue {
        if failUpdate { throw APIError.http(status: 400, message: "not allowed") }
        var issue = issuesToReturn.first { $0.id == id }!
        if let status = body.status { issue.status = status }
        return issue
    }
    func createIssue(_ body: CreateIssueBody) async throws -> Issue {
        Issue(id: "new", title: body.title, status: body.status)
    }
    var failDelete = false
    func deleteIssue(id: String) async throws {
        if failDelete { throw APIError.http(status: 403, message: "no") }
    }
}

@MainActor
final class BoardStoreTests: XCTestCase {
    func testRefreshLoadsIssuesAndFlag() async throws {
        let api = FakeAPI()
        api.issuesToReturn = [Issue(id: "1", title: "a", status: "todo")]
        let store = BoardStore(api: api)
        await store.refresh()
        XCTAssertTrue(store.hasLoaded)
        XCTAssertTrue(store.workflowsEnabled)
        XCTAssertEqual(store.issues.count, 1)
    }

    func testMoveUpdatesIssue() async {
        let api = FakeAPI()
        api.issuesToReturn = [Issue(id: "1", title: "a", status: "todo")]
        let store = BoardStore(api: api)
        await store.refresh()
        await store.move(store.issues[0], to: "in_progress")
        XCTAssertEqual(store.issues[0].status, "in_progress")
        XCTAssertNil(store.errorMessage)
    }

    func testFailedMoveRollsBackAndShowsMessage() async {
        let api = FakeAPI()
        api.issuesToReturn = [Issue(id: "1", title: "a", status: "todo")]
        let store = BoardStore(api: api)
        await store.refresh()
        api.failUpdate = true
        await store.move(store.issues[0], to: "done")
        XCTAssertEqual(store.issues[0].status, "todo")
        XCTAssertEqual(store.errorMessage, "not allowed")
    }

    func testCreateInsertsAtTop() async {
        let store = BoardStore(api: FakeAPI())
        let created = await store.create(CreateIssueBody(title: "New"))
        XCTAssertEqual(created?.title, "New")
        XCTAssertEqual(store.issues.first?.id, "new")
    }

    func testDeleteRemovesAndRollsBack() async {
        let api = FakeAPI()
        api.issuesToReturn = [Issue(id: "1", title: "a", status: "todo"), Issue(id: "2", title: "b", status: "todo")]
        let store = BoardStore(api: api)
        await store.refresh()
        await store.delete(store.issues[0])
        XCTAssertEqual(store.issues.map(\.id), ["2"])
        api.failDelete = true
        await store.delete(store.issues[0])
        XCTAssertEqual(store.issues.map(\.id), ["2"])
        XCTAssertEqual(store.errorMessage, "no")
    }
}
