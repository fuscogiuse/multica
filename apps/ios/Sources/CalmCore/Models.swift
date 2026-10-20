import Foundation

/// Wire models for the Multica API. Decoding is tolerant: unknown keys are ignored
/// and optional values may be missing.

public struct Workspace: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var slug: String
    public var issuePrefix: String?
}

public struct Company: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var color: String?
    public var position: Int?
}

public struct CompanyList: Codable, Sendable {
    public var companies: [Company]
}

public struct Project: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var icon: String?
    public var status: String?
    public var issueCount: Int?
    public var doneCount: Int?
    public var workflowId: String?
    public var companyId: String?
}

public struct ProjectList: Codable, Sendable {
    public var projects: [Project]
}

public struct StatusEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var key: String
    public var name: String
    public var description: String?
    public var category: String
    public var color: String?
    public var isSystem: Bool?
    public var position: Int
    public var boardHidden: Bool?
    public var archivedAt: String?

    public init(id: String, key: String, name: String, description: String? = nil, category: String,
                color: String? = nil, isSystem: Bool? = nil, position: Int, boardHidden: Bool? = nil,
                archivedAt: String? = nil) {
        self.id = id; self.key = key; self.name = name; self.description = description
        self.category = category; self.color = color; self.isSystem = isSystem
        self.position = position; self.boardHidden = boardHidden; self.archivedAt = archivedAt
    }
}

public struct StatusList: Codable, Sendable {
    public var statuses: [StatusEntry]
}

public struct WorkflowHandler: Codable, Hashable, Sendable {
    public var type: String
    public var id: String?
}

public struct WorkflowStep: Codable, Hashable, Sendable {
    public var statusKey: String
    public var handler: WorkflowHandler?
    public var instructions: String?

    public init(statusKey: String, handler: WorkflowHandler? = nil, instructions: String? = nil) {
        self.statusKey = statusKey; self.handler = handler; self.instructions = instructions
    }
}

public struct Workflow: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var isDefault: Bool
    public var steps: [WorkflowStep]
    public var projectIds: [String]?

    public init(id: String, name: String, isDefault: Bool, steps: [WorkflowStep], projectIds: [String]? = nil) {
        self.id = id; self.name = name; self.isDefault = isDefault; self.steps = steps; self.projectIds = projectIds
    }
}

public struct WorkflowList: Codable, Sendable {
    public var workflows: [Workflow]
}

public enum Priority: String, CaseIterable, Sendable {
    case urgent, high, medium, low, none

    public var italian: String {
        switch self {
        case .urgent: return "Urgente"
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Bassa"
        case .none: return "Nessuna"
        }
    }

    public var rank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .none: return 4
        }
    }
}

public struct Issue: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var identifier: String
    public var title: String
    public var description: String?
    public var status: String
    public var priority: String
    public var assigneeType: String?
    public var assigneeId: String?
    public var projectId: String?
    public var dueDate: String?
    public var createdAt: String
    public var updatedAt: String
    public var position: Double?

    public init(id: String, identifier: String = "", title: String, description: String? = nil,
                status: String, priority: String = "none", assigneeType: String? = nil,
                assigneeId: String? = nil, projectId: String? = nil, dueDate: String? = nil,
                createdAt: String = "", updatedAt: String = "", position: Double? = nil) {
        self.id = id; self.identifier = identifier; self.title = title; self.description = description
        self.status = status; self.priority = priority; self.assigneeType = assigneeType
        self.assigneeId = assigneeId; self.projectId = projectId; self.dueDate = dueDate
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.position = position
    }

    private enum CodingKeys: String, CodingKey {
        case id, identifier, title, description, status, priority, assigneeType, assigneeId
        case projectId, dueDate, createdAt, updatedAt, position
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "todo"
        priority = try c.decodeIfPresent(String.self, forKey: .priority) ?? "none"
        assigneeType = try c.decodeIfPresent(String.self, forKey: .assigneeType)
        assigneeId = try c.decodeIfPresent(String.self, forKey: .assigneeId)
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        position = try c.decodeIfPresent(Double.self, forKey: .position)
    }

    public var priorityValue: Priority { Priority(rawValue: priority) ?? .none }

    /// Due date as `yyyy-MM-dd`, whatever the server sent (date or timestamp).
    public var dueDay: String? {
        guard let dueDate, dueDate.count >= 10 else { return nil }
        return String(dueDate.prefix(10))
    }
}

public struct IssueList: Codable, Sendable {
    public var issues: [Issue]
    public var total: Int?
}

public struct Comment: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var authorType: String?
    public var authorId: String?
    public var content: String
    public var type: String?
    public var createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, authorType, authorId, content, type, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        authorType = try c.decodeIfPresent(String.self, forKey: .authorType)
        authorId = try c.decodeIfPresent(String.self, forKey: .authorId)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

public struct LoginResponse: Codable, Sendable {
    public var token: String
}

public struct AppConfig: Codable, Sendable {
    public var featureFlags: [String: Bool]?

    public var projectWorkflowsEnabled: Bool { featureFlags?["project_workflows_v1"] ?? false }
}
