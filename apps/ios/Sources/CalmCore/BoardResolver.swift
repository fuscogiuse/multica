import Foundation

/// Which columns a board shows and where each issue goes.
/// Port of `useBoard` in packages/views/calm/shared.tsx.
public struct BoardResolver: Sendable {
    public let columns: [StatusEntry]
    private let statusesByKey: [String: StatusEntry]

    /// Collapses legacy wire categories into unstarted, started, done or closed.
    public static func normalizeCategory(_ category: String) -> String {
        switch category {
        case "unstarted", "started", "done", "closed": return category
        case "backlog", "todo": return "unstarted"
        case "in_progress", "in_review", "blocked": return "started"
        case "cancelled": return "closed"
        default: return "unstarted"
        }
    }

    private init(columns: [StatusEntry], statusesByKey: [String: StatusEntry]) {
        self.columns = columns
        self.statusesByKey = statusesByKey
    }

    /// The same board limited to one status column, or unchanged when `key` is nil or unknown.
    public func restricting(to key: String?) -> BoardResolver {
        guard let key, columns.contains(where: { $0.key == key }) else { return self }
        return BoardResolver(columns: columns.filter { $0.key == key }, statusesByKey: statusesByKey)
    }

    public init(statuses: [StatusEntry], workflow: Workflow?, workflowsEnabled: Bool) {
        var byKey: [String: StatusEntry] = [:]
        for status in statuses { byKey[status.key] = status }
        statusesByKey = byKey

        if workflowsEnabled, let workflow, !workflow.isDefault {
            var result: [StatusEntry] = []
            for step in workflow.steps {
                guard let entry = byKey[step.statusKey], entry.archivedAt == nil else { continue }
                if BoardResolver.normalizeCategory(entry.category) == "closed" { continue }
                result.append(entry)
            }
            columns = result
        } else {
            columns = statuses
                .filter { $0.archivedAt == nil && ($0.boardHidden ?? false) == false }
                .sorted { $0.position < $1.position }
        }
    }

    public func entry(for key: String) -> StatusEntry? { statusesByKey[key] }

    public func name(for key: String) -> String { statusesByKey[key]?.name ?? key }

    public func category(for key: String) -> String {
        guard let entry = statusesByKey[key] else { return "unstarted" }
        return BoardResolver.normalizeCategory(entry.category)
    }

    /// The column an issue belongs to, or nil when it has none (closed statuses).
    public func column(for issue: Issue) -> StatusEntry? {
        if let direct = columns.first(where: { $0.key == issue.status }) { return direct }
        let category = category(for: issue.status)
        if category == "closed" { return nil }
        return columns.first { BoardResolver.normalizeCategory($0.category) == category }
    }

    /// Issues grouped by column key, ordered by priority then due date.
    public func group(_ issues: [Issue]) -> [String: [Issue]] {
        var result: [String: [Issue]] = [:]
        for column in columns { result[column.key] = [] }
        for issue in issues {
            if let column = column(for: issue) { result[column.key, default: []].append(issue) }
        }
        for key in result.keys { result[key]?.sort(by: BoardResolver.priorityThenDue) }
        return result
    }

    public static func priorityThenDue(_ a: Issue, _ b: Issue) -> Bool {
        let pa = a.priorityValue.rank, pb = b.priorityValue.rank
        if pa != pb { return pa < pb }
        switch (a.dueDay, b.dueDay) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.updatedAt > b.updatedAt
        }
    }
}

public enum Today {
    /// `yyyy-MM-dd` for a date in the current calendar.
    public static func dayString(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Open issues due today or earlier, most overdue first.
    public static func dueOrOverdue(_ issues: [Issue], resolver: BoardResolver, today: String) -> [Issue] {
        issues
            .filter { issue in
                guard let day = issue.dueDay, day <= today else { return false }
                let category = resolver.category(for: issue.status)
                return category == "unstarted" || category == "started"
            }
            .sorted { ($0.dueDay ?? "") < ($1.dueDay ?? "") }
    }
}
