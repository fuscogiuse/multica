import SwiftUI
import CalmCore

/// Due today and overdue. The caller wraps it in a NavigationStack.
struct TodayView: View {
    @EnvironmentObject var store: BoardStore
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue

    private var density: Density { Density(rawValue: densityRaw) ?? .medium }

    var body: some View {
        let resolver = store.resolver(for: nil)
        let due = Today.dueOrOverdue(store.issues, resolver: resolver, today: Today.dayString())
        List {
            if due.isEmpty && store.hasLoaded {
                ContentUnavailableView("Niente per oggi", systemImage: "sun.max", description: Text("Nessun task in scadenza."))
                    .listRowBackground(Color.clear)
            }
            ForEach(due) { issue in
                NavigationLink(value: issue) {
                    TaskRow(issue: issue, resolver: store.resolver(for: store.project(issue.projectId)), density: density,
                            projectName: store.project(issue.projectId)?.title, showStatus: true) {
                        let r = store.resolver(for: store.project(issue.projectId))
                        Task { await store.move(issue, to: r.doneKey) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .background(Calm.warm)
        .navigationTitle("Oggi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { MenuButton() } }
        .refreshable { await store.refresh() }
        .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
    }
}
