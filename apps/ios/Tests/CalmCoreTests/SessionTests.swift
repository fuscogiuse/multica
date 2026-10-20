import XCTest
@testable import CalmCore

final class SessionTests: XCTestCase {
    func testSaveLoadAndClear() {
        let sessions = SessionStore(store: InMemorySecretStore())
        XCTAssertNil(sessions.load())
        let session = Session(serverURL: URL(string: "https://host.ts.net")!, token: "t", workspaceId: "w")
        sessions.save(session)
        XCTAssertEqual(sessions.load(), session)
        sessions.clearToken()
        XCTAssertNil(sessions.load())
        XCTAssertEqual(sessions.savedServer(), "https://host.ts.net")
    }
}
