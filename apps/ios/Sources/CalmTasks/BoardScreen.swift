import SwiftUI
import CalmCore

/// Lista or Kanban for one project, or for every task when `project` is nil.
struct BoardScreen: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL

    let project: Project?
    let title: String

    @AppStorage("calm.view") private var viewMode = "list"
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    @State private var filter: IssueFilter

    init(project: Project?, title: String, initialFilter: IssueFilter = IssueFilter()) {
        self.project = project
        self.title = title
        _filter = State(initialValue: initialFilter)
    }

    /// The project whose workflow decides the columns: the one in view, or the one picked in the filter.
    private var activeProject: Project? { project ?? store.project(filter.projectId) }

    private var resolver: BoardResolver {
        store.resolver(for: activeProject).restricting(to: filter.statusKey)
    }

    private var issues: [Issue] {
        let base = project != nil ? store.issues(in: project) : store.issues
        return filter.apply(base, projects: store.projects)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            FilterBar(filter: $filter, fixedProject: project, resolver: store.resolver(for: activeProject))
            Group {
                if !store.hasLoaded && store.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if viewMode == "kanban" {
                    KanbanView(resolver: resolver, issues: issues)
                } else {
                    ListView(project: activeProject, resolver: resolver, issues: issues, showProject: project == nil)
                }
            }
        }
        .background(Calm.warm.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { MenuButton() }
            ToolbarItem(placement: .topBarTrailing) { columnsMenu }
        }
        .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Picker("Vista", selection: $viewMode) {
                Text("Lista").tag("list")
                Text("Kanban").tag("kanban")
            }
            .pickerStyle(.segmented)
            if let workflow = workflowName {
                Label(workflow, systemImage: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Calm.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var workflowName: String? {
        guard store.workflowsEnabled, let workflow = store.workflow(for: activeProject), !workflow.isDefault else { return nil }
        return workflow.name
    }

    private var columnsMenu: some View {
        Menu {
            if activeProject != nil, store.workflowsEnabled {
                Button("Modifica colonne sul web", systemImage: "square.and.pencil") {
                    if let url = model.workflowEditorURL(workflowId: store.workflow(for: activeProject)?.id) { openURL(url) }
                }
            }
            if viewMode == "list" {
                Picker("Lista", selection: $densityRaw) {
                    ForEach(Density.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
            }
            Button("Aggiorna", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        } label: {
            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Opzioni")
    }
}

/// Quick filters: client, status, due date. They combine. "Cliente" is one menu: pick an area, then all its projects or one.
struct FilterBar: View {
    @EnvironmentObject var store: BoardStore
    @Binding var filter: IssueFilter
    let fixedProject: Project?
    let resolver: BoardResolver

    private var clientValue: String? {
        if let project = store.project(filter.projectId) { return project.title }
        if let company = store.companies.first(where: { $0.id == filter.companyId }) { return company.name }
        return nil
    }

    private var statusName: String? { filter.statusKey.map { resolver.name(for: $0) } }

    private var statusColumns: [StatusEntry] {
        store.resolver(for: fixedProject ?? store.project(filter.projectId)).columns
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if fixedProject == nil {
                    Menu {
                        clientMenu
                    } label: { pill(icon: "folder", title: "Cliente", value: clientValue) }
                }

                Menu {
                    Picker("Stato", selection: $filter.statusKey) {
                        Text("Tutti gli stati").tag(String?.none)
                        ForEach(statusColumns) { Text($0.name).tag(Optional($0.key)) }
                    }
                    .pickerStyle(.inline)
                } label: { pill(icon: "circle.dashed", title: "Stato", value: statusName) }

                Menu {
                    Picker("Scadenza", selection: $filter.due) {
                        Text("Qualsiasi scadenza").tag(DueFilter?.none)
                        ForEach(DueFilter.allCases, id: \.self) { Text($0.italian).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                } label: { pill(icon: "calendar", title: "Scadenza", value: filter.due?.italian) }

                if filter.isActive {
                    Button("Azzera") { filter = IssueFilter() }
                        .font(.system(size: 14))
                        .foregroundStyle(Calm.primary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }

    /// One menu: every area is a submenu with "all projects of the area" and then each project.
    @ViewBuilder
    private var clientMenu: some View {
        Button { select(company: nil, project: nil) } label: {
            check("Tutti i clienti", on: filter.companyId == nil && filter.projectId == nil)
        }
        ForEach(store.companies) { company in
            Menu(company.name) {
                Button { select(company: company.id, project: nil) } label: {
                    check("Tutti i progetti di \(company.name)", on: filter.companyId == company.id && filter.projectId == nil)
                }
                ForEach(store.projects(in: company)) { project in
                    Button { select(company: company.id, project: project.id) } label: {
                        check(project.title, on: filter.projectId == project.id)
                    }
                }
            }
        }
        let loose = store.projects(in: nil)
        if !loose.isEmpty {
            Menu("Senza area") {
                ForEach(loose) { project in
                    Button { select(company: nil, project: project.id) } label: {
                        check(project.title, on: filter.projectId == project.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func check(_ title: String, on: Bool) -> some View {
        if on { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private func select(company: String?, project: String?) {
        filter.companyId = company
        filter.projectId = project
        filter.statusKey = nil
    }

    /// A labelled button. With a choice made it turns dark and shows the choice instead of its name.
    private func pill(icon: String, title: String, value: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium))
            Text(value ?? title).font(.system(size: 14, weight: value == nil ? .regular : .semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(value == nil ? Calm.ink : Color.white)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Capsule().fill(value == nil ? Color.white : Calm.ink))
        .overlay(Capsule().strokeBorder(value == nil ? Color.black.opacity(0.14) : Color.clear, lineWidth: 1))
        .accessibilityLabel(value.map { "Filtro \(title): \($0)" } ?? "Filtra per \(title)")
    }
}
