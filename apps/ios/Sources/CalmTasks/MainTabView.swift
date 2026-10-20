import SwiftUI
import CalmCore

/// The new-task sheet, typed or dictated.
enum NewTaskMode: String, Identifiable {
    case typed, dictated
    var id: String { rawValue }
}

struct MainTabView: View {
    @EnvironmentObject var store: BoardStore
    /// Not observed here: the position changes on every drag step and only the drawer layer needs to redraw.
    @State private var sidebar = SidebarState()

    @AppStorage("calm.tab") private var tab = 0
    @AppStorage("calm.openProject") private var launchProject = ""
    @AppStorage("calm.sidebar") private var launchSidebar = ""

    @State private var scope: BoardScope = .all
    @State private var todayPath = NavigationPath()
    @State private var taskPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var newTask: NewTaskMode?

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
                if tab != 3 && canSwipeOpen {
                    Button { newTask = .typed } label: {
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
            .overlay(alignment: .leading) {
                if canSwipeOpen {
                    EdgeSwipe(
                        onChanged: { sidebar.follow($0, from: -SidebarState.width) },
                        onEnded: { translation, velocity in
                            sidebar.settle(open: translation > SidebarState.width * 0.4 || velocity > 600)
                        })
                        .frame(width: 22)
                        .ignoresSafeArea()
                }
            }

            DrawerLayer(
                onToday: { tab = 0; todayPath = NavigationPath(); close() },
                onScope: { newScope in select(newScope) })
        }
        .environmentObject(sidebar)
        .sheet(item: $newTask) { mode in
            NewTaskView(project: currentProject, startDictation: mode == .dictated)
        }
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
            BoardScreen().id("all")
        case .area(let id):
            BoardScreen(initialFilter: IssueFilter(companyId: id)).id("area-\(id)")
        case .project(let id):
            let project = store.project(id)
            BoardScreen(initialFilter: IssueFilter(companyId: project?.companyId, projectId: id)).id("project-\(id)")
        }
    }

    private func select(_ newScope: BoardScope) {
        scope = newScope
        taskPath = NavigationPath()
        tab = 1
        close()
    }

    private func close() { sidebar.close() }

    /// Launch arguments used by the CI screenshots: `-calm.openProject <id>` and `-calm.sidebar open|manage`.
    private func applyLaunchHooks(_ projects: [Project]) {
        if !launchProject.isEmpty, projects.contains(where: { $0.id == launchProject }) {
            scope = .project(launchProject)
            tab = 1
            launchProject = ""
        }
        if !launchSidebar.isEmpty, store.hasLoaded {
            sidebar.open()
            launchSidebar = ""
        }
    }
}

/// The dimmed backdrop and the sidebar. It is the only part that redraws while the sidebar moves.
struct DrawerLayer: View {
    @EnvironmentObject var sidebar: SidebarState

    let onToday: () -> Void
    let onScope: (BoardScope) -> Void

    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                sidebar.follow(value.translation.width, from: 0)
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width - value.translation.width
                sidebar.settle(open: sidebar.x > -SidebarState.width * 0.45 && velocity > -200)
            }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.32 * sidebar.progress)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { sidebar.close() }
                .gesture(closeDrag)
                .accessibilityHidden(true)

            SidebarView(onToday: onToday, onScope: onScope)
                .equatable()
                .frame(width: SidebarState.width)
                .background(Color.white)
                .shadow(color: .black.opacity(0.18 * sidebar.progress), radius: 14, x: 6)
                .offset(x: sidebar.x)
                .gesture(closeDrag)
                .accessibilityHidden(!sidebar.isVisible)
        }
        .allowsHitTesting(sidebar.isVisible)
    }
}
