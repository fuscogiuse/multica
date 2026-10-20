import SwiftUI
import CalmCore

struct TaskRow: View {
    let issue: Issue
    let resolver: BoardResolver
    var density: Density = .medium
    /// The client name, shown under the title in the medium layout. Pass nil when the screen is already one client.
    var projectName: String?
    var showStatus = false
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: density == .compact ? 8 : 10) {
            Button {
                onComplete?()
            } label: {
                Circle()
                    .strokeBorder(Calm.priorityColor(issue.priorityValue), lineWidth: 2)
                    .background(Circle().fill(Calm.priorityColor(issue.priorityValue).opacity(0.1)))
                    .frame(width: density == .compact ? 17 : 20, height: density == .compact ? 17 : 20)
                    .frame(width: density == .compact ? 30 : 34, height: density == .compact ? 34 : 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Segna come fatto")
            .disabled(onComplete == nil)

            if density == .compact {
                Text(issue.title)
                    .font(.system(size: 14))
                    .foregroundStyle(Calm.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                trailing
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(issue.title)
                        .font(.system(size: 15))
                        .foregroundStyle(Calm.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let projectName {
                            Text(projectName).foregroundStyle(Calm.muted)
                        }
                        if showStatus {
                            Text(resolver.name(for: issue.status)).foregroundStyle(Calm.muted)
                        }
                        if let day = issue.dueDay {
                            Text(DateText.relative(day))
                                .foregroundStyle(DateText.isOverdue(day) ? Calm.red : (day == Today.dayString() ? Calm.green : Calm.muted))
                        }
                        if issue.assigneeType == "agent" {
                            Image(systemName: "sparkles").foregroundStyle(Calm.muted)
                        }
                    }
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: density == .compact ? 34 : 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailing: some View {
        if issue.assigneeType == "agent" {
            Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(Calm.muted)
        }
        if let day = issue.dueDay {
            Text(DateText.relative(day))
                .font(.system(size: 12))
                .foregroundStyle(DateText.isOverdue(day) ? Calm.red : (day == Today.dayString() ? Calm.green : Calm.muted))
        }
    }
}

/// The "move to…" menu used by long press and swipe.
struct MoveMenu: View {
    @EnvironmentObject var store: BoardStore
    let issue: Issue
    let resolver: BoardResolver

    var body: some View {
        Menu("Sposta in…", systemImage: "arrow.right.circle") {
            ForEach(resolver.columns) { column in
                Button(column.name) { Task { await store.move(issue, to: column.key) } }
                    .disabled(column.key == issue.status)
            }
        }
    }
}

extension BoardResolver {
    /// The status key a "done" tap should use: the first column of the done category, else "done".
    var doneKey: String {
        columns.first { BoardResolver.normalizeCategory($0.category) == "done" }?.key ?? "done"
    }
}
