import SwiftUI
import CalmCore

/// A tap target for one area (company). `companyId` is nil for projects with no area.
struct AreaRoute: Hashable {
    let companyId: String?
}

/// The Progetti tab shows the areas only. Tap an area to see its projects.
struct ProjectsView: View {
    @EnvironmentObject var store: BoardStore
    @State private var path = NavigationPath()
    @AppStorage("calm.openProject") private var openProject = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(store.companies) { company in
                    areaRow(AreaRoute(companyId: company.id), name: company.name, color: company.color)
                }
                if !store.projects(in: nil).isEmpty {
                    areaRow(AreaRoute(companyId: nil), name: "Senza area", color: nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .background(Calm.warm)
            .navigationTitle("Aree")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AreaRoute.self) { route in AreaView(route: route) }
            .navigationDestination(for: Project.self) { project in
                BoardScreen(project: project, title: project.title)
            }
            .onChange(of: store.projects) { _, projects in
                // Screenshot hook: `-calm.openProject <id>` opens that project on launch.
                if !openProject.isEmpty, path.isEmpty, let project = projects.first(where: { $0.id == openProject }) {
                    path.append(AreaRoute(companyId: project.companyId))
                    path.append(project)
                    openProject = ""
                }
            }
            .refreshable { await store.refresh() }
            .overlay {
                if store.hasLoaded && store.companies.isEmpty && store.projects.isEmpty {
                    ContentUnavailableView("Nessuna area", systemImage: "folder")
                }
            }
        }
    }

    private func areaRow(_ route: AreaRoute, name: String, color: String?) -> some View {
        let projects = store.projects(in: store.companies.first { $0.id == route.companyId })
        return NavigationLink(value: route) {
            HStack(spacing: 12) {
                Circle().fill(color.flatMap { Color(hexString: $0) } ?? Calm.muted).frame(width: 12, height: 12)
                Text(name).font(.system(size: 17, weight: .medium)).foregroundStyle(Calm.ink)
                Spacer()
                Text("\(projects.count)").font(.footnote).foregroundStyle(Calm.muted)
            }
            .frame(minHeight: 48)
        }
    }
}

/// The projects of one area, plus a row that opens every task of the area.
struct AreaView: View {
    @EnvironmentObject var store: BoardStore
    let route: AreaRoute

    private var company: Company? { store.companies.first { $0.id == route.companyId } }
    private var name: String { company?.name ?? "Senza area" }
    private var projects: [Project] { store.projects(in: company) }

    var body: some View {
        List {
            if company != nil {
                Section {
                    NavigationLink {
                        BoardScreen(project: nil, title: name, initialFilter: IssueFilter(companyId: company?.id))
                    } label: {
                        Label("Tutti i task di \(name)", systemImage: "checklist")
                            .frame(minHeight: 44)
                    }
                }
            }
            Section("Progetti") {
                if projects.isEmpty {
                    Text("Nessun progetto").foregroundStyle(Calm.muted)
                }
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        HStack {
                            Text(project.title).foregroundStyle(Calm.ink)
                            Spacer()
                            let open = store.issues(in: project)
                                .filter { store.resolver(for: project).column(for: $0) != nil }.count
                            Text("\(open)").foregroundStyle(Calm.muted).font(.footnote)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .background(Calm.warm)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
    }
}
