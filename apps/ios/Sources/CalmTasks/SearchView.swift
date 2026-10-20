import SwiftUI
import CalmCore

/// Find a task by title, identifier or client name.
struct SearchView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var sidebar: SidebarState
    @Binding var path: NavigationPath
    @State private var query = ""

    private var results: [Issue] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return store.issues.filter {
            $0.title.lowercased().contains(q)
                || $0.identifier.lowercased().contains(q)
                || (store.project($0.projectId)?.title.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if query.isEmpty {
                    ContentUnavailableView("Cerca un task", systemImage: "magnifyingglass",
                                           description: Text("Titolo, codice o cliente."))
                        .listRowBackground(Color.clear)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
                }
                ForEach(results) { issue in
                    NavigationLink(value: issue) {
                        TaskRow(issue: issue, resolver: store.resolver(for: store.project(issue.projectId)),
                                projectName: store.project(issue.projectId)?.title, showStatus: true)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca")
            .scrollContentBackground(.hidden)
            .background(Calm.warm)
            .navigationTitle("Cerca")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { MenuButton() }
            }
        }
    }
}

/// The button that opens the sidebar.
struct MenuButton: View {
    @EnvironmentObject var sidebar: SidebarState

    var body: some View {
        Button { sidebar.open() } label: {
            Image(systemName: "line.3.horizontal").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Apri la barra laterale")
    }
}
