import SwiftUI
import CalmCore

/// Lista or Kanban. The title is the client picker: area, then all its projects or one.
/// The view switch and the filters live in a floating bar at the bottom, within thumb reach.
struct BoardScreen: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL

    @AppStorage("calm.view") private var viewMode = "list"
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    @State private var filter: IssueFilter

    init(initialFilter: IssueFilter = IssueFilter()) {
        _filter = State(initialValue: initialFilter)
    }

    private var activeProject: Project? { store.project(filter.projectId) }

    private var title: String {
        if let project = activeProject { return project.title }
        if let company = store.companies.first(where: { $0.id == filter.companyId }) { return company.name }
        return "Tutti i task"
    }

    private var resolver: BoardResolver {
        store.resolver(for: activeProject).restricting(to: filter.statusKey)
    }

    private var issues: [Issue] { filter.apply(store.issues, projects: store.projects) }

    private var otherFiltersActive: Bool { filter.statusKey != nil || filter.due != nil }

    var body: some View {
        VStack(spacing: 0) {
            if otherFiltersActive { chips }
            Group {
                if !store.hasLoaded && store.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if viewMode == "kanban" {
                    KanbanView(resolver: resolver, issues: issues)
                } else {
                    ListView(project: activeProject, resolver: resolver, issues: issues, showProject: activeProject == nil)
                }
            }
        }
        .background(Calm.warm.ignoresSafeArea())
        .overlay(alignment: .bottomLeading) { floatingBar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { MenuButton() }
            ToolbarItem(placement: .principal) { titleMenu }
            ToolbarItem(placement: .topBarTrailing) { optionsMenu }
        }
        .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
    }

    // MARK: Title: pick the client

    private var titleMenu: some View {
        Menu {
            Button { selectClient(company: nil, project: nil) } label: {
                check("Tutti i clienti", on: filter.companyId == nil && filter.projectId == nil)
            }
            ForEach(store.companies) { company in
                Menu(company.name) {
                    Button { selectClient(company: company.id, project: nil) } label: {
                        check("Tutti i progetti di \(company.name)", on: filter.companyId == company.id && filter.projectId == nil)
                    }
                    ForEach(store.projects(in: company)) { project in
                        Button { selectClient(company: company.id, project: project.id) } label: {
                            check(project.title, on: filter.projectId == project.id)
                        }
                    }
                }
            }
            let loose = store.projects(in: nil)
            if !loose.isEmpty {
                Menu("Senza area") {
                    ForEach(loose) { project in
                        Button { selectClient(company: nil, project: project.id) } label: {
                            check(project.title, on: filter.projectId == project.id)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 18, weight: .bold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Calm.muted)
            }
            .foregroundStyle(Calm.ink)
            .frame(minHeight: 44)
        }
        .accessibilityLabel("Cliente: \(title). Tocca per cambiare.")
    }

    private func selectClient(company: String?, project: String?) {
        filter.companyId = company
        filter.projectId = project
        filter.statusKey = nil
    }

    @ViewBuilder
    private func check(_ text: String, on: Bool) -> some View {
        if on { Label(text, systemImage: "checkmark") } else { Text(text) }
    }

    // MARK: Options

    private var optionsMenu: some View {
        Menu {
            if viewMode == "list" {
                Picker("Lista", selection: $densityRaw) {
                    ForEach(Density.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
            }
            if activeProject != nil, store.workflowsEnabled {
                Button("Modifica colonne sul web", systemImage: "square.and.pencil") {
                    if let url = model.workflowEditorURL(workflowId: store.workflow(for: activeProject)?.id) { openURL(url) }
                }
            }
            Button("Aggiorna", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Altre opzioni")
    }

    // MARK: Active filters

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let key = filter.statusKey {
                    chip(resolver.name(for: key)) { filter.statusKey = nil }
                }
                if let due = filter.due {
                    chip(due.italian) { filter.due = nil }
                }
                Button("Azzera") { filter.statusKey = nil; filter.due = nil }
                    .font(.system(size: 13))
                    .foregroundStyle(Calm.primary)
                    .frame(minHeight: 36)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }

    private func chip(_ text: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 6) {
                Text(text).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Calm.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Calm.sand))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text). Tocca per togliere il filtro.")
    }

    // MARK: Floating bar

    private var floatingBar: some View {
        HStack(spacing: 2) {
            segment("Lista", icon: "list.bullet", on: viewMode == "list") { viewMode = "list" }
            segment("Kanban", icon: "rectangle.split.2x1", on: viewMode == "kanban") { viewMode = "kanban" }
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: 22).padding(.horizontal, 4)
            filtersMenu
        }
        .padding(5)
        .background(Capsule().fill(Calm.bar))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.leading, 16)
        .padding(.bottom, 21)
    }

    private func segment(_ name: String, icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(name).font(.system(size: 14, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Calm.bar : Color.white)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Capsule().fill(on ? Color.white : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var filtersMenu: some View {
        let count = (filter.statusKey != nil ? 1 : 0) + (filter.due != nil ? 1 : 0)
        return Menu {
            Section("Stato") {
                Picker("Stato", selection: $filter.statusKey) {
                    Text("Tutti gli stati").tag(String?.none)
                    ForEach(store.resolver(for: activeProject).columns) { Text($0.name).tag(Optional($0.key)) }
                }
                .pickerStyle(.inline)
            }
            Section("Scadenza") {
                Picker("Scadenza", selection: $filter.due) {
                    Text("Qualsiasi scadenza").tag(DueFilter?.none)
                    ForEach(DueFilter.allCases, id: \.self) { Text($0.italian).tag(Optional($0)) }
                }
                .pickerStyle(.inline)
            }
            if otherFiltersActive {
                Button("Azzera i filtri", role: .destructive) { filter.statusKey = nil; filter.due = nil }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 14, weight: .medium))
                Text("Filtri").font(.system(size: 14))
                if count > 0 {
                    Text("\(count)").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Calm.bar)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Color.white))
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 42)
        }
        .accessibilityLabel(count > 0 ? "Filtri, \(count) attivi" : "Filtri")
    }
}
