import SwiftUI
import CalmCore

struct ProjectsView: View {
    @EnvironmentObject var store: BoardStore
    @State private var path: [Project] = []
    @AppStorage("calm.openProject") private var openProject = ""

    var body: some View {
        NavigationStack(path: $path) {
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
            .navigationDestination(for: Project.self) { project in
                BoardScreen(project: project, title: project.title)
            }
            .onChange(of: store.projects) { _, projects in
                // Screenshot hook: `-calm.openProject <id>` opens that project on launch.
                if !openProject.isEmpty, path.isEmpty, let project = projects.first(where: { $0.id == openProject }) {
                    path = [project]
                    openProject = ""
                }
            }
            .refreshable { await store.refresh() }
            .overlay {
                if store.hasLoaded && store.projects.isEmpty {
                    ContentUnavailableView("Nessun progetto", systemImage: "folder")
                }
            }
        }
    }

    private func row(_ project: Project) -> some View {
        NavigationLink(value: project) {
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
