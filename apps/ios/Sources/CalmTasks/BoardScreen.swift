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
    @State private var newTask = false

    private var resolver: BoardResolver { store.resolver(for: project) }
    private var issues: [Issue] { store.issues(in: project) }

    var body: some View {
        VStack(spacing: 0) {
            header
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { columnsMenu }
        }
        .sheet(isPresented: $newTask) { NewTaskView(project: project) }
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
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Calm.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var workflowName: String? {
        guard store.workflowsEnabled, let workflow = store.workflow(for: project), !workflow.isDefault else { return nil }
        return workflow.name
    }

    private var columnsMenu: some View {
        Menu {
            if project != nil, store.workflowsEnabled {
                Button("Modifica colonne sul web", systemImage: "square.and.pencil") {
                    if let url = model.workflowEditorURL(workflowId: store.workflow(for: project)?.id) { openURL(url) }
                }
            }
            Button("Aggiorna", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
        } label: {
            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Opzioni")
    }
}
