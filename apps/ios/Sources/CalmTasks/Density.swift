import SwiftUI

/// How tight the task list is. Medium is the default.
enum Density: String, CaseIterable {
    case compact, medium

    static let storageKey = "calm.density"

    var title: String {
        switch self {
        case .compact: return "Compatta"
        case .medium: return "Media"
        }
    }

    var sectionHeaderHeight: CGFloat { self == .compact ? 30 : 40 }
}
