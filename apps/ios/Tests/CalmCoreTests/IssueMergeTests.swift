import XCTest
@testable import CalmCore

final class IssueMergeTests: XCTestCase {
    private func comment(_ content: String, author: String = "member", type: String = "comment") throws -> Comment {
        let json = #"{"id":"c\#(content.count)","author_type":"\#(author)","content":"\#(content)","type":"\#(type)"}"#
        return try APIClient.decoder.decode(Comment.self, from: Data(json.utf8))
    }

    func testDescriptionKeepsBothContexts() throws {
        let target = Issue(id: "t", identifier: "SLD-38", title: "Lancio casco", description: "Note del lancio", status: "todo")
        let source = Issue(id: "s", identifier: "SLD-12", title: "Report Meta", description: "Numeri di ottobre", status: "todo")
        let text = IssueMerge.mergedDescription(target: target, source: source,
                                                sourceComments: [try comment("Fatto il primo giro", author: "agent"),
                                                                 try comment("run failed", type: "system")])
        XCTAssertTrue(text.hasPrefix("Note del lancio"))
        XCTAssertTrue(text.contains("**Unito da SLD-12: Report Meta**"))
        XCTAssertTrue(text.contains("Numeri di ottobre"))
        XCTAssertTrue(text.contains("- Agente: Fatto il primo giro"))
        XCTAssertFalse(text.contains("run failed"))
    }

    func testEmptyTargetNotes() {
        let target = Issue(id: "t", title: "A", status: "todo")
        let source = Issue(id: "s", identifier: "SLD-2", title: "B", status: "todo")
        XCTAssertTrue(IssueMerge.mergedDescription(target: target, source: source, sourceComments: []).hasPrefix("---"))
    }

    func testPriorityAndDue() {
        let a = Issue(id: "a", title: "a", status: "todo", priority: "low", dueDate: "2026-11-02")
        let b = Issue(id: "b", title: "b", status: "todo", priority: "urgent", dueDate: "2026-10-24")
        XCTAssertEqual(IssueMerge.mergedPriority(a, b), "urgent")
        XCTAssertEqual(IssueMerge.mergedDueDay(a, b), "2026-10-24")
        XCTAssertNil(IssueMerge.mergedDueDay(Issue(id: "x", title: "x", status: "todo"), Issue(id: "y", title: "y", status: "todo")))
    }
}
