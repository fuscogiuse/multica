import SwiftUI
import CalmCore

struct ListView: View {
    @EnvironmentObject var store: BoardStore
    let resolver: BoardResolver
    let issues: [Issue]

    var body: some View {
        let grouped = resolver.group(issues)
        List {
            ForEach(resolver.columns) { column in
                let items = grouped[column.key] ?? []
                Section {
                    if items.isEmpty {
                        Text("Nessun task").font(.footnote).foregroundStyle(Calm.muted)
                    }
                    ForEach(items) { issue in
                        NavigationLink(value: issue) {
                            TaskRow(issue: issue, resolver: resolver) {
                                Task { await store.move(issue, to: resolver.doneKey) }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Fatto") { Task { await store.move(issue, to: resolver.doneKey) } }.tint(Calm.green)
                        }
                        .contextMenu { MoveMenu(issue: issue, resolver: resolver) }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Circle().fill(Calm.statusColor(column)).frame(width: 9, height: 9)
                        Text(column.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Calm.ink)
                        Text("\(items.count)").font(.system(size: 13)).foregroundStyle(Calm.muted)
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await store.refresh() }
    }
}
