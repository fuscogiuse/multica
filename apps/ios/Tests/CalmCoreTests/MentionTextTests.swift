import XCTest
@testable import CalmCore

final class MentionTextTests: XCTestCase {
    private let operatore = Mentionable(kind: .agent, id: "22b9717e-67e5-4c88-bb7b-a836b9dfd55b", name: "Operatore")
    private let giuseppe = Mentionable(kind: .member, id: "579bccd1-7939-416f-8b9f-f732676e8533", name: "Giuseppe")

    func testMarkupMatchesWhatTheServerReads() {
        XCTAssertEqual(operatore.markup, "[@Operatore](mention://agent/22b9717e-67e5-4c88-bb7b-a836b9dfd55b)")
    }

    func testActiveQueryAfterAt() {
        XCTAssertEqual(MentionText.activeQuery(in: "ciao @ope")?.text, "ope")
        XCTAssertEqual(MentionText.activeQuery(in: "@")?.text, "")
    }

    func testNoQueryInsideWordOrAfterSpace() {
        XCTAssertNil(MentionText.activeQuery(in: "mario@example.com"))
        XCTAssertNil(MentionText.activeQuery(in: "ciao @operatore e poi"))
        XCTAssertNil(MentionText.activeQuery(in: "nessuna menzione"))
    }

    func testSuggestionsPreferPrefix() {
        let list = [giuseppe, operatore, Mentionable(kind: .agent, id: "x", name: "Co-operatore")]
        XCTAssertEqual(MentionText.suggestions(list, matching: "ope").map(\.name), ["Operatore", "Co-operatore"])
        XCTAssertEqual(MentionText.suggestions(list, matching: "").count, 3)
    }

    func testInsertingAndConvertingBack() throws {
        let typed = "ciao @ope"
        let query = try XCTUnwrap(MentionText.activeQuery(in: typed))
        let text = MentionText.inserting(operatore, over: query, in: typed)
        XCTAssertEqual(text, "ciao @Operatore ")
        let sent = MentionText.toMarkup(text + "fai questo", mentions: [operatore])
        XCTAssertEqual(sent, "ciao [@Operatore](mention://agent/22b9717e-67e5-4c88-bb7b-a836b9dfd55b) fai questo")
    }

    func testTwoMentionsAndLongestNameFirst() {
        let long = Mentionable(kind: .agent, id: "aa", name: "Operatore Due")
        let sent = MentionText.toMarkup("@Operatore Due e @Operatore", mentions: [operatore, long])
        XCTAssertEqual(sent, "[@Operatore Due](mention://agent/aa) e [@Operatore](mention://agent/22b9717e-67e5-4c88-bb7b-a836b9dfd55b)")
    }

    func testSegmentsSplitTextAndMentions() {
        let markup = "Per favore [@Operatore](mention://agent/22b9717e-67e5-4c88-bb7b-a836b9dfd55b) controlla."
        XCTAssertEqual(MentionText.segments(markup), [
            .text("Per favore "),
            .mention(name: "Operatore", kind: "agent"),
            .text(" controlla."),
        ])
        XCTAssertEqual(MentionText.segments("niente"), [.text("niente")])
    }
}
