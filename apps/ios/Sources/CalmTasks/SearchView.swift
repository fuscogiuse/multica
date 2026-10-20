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
            VStack(spacing: 0) {
            ScreenHeader(subtitle: nil) { LargeTitle(text: "Cerca") }
            HStack(spacing: DS.Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(Calm.muted)
                TextField("Titolo, codice o cliente", text: $query)
                    .font(DS.Text.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Calm.checkbox) }
                        .buttonStyle(.plain).accessibilityLabel("Cancella")
                }
            }
            .padding(.horizontal, DS.Space.l)
            .frame(height: DS.Size.field)
            .background(RoundedRectangle(cornerRadius: DS.Radius.m).fill(Calm.field))
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, DS.Space.s)
            List {
                if query.isEmpty {
                    ContentUnavailableView("Cerca un task", systemImage: "magnifyingglass",
                                           description: Text("Titolo, codice o cliente."))
                        .listRowBackground(Color.clear)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
                }
                ForEach(results) { issue in
                    RowLink(value: issue) {
                        TaskRow(issue: issue, resolver: store.resolver(for: store.project(issue.projectId)),
                                projectName: store.project(issue.projectId)?.title, showStatus: true)
                    }
                    .dsListRow()
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, DS.Size.rowMedium)
            .scrollContentBackground(.hidden)
            }
            .background(Color.white.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
        }
    }
}

/// The button that opens the sidebar.
struct MenuButton: View {
    @EnvironmentObject var sidebar: SidebarState

    var body: some View {
        Button { sidebar.open() } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(Calm.ink)
                .frame(width: DS.Size.iconButton, height: DS.Size.iconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apri la barra laterale")
    }
}
