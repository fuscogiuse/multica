import Foundation

/// Quick filters for the board: area (company), project and status.
public struct IssueFilter: Equatable, Sendable {
    public var companyId: String?
    public var projectId: String?
    public var statusKey: String?

    public init(companyId: String? = nil, projectId: String? = nil, statusKey: String? = nil) {
        self.companyId = companyId; self.projectId = projectId; self.statusKey = statusKey
    }

    public var isActive: Bool { companyId != nil || projectId != nil || statusKey != nil }

    /// Issues that pass the area and project filters. The status filter works on columns, see `BoardResolver.restricting`.
    public func apply(_ issues: [Issue], projects: [Project]) -> [Issue] {
        var companyByProject: [String: String] = [:]
        for project in projects { if let c = project.companyId { companyByProject[project.id] = c } }
        return issues.filter { issue in
            if let projectId, issue.projectId != projectId { return false }
            if let companyId {
                guard let pid = issue.projectId, companyByProject[pid] == companyId else { return false }
            }
            return true
        }
    }
}
