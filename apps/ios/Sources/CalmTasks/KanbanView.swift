import SwiftUI
import CalmCore

/// One column at a time on a phone: swipe sideways, or long press a card and drag it onto another column.
struct KanbanView: View {
    @EnvironmentObject var store: BoardStore
    let resolver: BoardResolver
    let issues: [Issue]

    @AppStorage(Collapsed.storageKey) private var collapsedRaw = ""
    @State private var targeted: String?
    @State private var mergePair: MergePair?

    private func toggle(_ key: String) {
        withAnimation(.easeInOut(duration: 0.2)) { collapsedRaw = Collapsed.toggled(key, in: collapsedRaw) }
    }

    var body: some View {
        let grouped = resolver.group(issues)
        let folded = Collapsed.set(collapsedRaw)
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DS.Space.m) {
                    ForEach(resolver.columns) { column in
                        if folded.contains(column.key) {
                            foldedColumn(column, count: grouped[column.key]?.count ?? 0)
                                .frame(width: 54)
                        } else {
                            columnView(column, items: grouped[column.key] ?? [], height: geometry.size.height)
                                .frame(width: max(geometry.size.width - DS.gutter * 2 - 36, 240))
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, DS.gutter)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .mergeDialog($mergePair)
    }

    private func columnView(_ column: StatusEntry, items: [Issue], height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { toggle(column.key) } label: {
                SectionTitle(name: column.name, count: items.count)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comprimi \(column.name)")

            ScrollView {
                LazyVStack(spacing: DS.Space.s) {
                    ForEach(items) { issue in
                        NavigationLink(value: issue) { card(issue) }
                            .buttonStyle(.plain)
                            .draggable(issue.id)
                            .contextMenu { MoveMenu(issue: issue, resolver: resolver) }
                            // A card dropped on another card asks to join the two.
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first, id != issue.id,
                                      let source = store.issues.first(where: { $0.id == id }) else { return false }
                                mergePair = MergePair(source: source, target: issue)
                                return true
                            }
                    }
                    if items.isEmpty {
                        Text("Trascina qui un task")
                            .font(.system(size: 14)).foregroundStyle(Calm.muted)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Calm.checkbox, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                }
                .padding(.bottom, 90)
            }
        }
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18).fill(targeted == column.key ? Calm.primary.opacity(0.06) : Color.white))
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, let issue = store.issues.first(where: { $0.id == id }) else { return false }
            Task { await store.move(issue, to: column.key) }
            return true
        } isTargeted: { isTargeted in
            targeted = isTargeted ? column.key : (targeted == column.key ? nil : targeted)
        }
    }

    /// A narrow strip with the name written sideways. Tap to open; dropping a card on it still moves the task there.
    private func foldedColumn(_ column: StatusEntry, count: Int) -> some View {
        Button { toggle(column.key) } label: {
            VStack(spacing: 10) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Calm.muted)
                Circle().fill(Calm.statusColor(column)).frame(width: 9, height: 9)
                Text("\(count)").font(.system(size: 13, weight: .medium)).foregroundStyle(Calm.muted)
                Text(column.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Calm.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 20, height: 120)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 14).fill(targeted == column.key ? Calm.primary.opacity(0.08) : Calm.sand))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apri \(column.name), \(count) task")
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, let issue = store.issues.first(where: { $0.id == id }) else { return false }
            Task { await store.move(issue, to: column.key) }
            return true
        } isTargeted: { isTargeted in
            targeted = isTargeted ? column.key : (targeted == column.key ? nil : targeted)
        }
    }

    private func card(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(issue.title)
                .font(DS.Text.headline)
                .foregroundStyle(Calm.ink)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            HStack(spacing: 8) {
                if let day = issue.dueDay {
                    let today = Today.dayString()
                    Text(day == today ? "Oggi" : DateText.relative(day))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(day < today ? Calm.late : (day == today ? Calm.primary : Calm.soft))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(day == today ? Calm.primary.opacity(0.12) : Color(hex: 0xECEEF2)))
                }
                if let project = store.project(issue.projectId) {
                    Text(project.title).font(.system(size: 12)).foregroundStyle(Calm.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if issue.assigneeType == "agent" {
                    Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(Calm.primary)
                }
                Text(issue.identifier).font(.system(size: 12)).foregroundStyle(Calm.muted)
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.l).fill(Calm.card))
    }
}
