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
                    ListView(resolver: resolver, issues: issues)
                }
            }
        }
        .background(Calm.warm.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            Button("Aggiorna", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        } label: {
            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Opzioni")
    }
}

/// Quick filters: area, project, status. Area and project are fixed when the screen belongs to one project.
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if fixedProject == nil {
                    chip("Area", value: companyName) {
                        Button("Tutte") { filter.companyId = nil }
                        ForEach(store.companies) { company in
                            Button(company.name) {
                                filter.companyId = company.id
                                if let pid = filter.projectId, store.project(pid)?.companyId != company.id {
                                    filter.projectId = nil
                                }
                            }
                        }
                    }
                    chip("Progetto", value: projectTitle) {
                        Button("Tutti") { filter.projectId = nil }
                        ForEach(projectChoices) { project in
                            Button(project.title) {
                                filter.projectId = project.id
                                filter.statusKey = nil
                            }
                        }
                    }
                }
                chip("Stato", value: statusName) {
                    Button("Tutti") { filter.statusKey = nil }
                    ForEach(store.resolver(for: fixedProject ?? store.project(filter.projectId)).columns) { column in
                        Button(column.name) { filter.statusKey = column.key }
                    }
                }
                if filter.isActive {
                    Button("Azzera") { filter = IssueFilter() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Calm.primary)
                        .frame(minHeight: 36)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private func chip<Content: View>(_ title: String, value: String?, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(value ?? title)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(value == nil ? Calm.soft : Color.white)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Capsule().fill(value == nil ? Color.clear : Calm.primary))
            .overlay(Capsule().strokeBorder(value == nil ? Calm.line : Color.clear, lineWidth: 1))
        }
    }
}
