import XCTest
@testable import CalmCore

final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, data) = StubProtocol.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return APIClient(baseURL: URL(string: "https://host.ts.net")!, token: "tok", workspaceId: "ws1",
                         session: URLSession(configuration: config))
    }

    func testSendsAuthAndWorkspaceHeaders() async throws {
        var seen: URLRequest?
        StubProtocol.handler = { request in
            seen = request
            return (200, #"{"companies":[]}"#.data(using: .utf8)!)
        }
        _ = try await makeClient().companies()
        XCTAssertEqual(seen?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(seen?.value(forHTTPHeaderField: "X-Workspace-ID"), "ws1")
        XCTAssertEqual(seen?.url?.path, "/api/companies")
    }

    func testUnauthorizedMapsToError() async {
        StubProtocol.handler = { _ in (401, Data()) }
        do {
            _ = try await makeClient().projects()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
    }

    func testServerMessageIsSurfaced() async {
        StubProtocol.handler = { _ in (400, #"{"error":"status not allowed"}"#.data(using: .utf8)!) }
        do {
            _ = try await makeClient().updateIssue(id: "i1", UpdateIssueBody(status: "x"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? APIError, .http(status: 400, message: "status not allowed"))
        }
    }

    func testIssuesPaginateUntilShortPage() async throws {
        var offsets: [String] = []
        StubProtocol.handler = { request in
            let comps = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let offset = comps.queryItems?.first { $0.name == "offset" }?.value ?? "0"
            offsets.append(offset)
            let count = offset == "0" ? 100 : 3
            let items = (0..<count).map { #"{"id":"i\#(offset)-\#($0)","title":"t","status":"todo"}"# }.joined(separator: ",")
            return (200, #"{"issues":[\#(items)],"total":103}"#.data(using: .utf8)!)
        }
        let all = try await makeClient().issues()
        XCTAssertEqual(all.count, 103)
        XCTAssertEqual(offsets, ["0", "100"])
    }

    func testUpdateIssueEncodesSnakeCase() async throws {
        var body: [String: Any]?
        StubProtocol.handler = { request in
            let stream = request.httpBodyStream
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream {
                stream.open()
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buffer, maxLength: buffer.count)
                    if n <= 0 { break }
                    data.append(buffer, count: n)
                }
                stream.close()
            }
            body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (200, #"{"id":"i1","title":"t","status":"done"}"#.data(using: .utf8)!)
        }
        _ = try await makeClient().updateIssue(id: "i1", UpdateIssueBody(status: "done", dueDate: "2026-10-21"))
        XCTAssertEqual(body?["status"] as? String, "done")
        XCTAssertEqual(body?["due_date"] as? String, "2026-10-21")
        XCTAssertNil(body?["title"])
    }
}
