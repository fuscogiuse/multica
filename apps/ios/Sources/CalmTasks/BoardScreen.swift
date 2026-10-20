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
            header
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
        // Own header instead of the system bar: the system bar wraps each button in glass and squeezes the title.
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
    }

    // MARK: Header

    private var subtitle: String {
        let open = issues.filter { resolver.column(for: $0) != nil && resolver.category(for: $0.status) != "done" }.count
        let area = activeProject.flatMap { store.company(of: $0)?.name }
        return [area, "\(open) aperti"].compactMap { $0 }.joined(separator: " · ")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                MenuButton()
                Spacer(minLength: 4)
                viewToggle
                filtersMenu
                optionsMenu
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            VStack(alignment: .leading, spacing: 2) {
                titleMenu
                Text(subtitle).font(.system(size: 15)).foregroundStyle(Calm.muted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
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
            HStack(spacing: 8) {
                Text(title).font(.system(size: 30, weight: .heavy)).tracking(-0.4).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(Calm.muted)
            }
            .foregroundStyle(Calm.ink)
            .frame(minHeight: 40)
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
            Image(systemName: "ellipsis").font(.system(size: 17)).frame(width: 36, height: 44)
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

    // MARK: View switch and filters, in the top bar

    private var viewToggle: some View {
        Button {
            viewMode = viewMode == "list" ? "kanban" : "list"
        } label: {
            Image(systemName: viewMode == "list" ? "rectangle.split.2x1" : "list.bullet")
                .font(.system(size: 17))
                .frame(width: 40, height: 44)
        }
        .accessibilityLabel(viewMode == "list" ? "Passa a Kanban" : "Passa a Lista")
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
            Image(systemName: count > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 18))
                .foregroundStyle(count > 0 ? Calm.primary : Calm.ink)
                .frame(width: 40, height: 44)
        }
        .accessibilityLabel(count > 0 ? "Filtri, \(count) attivi" : "Filtri")
    }
}
