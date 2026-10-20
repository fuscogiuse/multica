import SwiftUI
import CalmCore

/// One column at a time on a phone: swipe sideways, or long press a card and drag it onto another column.
struct KanbanView: View {
    @EnvironmentObject var store: BoardStore
    let resolver: BoardResolver
    let issues: [Issue]

    @State private var targeted: String?

    var body: some View {
        let grouped = resolver.group(issues)
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(resolver.columns) { column in
                        columnView(column, items: grouped[column.key] ?? [], height: geometry.size.height)
                            .frame(width: max(geometry.size.width - 56, 240))
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func columnView(_ column: StatusEntry, items: [Issue], height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Calm.statusColor(column)).frame(width: 9, height: 9)
                Text(column.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Calm.ink)
                Spacer()
                Text("\(items.count)").font(.system(size: 13)).foregroundStyle(Calm.muted)
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { issue in
                        NavigationLink(value: issue) { card(issue) }
                            .buttonStyle(.plain)
                            .draggable(issue.id)
                            .contextMenu { MoveMenu(issue: issue, resolver: resolver) }
                    }
                    if items.isEmpty {
                        Text("Trascina qui un task")
                            .font(.footnote).foregroundStyle(Calm.muted)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
                .padding(.bottom, 90)
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14).fill(targeted == column.key ? Calm.primary.opacity(0.08) : Calm.sand))
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, let issue = store.issues.first(where: { $0.id == id }) else { return false }
            Task { await store.move(issue, to: column.key) }
            return true
        } isTargeted: { isTargeted in
            targeted = isTargeted ? column.key : (targeted == column.key ? nil : targeted)
        }
    }

    private func card(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let project = store.project(issue.projectId) {
                Text(project.title).font(.system(size: 11, weight: .medium)).foregroundStyle(Calm.muted)
            }
            Text(issue.title)
                .font(.system(size: 15))
                .foregroundStyle(Calm.ink)
                .multilineTextAlignment(.leading)
            HStack(spacing: 8) {
                Text(issue.identifier).font(.system(size: 11)).foregroundStyle(Calm.muted)
                if let day = issue.dueDay {
                    Text(DateText.short(day))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DateText.isOverdue(day) ? Calm.red : Calm.green)
                }
                Spacer()
                if issue.priorityValue != .none {
                    Circle().fill(Calm.priorityColor(issue.priorityValue)).frame(width: 8, height: 8)
                }
                if issue.assigneeType == "agent" {
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Calm.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
