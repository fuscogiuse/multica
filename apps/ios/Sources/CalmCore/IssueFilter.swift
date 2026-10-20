import Foundation

/// Due-date quick filter.
public enum DueFilter: String, CaseIterable, Sendable {
    case overdue, today, week, undated

    public var italian: String {
        switch self {
        case .overdue: return "Scaduti"
        case .today: return "Oggi"
        case .week: return "Questa settimana"
        case .undated: return "Senza data"
        }
    }
}

/// Quick filters for the board: area (company), project, status and due date. They combine.
public struct IssueFilter: Equatable, Sendable {
    public var companyId: String?
    public var projectId: String?
    public var statusKey: String?
    public var due: DueFilter?

    public init(companyId: String? = nil, projectId: String? = nil, statusKey: String? = nil, due: DueFilter? = nil) {
        self.companyId = companyId; self.projectId = projectId; self.statusKey = statusKey; self.due = due
    }

    public var isActive: Bool { companyId != nil || projectId != nil || statusKey != nil || due != nil }

    /// Issues that pass the area, project and due filters. The status filter works on columns, see `BoardResolver.restricting`.
    public func apply(_ issues: [Issue], projects: [Project], today: String = Today.dayString(), calendar: Calendar = .current) -> [Issue] {
        var companyByProject: [String: String] = [:]
        for project in projects { if let c = project.companyId { companyByProject[project.id] = c } }
        let weekEnd = IssueFilter.weekEnd(from: today, calendar: calendar)
        return issues.filter { issue in
            if let projectId, issue.projectId != projectId { return false }
            if let companyId {
                guard let pid = issue.projectId, companyByProject[pid] == companyId else { return false }
            }
            if let due {
                let day = issue.dueDay
                switch due {
                case .undated: if day != nil { return false }
                case .overdue: guard let day, day < today else { return false }
                case .today: guard let day, day == today else { return false }
                case .week: guard let day, day >= today, day <= weekEnd else { return false }
                }
            }
            return true
        }
    }

    /// The day six days after `today`, as `yyyy-MM-dd`.
    static func weekEnd(from today: String, calendar: Calendar) -> String {
        let parts = today.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let end = calendar.date(byAdding: .day, value: 6, to: start) else { return today }
        return Today.dayString(end, calendar: calendar)
    }
}
