import SwiftUI
import CalmCore

struct ProjectsView: View {
    @EnvironmentObject var store: BoardStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.companies) { company in
                    Section(company.name) {
                        let projects = store.projects(in: company)
                        if projects.isEmpty {
                            Text("Nessun progetto").foregroundStyle(Calm.muted)
                        }
                        ForEach(projects) { project in row(project) }
                    }
                }
                let loose = store.projects(in: nil)
                if !loose.isEmpty {
                    Section("Senza company") {
                        ForEach(loose) { project in row(project) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Calm.warm)
            .navigationTitle("Progetti")
            .refreshable { await store.refresh() }
            .overlay {
                if store.hasLoaded && store.projects.isEmpty {
                    ContentUnavailableView("Nessun progetto", systemImage: "folder")
                }
            }
        }
    }

    private func row(_ project: Project) -> some View {
        NavigationLink {
            BoardScreen(project: project, title: project.title)
        } label: {
            HStack {
                Text(project.title).foregroundStyle(Calm.ink)
                Spacer()
                let open = store.issues(in: project).filter { store.resolver(for: project).column(for: $0) != nil }.count
                Text("\(open)").foregroundStyle(Calm.muted).font(.footnote)
            }
            .frame(minHeight: 44)
        }
    }
}
