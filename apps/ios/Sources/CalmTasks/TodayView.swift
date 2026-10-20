import SwiftUI
import CalmCore

struct TodayView: View {
    @EnvironmentObject var store: BoardStore

    var body: some View {
        NavigationStack {
            let resolver = store.resolver(for: nil)
            let due = Today.dueOrOverdue(store.issues, resolver: resolver, today: Today.dayString())
            List {
                if due.isEmpty && store.hasLoaded {
                    ContentUnavailableView("Niente per oggi", systemImage: "sun.max", description: Text("Nessun task in scadenza."))
                        .listRowBackground(Color.clear)
                }
                ForEach(due) { issue in
                    NavigationLink(value: issue) {
                        TaskRow(issue: issue, resolver: store.resolver(for: store.project(issue.projectId)), showStatus: true) {
                            let r = store.resolver(for: store.project(issue.projectId))
                            Task { await store.move(issue, to: r.doneKey) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Calm.warm)
            .navigationTitle("Oggi")
            .refreshable { await store.refresh() }
            .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
        }
    }
}
