import Foundation

/// Joining two tasks into one. The target stays; the source's context is appended to it.
public enum IssueMerge {
    /// The target's notes followed by a section with the source's title, notes and comments.
    public static func mergedDescription(target: Issue, source: Issue, sourceComments: [Comment]) -> String {
        var parts: [String] = []
        let existing = (target.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty { parts.append(existing) }

        var section = "---\n**Unito da \(source.identifier.isEmpty ? "un altro task" : source.identifier): \(source.title)**"
        let notes = (source.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { section += "\n\n" + notes }
        let written = sourceComments.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.type != "system" }
        if !written.isEmpty {
            section += "\n\n**Commenti di \(source.identifier.isEmpty ? "quel task" : source.identifier)**"
            for comment in written {
                let author = comment.authorType == "agent" ? "Agente" : "Membro"
                let text = comment.content.replacingOccurrences(of: "\n", with: " ")
                section += "\n- \(author): \(text)"
            }
        }
        parts.append(section)
        return parts.joined(separator: "\n\n")
    }

    /// The more urgent of the two priorities.
    public static func mergedPriority(_ a: Issue, _ b: Issue) -> String {
        a.priorityValue.rank <= b.priorityValue.rank ? a.priority : b.priority
    }

    /// The earlier of the two due dates, if any.
    public static func mergedDueDay(_ a: Issue, _ b: Issue) -> String? {
        switch (a.dueDay, b.dueDay) {
        case let (x?, y?): return min(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }
}
