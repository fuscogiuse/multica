import SwiftUI
import CalmCore

/// One task in a list: the title and one quiet line under it.
/// Heights come from DS.Size so every list looks the same.
struct TaskRow: View {
    let issue: Issue
    let resolver: BoardResolver
    var density: Density = .medium
    /// The client name, shown under the title. Pass nil when the screen is already one client.
    var projectName: String?
    var showStatus = false
    var onComplete: (() -> Void)?

    private var isDone: Bool { resolver.category(for: issue.status) == "done" }
    private var compact: Bool { density == .compact }

    var body: some View {
        // No checkbox: a task is completed with a swipe to the right.
        HStack(spacing: DS.Space.m) {
            if compact {
                Text(issue.title)
                    .font(DS.Text.callout)
                    .foregroundStyle(isDone ? Calm.muted : Calm.ink)
                    .strikethrough(isDone)
                    .lineLimit(1)
                Spacer(minLength: DS.Space.s)
                if let day = issue.dueDay { dueText(day).font(DS.Text.footnote) }
            } else {
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(issue.title)
                        .font(DS.Text.body)
                        .foregroundStyle(isDone ? Calm.muted : Calm.ink)
                        .strikethrough(isDone)
                        .lineLimit(1)
                    if hasMeta { meta.font(DS.Text.footnote).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            if issue.priorityValue.rank <= 1 && !isDone {
                Image(systemName: "flag.fill").font(DS.Text.footnote).foregroundStyle(Calm.late)
                    .accessibilityLabel("Priorità alta")
            }
        }
        .frame(minHeight: compact ? DS.Size.rowCompact : (hasMeta ? DS.Size.rowMedium : DS.Size.iconButton))
        .contentShape(Rectangle())
    }

    private var metaPrefix: String {
        [projectName, showStatus ? resolver.name(for: issue.status) : nil].compactMap { $0 }.joined(separator: " · ")
    }

    private var hasMeta: Bool { !metaPrefix.isEmpty || issue.dueDay != nil || issue.assigneeType == "agent" }

    private var meta: some View {
        HStack(spacing: 0) {
            Text(metaPrefix).foregroundStyle(Calm.muted)
            if let day = issue.dueDay {
                if !metaPrefix.isEmpty { Text(" · ").foregroundStyle(Calm.muted) }
                dueText(day)
            }
            if issue.assigneeType == "agent" {
                Text(" · ").foregroundStyle(Calm.muted)
                Image(systemName: "sparkles").foregroundStyle(Calm.primary)
            }
        }
    }

    private func dueText(_ day: String) -> Text {
        let today = Today.dayString()
        if day < today { return Text(DateText.relative(day)).foregroundColor(Calm.late) }
        if day == today { return Text("Oggi").foregroundColor(Calm.primary) }
        return Text(DateText.relative(day)).foregroundColor(Calm.muted)
    }
}

/// The "move to…" menu used by long press.
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
