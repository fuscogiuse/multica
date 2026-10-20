import SwiftUI
import CalmCore

struct ListView: View {
    @EnvironmentObject var store: BoardStore
    @AppStorage(Collapsed.storageKey) private var collapsedRaw = ""
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    let resolver: BoardResolver
    let issues: [Issue]
    /// Show the client name on each row. Off when the screen is a single client.
    var showProject = true

    private var density: Density { Density(rawValue: densityRaw) ?? .medium }

    var body: some View {
        let grouped = resolver.group(issues)
        let folded = Collapsed.set(collapsedRaw)
        List {
            ForEach(resolver.columns) { column in
                let items = grouped[column.key] ?? []
                let isFolded = folded.contains(column.key)
                Section {
                    if !isFolded {
                        if items.isEmpty {
                            Text("Nessun task").font(.footnote).foregroundStyle(Calm.muted)
                        }
                        ForEach(items) { issue in
                            NavigationLink(value: issue) {
                                TaskRow(issue: issue, resolver: resolver, density: density,
                                        projectName: showProject ? store.project(issue.projectId)?.title : nil) {
                                    Task { await store.move(issue, to: resolver.doneKey) }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                            .swipeActions(edge: .trailing) {
                                Button("Fatto") { Task { await store.move(issue, to: resolver.doneKey) } }.tint(Calm.green)
                            }
                            .contextMenu { MoveMenu(issue: issue, resolver: resolver) }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            collapsedRaw = Collapsed.toggled(column.key, in: collapsedRaw)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Calm.muted)
                                .rotationEffect(.degrees(isFolded ? 0 : 90))
                            Circle().fill(Calm.statusColor(column)).frame(width: 9, height: 9)
                            Text(column.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Calm.ink)
                            Text("\(items.count)").font(.system(size: 13)).foregroundStyle(Calm.muted)
                            Spacer()
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: density.sectionHeaderHeight, alignment: .leading)
                    .background(Calm.sand)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("\(column.name), \(items.count) task, \(isFolded ? "chiusa" : "aperta")")
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, density == .compact ? 34 : 48)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .refreshable { await store.refresh() }
    }
}
