import Foundation

/// Someone or something a comment can mention: an agent or a member.
public struct Mentionable: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case agent, member }

    public let kind: Kind
    public let id: String
    public let name: String

    public init(kind: Kind, id: String, name: String) {
        self.kind = kind; self.id = id; self.name = name
    }

    /// The markup the server reads to start an agent: `[@Name](mention://agent/<uuid>)`.
    public var markup: String { "[@\(name)](mention://\(kind.rawValue)/\(id))" }
}

public struct AgentRef: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var archivedAt: String?
}

public struct MemberRef: Codable, Hashable, Sendable {
    public var userId: String
    public var name: String
}

/// @mention helpers for the comment composer and for showing comments.
public enum MentionText {
    public struct Query: Equatable {
        public let range: Range<String.Index>
        public let text: String
    }

    /// The `@word` the user is typing at the end of `text`, if any. It must start a word and contain no space yet.
    public static func activeQuery(in text: String) -> Query? {
        guard let at = text.lastIndex(of: "@") else { return nil }
        if at > text.startIndex {
            let previous = text[text.index(before: at)]
            guard previous.isWhitespace else { return nil }
        }
        let after = text[text.index(after: at)...]
        if after.contains(where: { $0.isWhitespace }) { return nil }
        return Query(range: at..<text.endIndex, text: String(after))
    }

    /// People matching what was typed, names that start with it first.
    public static func suggestions(_ all: [Mentionable], matching query: String, limit: Int = 5) -> [Mentionable] {
        let q = query.lowercased()
        let starts = all.filter { $0.name.lowercased().hasPrefix(q) }
        let contains = all.filter { !$0.name.lowercased().hasPrefix(q) && $0.name.lowercased().contains(q) }
        return Array((starts + contains).prefix(limit))
    }

    /// Replaces the typed `@word` with `@Name ` so the composer shows a readable name.
    public static func inserting(_ mention: Mentionable, over query: Query, in text: String) -> String {
        text.replacingCharacters(in: query.range, with: "@\(mention.name) ")
    }

    /// Turns the readable `@Name` tokens back into the markup the server understands.
    public static func toMarkup(_ text: String, mentions: [Mentionable]) -> String {
        var result = text
        var markups: [String] = []
        for mention in mentions.sorted(by: { $0.name.count > $1.name.count }) {
            let token = "@\(mention.name)"
            guard result.contains(token) else { continue }
            let placeholder = "\u{1}\(markups.count)\u{2}"
            markups.append(mention.markup)
            result = result.replacingOccurrences(of: token, with: placeholder)
        }
        for (index, markup) in markups.enumerated() {
            result = result.replacingOccurrences(of: "\u{1}\(index)\u{2}", with: markup)
        }
        return result
    }

    public enum Segment: Equatable {
        case text(String)
        case mention(name: String, kind: String)
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"\[@?(.+?)\]\(mention://(member|agent|squad|issue|all)/([0-9a-fA-F-]+|all)\)"#)

    /// Splits a comment into plain text and mentions, so mentions can be drawn as chips.
    public static func segments(_ markup: String) -> [Segment] {
        let ns = markup as NSString
        var result: [Segment] = []
        var cursor = 0
        for match in pattern.matches(in: markup, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                result.append(.text(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            result.append(.mention(name: ns.substring(with: match.range(at: 1)), kind: ns.substring(with: match.range(at: 2))))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { result.append(.text(ns.substring(from: cursor))) }
        return result
    }
}

extension APIClient {
    public func agents() async throws -> [AgentRef] {
        let all: [AgentRef] = try await get("/api/agents")
        return all.filter { $0.archivedAt == nil }
    }

    public func members() async throws -> [MemberRef] {
        guard let workspaceId else { return [] }
        return try await get("/api/workspaces/\(workspaceId)/members")
    }

    /// Agents and members a comment can mention.
    public func mentionables() async -> [Mentionable] {
        async let agents = try? agents()
        async let members = try? members()
        let a = (await agents ?? []).map { Mentionable(kind: .agent, id: $0.id, name: $0.name) }
        let m = (await members ?? []).map { Mentionable(kind: .member, id: $0.userId, name: $0.name) }
        return a + m
    }
}
