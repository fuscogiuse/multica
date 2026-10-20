import SwiftUI
import CalmCore

/// One task in a list, Aria style: rounded square checkbox, title, and a quiet line under it.
struct TaskRow: View {
    let issue: Issue
    let resolver: BoardResolver
    var density: Density = .medium
    /// The client name, shown under the title in the medium layout. Pass nil when the screen is already one client.
    var projectName: String?
    var showStatus = false
    var onComplete: (() -> Void)?

    private var isDone: Bool { resolver.category(for: issue.status) == "done" }

    private var boxColor: Color {
        switch issue.priorityValue {
        case .urgent, .high: return Calm.late
        default: return Calm.checkbox
        }
    }

    var body: some View {
        HStack(spacing: density == .compact ? 10 : 14) {
            Button { onComplete?() } label: {
                checkbox
                    .frame(width: density == .compact ? 32 : 36, height: density == .compact ? 34 : 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Segna come fatto")
            .disabled(onComplete == nil)

            if density == .compact {
                Text(issue.title)
                    .font(.system(size: 15))
                    .foregroundStyle(isDone ? Calm.muted : Calm.ink)
                    .strikethrough(isDone)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let day = issue.dueDay { dueText(day).font(.system(size: 12)) }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.system(size: 17))
                        .foregroundStyle(isDone ? Calm.muted : Calm.ink)
                        .strikethrough(isDone)
                        .lineLimit(1)
                    if hasMeta {
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
                        .font(.system(size: 13))
                        .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: density == .compact ? 38 : 56)
        .contentShape(Rectangle())
    }

    private var metaPrefix: String {
        [projectName, showStatus ? resolver.name(for: issue.status) : nil].compactMap { $0 }.joined(separator: " · ")
    }

    private var hasMeta: Bool { !metaPrefix.isEmpty || issue.dueDay != nil || issue.assigneeType == "agent" }

    @ViewBuilder
    private var checkbox: some View {
        let size: CGFloat = density == .compact ? 19 : 22
        if isDone {
            RoundedRectangle(cornerRadius: 7).fill(Calm.primary)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "checkmark").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(.white))
        } else {
            RoundedRectangle(cornerRadius: 7).strokeBorder(boxColor, lineWidth: 1.8)
                .frame(width: size, height: size)
        }
    }

    private func dueText(_ day: String) -> Text {
        let today = Today.dayString()
        if day < today { return Text(DateText.relative(day)).foregroundColor(Calm.late) }
        if day == today { return Text("Oggi").foregroundColor(Calm.primary) }
        return Text(DateText.relative(day)).foregroundColor(Calm.muted)
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
