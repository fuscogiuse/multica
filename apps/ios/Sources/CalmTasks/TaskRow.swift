import SwiftUI
import CalmCore

struct TaskRow: View {
    let issue: Issue
    let resolver: BoardResolver
    var showStatus = false
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onComplete?()
            } label: {
                Circle()
                    .strokeBorder(Calm.priorityColor(issue.priorityValue), lineWidth: 2)
                    .background(Circle().fill(Calm.priorityColor(issue.priorityValue).opacity(0.1)))
                    .frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Segna come fatto")
            .disabled(onComplete == nil)

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.system(size: 16))
                    .foregroundStyle(Calm.ink)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(issue.identifier).font(.system(size: 12)).foregroundStyle(Calm.muted)
                    if let day = issue.dueDay {
                        Text(DateText.short(day))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DateText.isOverdue(day) ? Calm.red : Calm.green)
                    }
                    if issue.assigneeType == "agent" {
                        Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Calm.muted)
                    }
                    if showStatus {
                        Text(resolver.name(for: issue.status)).font(.system(size: 12)).foregroundStyle(Calm.muted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
