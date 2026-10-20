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
                    ListView(resolver: resolver, issues: issues, showProject: project == nil)
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

/// Icon filters: area, client, status, due date. Tap an icon for a pop-up menu; the choices combine.
struct FilterBar: View {
    @EnvironmentObject var store: BoardStore
    @Binding var filter: IssueFilter
    let fixedProject: Project?
    let resolver: BoardResolver

    private var companyName: String? { store.companies.first { $0.id == filter.companyId }?.name }
    private var projectTitle: String? { store.project(filter.projectId)?.title }
    private var statusName: String? { filter.statusKey.map { resolver.name(for: $0) } }

    private var projectChoices: [Project] {
        guard let companyId = filter.companyId else { return store.projects }
        return store.projects.filter { $0.companyId == companyId }
    }

    private var companyBinding: Binding<String?> {
        Binding(
            get: { filter.companyId },
            set: { id in
                filter.companyId = id
                if let pid = filter.projectId, let id, store.project(pid)?.companyId != id { filter.projectId = nil }
            })
    }

    private var projectBinding: Binding<String?> {
        Binding(
            get: { filter.projectId },
            set: { id in
                filter.projectId = id
                filter.statusKey = nil
            })
    }

    private var statusColumns: [StatusEntry] {
        store.resolver(for: fixedProject ?? store.project(filter.projectId)).columns
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if fixedProject == nil {
                    Menu {
                        Picker("Area", selection: companyBinding) {
                            Text("Tutte le aree").tag(String?.none)
                            ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.inline)
                    } label: { chip(icon: "square.grid.2x2", value: companyName, name: "area") }

                    Menu {
                        Picker("Cliente", selection: projectBinding) {
                            Text("Tutti i clienti").tag(String?.none)
                            ForEach(projectChoices) { Text($0.title).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.inline)
                    } label: { chip(icon: "folder", value: projectTitle, name: "cliente") }
                }

                Menu {
                    Picker("Stato", selection: $filter.statusKey) {
                        Text("Tutti gli stati").tag(String?.none)
                        ForEach(statusColumns) { Text($0.name).tag(Optional($0.key)) }
                    }
                    .pickerStyle(.inline)
                } label: { chip(icon: "circle.dashed", value: statusName, name: "stato") }

                Menu {
                    Picker("Scadenza", selection: $filter.due) {
                        Text("Qualsiasi scadenza").tag(DueFilter?.none)
                        ForEach(DueFilter.allCases, id: \.self) { Text($0.italian).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                } label: { chip(icon: "calendar", value: filter.due?.italian, name: "scadenza") }

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

    /// A round icon button. With a value it grows into a dark pill that shows the choice.
    private func chip(icon: String, value: String?, name: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
            if let value {
                Text(value).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }
        }
        .foregroundStyle(value == nil ? Calm.ink : Color.white)
        .padding(.horizontal, value == nil ? 0 : 14)
        .frame(minWidth: 44, minHeight: 44)
        .background(Capsule().fill(value == nil ? Color.white : Calm.ink))
        .overlay(Capsule().strokeBorder(value == nil ? Calm.line.opacity(1.8) : Color.clear, lineWidth: 1))
        .accessibilityLabel(value.map { "Filtro \(name): \($0)" } ?? "Filtra per \(name)")
    }
}
