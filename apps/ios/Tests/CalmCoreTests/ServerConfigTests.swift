import XCTest
@testable import CalmCore

final class ServerConfigTests: XCTestCase {
    func testAddsHttpsAndStripsSlash() throws {
        XCTAssertEqual(try ServerConfig.normalize("macbook.ts.net/").absoluteString, "https://macbook.ts.net")
    }

    func testRejectsEmptyAndInsecure() {
        XCTAssertThrowsError(try ServerConfig.normalize("  ")) { XCTAssertEqual($0 as? ServerConfigError, .empty) }
        XCTAssertThrowsError(try ServerConfig.normalize("http://example.com")) { XCTAssertEqual($0 as? ServerConfigError, .insecure) }
    }

    func testAllowsHttpLocalhost() throws {
        XCTAssertEqual(try ServerConfig.normalize("http://localhost:8080").absoluteString, "http://localhost:8080")
    }

    func testWebSocketURL() throws {
        let base = try ServerConfig.normalize("https://host.ts.net")
        XCTAssertEqual(ServerConfig.webSocketURL(base: base, workspaceId: "w1")?.absoluteString, "wss://host.ts.net/ws?workspace_id=w1")
    }
}
