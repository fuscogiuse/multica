import SwiftUI
import CalmCore

struct ListView: View {
    @EnvironmentObject var store: BoardStore
    @AppStorage(Collapsed.storageKey) private var collapsedRaw = ""
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    /// Empty sections start folded. These are the empty ones the user opened.
    @AppStorage("calm.expandedEmpty") private var expandedRaw = ""
    @State private var newTaskColumn: StatusEntry?
    /// The client the list belongs to, used for the "Nuovo task" row.
    var project: Project?
    let resolver: BoardResolver
    let issues: [Issue]
    /// Show the client name on each row. Off when the screen is a single client.
    var showProject = true

    private var density: Density { Density(rawValue: densityRaw) ?? .medium }

    var body: some View {
        let grouped = resolver.group(issues)
        let folded = Collapsed.set(collapsedRaw)
        let expandedEmpty = Collapsed.set(expandedRaw)
        List {
            ForEach(resolver.columns) { column in
                let items = grouped[column.key] ?? []
                let isFolded = folded.contains(column.key) || (items.isEmpty && !expandedEmpty.contains(column.key))
                Section {
                    if !isFolded {
                        if items.isEmpty {
                            Button { newTaskColumn = column } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                                    Text("Nuovo task").font(.system(size: 14))
                                }
                                .foregroundStyle(Calm.primary)
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                .padding(.leading, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white)
                        }
                        ForEach(items) { issue in
                            NavigationLink(value: issue) {
                                TaskRow(issue: issue, resolver: resolver, density: density,
                                        projectName: showProject ? store.project(issue.projectId)?.title : nil) {
                                    Task { await store.move(issue, to: resolver.doneKey) }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                            .listRowBackground(Color.white)
                            .listRowSeparatorTint(Color.black.opacity(0.06))
                            .swipeActions(edge: .trailing) {
                                Button("Fatto") { Task { await store.move(issue, to: resolver.doneKey) } }.tint(Calm.green)
                            }
                            .contextMenu { MoveMenu(issue: issue, resolver: resolver) }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isFolded {
                                // Open it: clear any fold and, for an empty section, remember it was opened.
                                var keys = Collapsed.set(collapsedRaw); keys.remove(column.key)
                                collapsedRaw = keys.sorted().joined(separator: ",")
                                if items.isEmpty { expandedRaw = Collapsed.toggled(column.key, in: expandedRaw) }
                            } else {
                                collapsedRaw = Collapsed.toggled(column.key, in: collapsedRaw)
                                var open = Collapsed.set(expandedRaw); open.remove(column.key)
                                expandedRaw = open.sorted().joined(separator: ",")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Calm.muted)
                                .rotationEffect(.degrees(isFolded ? 0 : 90))
                            Circle().fill(Calm.statusColor(column)).frame(width: 9, height: 9)
                            Text(column.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Calm.ink)
                            Text("\(items.count)").font(.system(size: 13)).foregroundStyle(Calm.muted)
                            Spacer()
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: density.sectionHeaderHeight, alignment: .leading)
                    .background(Color.white)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("\(column.name), \(items.count) task, \(isFolded ? "chiusa" : "aperta")")
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .background(Color.white)
        .environment(\.defaultMinListRowHeight, density == .compact ? 34 : 48)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .refreshable { await store.refresh() }
        .sheet(item: $newTaskColumn) { column in
            NewTaskView(project: project, status: column.key)
        }
    }
}
