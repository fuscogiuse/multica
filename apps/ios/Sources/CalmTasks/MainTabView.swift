import SwiftUI
import CalmCore

struct MainTabView: View {
    @EnvironmentObject var store: BoardStore
    @StateObject private var sidebar = SidebarState()

    @AppStorage("calm.tab") private var tab = 0
    @AppStorage("calm.openProject") private var launchProject = ""
    @AppStorage("calm.sidebar") private var launchSidebar = ""

    @State private var scope: BoardScope = .all
    @State private var todayPath = NavigationPath()
    @State private var taskPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var newTask = false
    @State private var dragOffset: CGFloat = 0

    private let drawerWidth: CGFloat = 316

    /// Swipe from the left edge only where no screen is pushed, so the back swipe keeps working.
    private var canSwipeOpen: Bool {
        switch tab {
        case 0: return todayPath.isEmpty
        case 1: return taskPath.isEmpty
        case 2: return searchPath.isEmpty
        default: return false
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $tab) {
                    NavigationStack(path: $todayPath) { TodayView() }
                        .tabItem { Label("Oggi", systemImage: "calendar") }
                        .tag(0)
                    NavigationStack(path: $taskPath) { scopedBoard }
                        .tabItem { Label("Task", systemImage: "checklist") }
                        .tag(1)
                    SearchView(path: $searchPath)
                        .tabItem { Label("Cerca", systemImage: "magnifyingglass") }
                        .tag(2)
                    SettingsView()
                        .tabItem { Label("Altro", systemImage: "ellipsis") }
                        .tag(3)
                }
                if tab != 3 {
                    Button { newTask = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Calm.primary))
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    }
                    .accessibilityLabel("Nuovo task")
                    .padding(.trailing, 20)
                    .padding(.bottom, 68)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onEnded { value in
                        if canSwipeOpen, value.startLocation.x < 30, value.translation.width > 70,
                           abs(value.translation.height) < 60 {
                            withAnimation(.easeOut(duration: 0.22)) { sidebar.open() }
                        }
                    }
            )

            if sidebar.isOpen {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                SidebarView(
                    onToday: { tab = 0; todayPath = NavigationPath(); close() },
                    onScope: { newScope in select(newScope) })
                    .frame(width: drawerWidth)
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 6)
                    .offset(x: min(0, dragOffset))
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = min(0, $0.translation.width) }
                            .onEnded { value in
                                if value.translation.width < -80 { close() }
                                withAnimation(.easeOut(duration: 0.18)) { dragOffset = 0 }
                            })
                    .transition(.move(edge: .leading))
            }
        }
        .environmentObject(sidebar)
        .sheet(isPresented: $newTask) { NewTaskView(project: currentProject) }
        .alert("Qualcosa non è andato", isPresented: Binding(
            get: { store.errorMessage != nil && store.hasLoaded },
            set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if !store.hasLoaded, let message = store.errorMessage {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Calm.red)
            }
        }
        .onChange(of: store.projects) { _, projects in applyLaunchHooks(projects) }
        .onAppear { applyLaunchHooks(store.projects) }
    }

    // MARK: Scope

    private var currentProject: Project? {
        if case .project(let id) = scope { return store.project(id) }
        return nil
    }

    @ViewBuilder
    private var scopedBoard: some View {
        switch scope {
        case .all:
            BoardScreen(project: nil, title: "Tutti i task").id("all")
        case .area(let id):
            BoardScreen(project: nil, title: store.companies.first { $0.id == id }?.name ?? "Area",
                        initialFilter: IssueFilter(companyId: id)).id("area-\(id)")
        case .project(let id):
            if let project = store.project(id) {
                BoardScreen(project: project, title: project.title).id("project-\(id)")
            } else {
                BoardScreen(project: nil, title: "Tutti i task").id("all")
            }
        }
    }

    private func select(_ newScope: BoardScope) {
        scope = newScope
        taskPath = NavigationPath()
        tab = 1
        close()
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { sidebar.close() }
    }

    /// Launch arguments used by the CI screenshots: `-calm.openProject <id>` and `-calm.sidebar open|manage`.
    private func applyLaunchHooks(_ projects: [Project]) {
        if !launchProject.isEmpty, projects.contains(where: { $0.id == launchProject }) {
            scope = .project(launchProject)
            tab = 1
            launchProject = ""
        }
        if !launchSidebar.isEmpty, store.hasLoaded {
            sidebar.startsInManageMode = launchSidebar == "manage"
            sidebar.open()
            launchSidebar = ""
        }
    }
}
