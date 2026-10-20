import SwiftUI
import CalmCore

/// The new-task sheet, typed or dictated.
enum NewTaskMode: String, Identifiable {
    case typed, dictated
    var id: String { rawValue }
}

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
    @State private var newTask: NewTaskMode?
    /// Finger position while dragging the sidebar, from -drawerWidth (closed) to 0 (open). Nil when not dragging.
    @State private var drag: CGFloat?

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

    private var drawerX: CGFloat { drag ?? (sidebar.isOpen ? 0 : -drawerWidth) }
    private var drawerProgress: Double { Double(1 + drawerX / drawerWidth) }

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
                    VStack(spacing: 12) {
                        Button { newTask = .dictated } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Calm.primary)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color.white))
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.1)))
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        }
                        .accessibilityLabel("Detta un task")
                        Button { newTask = .typed } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Calm.primary))
                                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        }
                        .accessibilityLabel("Nuovo task")
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 68)
                }
            }
            .simultaneousGesture(openGesture)

            Color.black.opacity(0.32 * drawerProgress)
                .ignoresSafeArea()
                .allowsHitTesting(sidebar.isOpen || drag != nil)
                .onTapGesture { close() }
                .gesture(closeGesture)
                .accessibilityHidden(true)

            SidebarView(
                onToday: { tab = 0; todayPath = NavigationPath(); close() },
                onScope: { newScope in select(newScope) })
                .frame(width: drawerWidth)
                .shadow(color: .black.opacity(0.18 * drawerProgress), radius: 14, x: 6)
                .offset(x: drawerX)
                .gesture(closeGesture)
                .allowsHitTesting(sidebar.isOpen || drag != nil)
                .accessibilityHidden(!sidebar.isOpen)
        }
        .animation(.easeOut(duration: 0.22), value: sidebar.isOpen)
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

    /// Pull the sidebar out from the left edge. The drawer follows the finger.
    private var openGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard canSwipeOpen, !sidebar.isOpen, value.startLocation.x < 28,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                drag = max(-drawerWidth, min(0, -drawerWidth + value.translation.width))
            }
            .onEnded { value in
                guard let current = drag else { return }
                let open = current > -drawerWidth * 0.6 || value.predictedEndTranslation.width > drawerWidth * 0.5
                drag = nil
                withAnimation(.easeOut(duration: 0.22)) { sidebar.isOpen = open }
            }
    }

    /// Push the open sidebar back to the left, or tap outside it.
    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard sidebar.isOpen else { return }
                drag = max(-drawerWidth, min(0, value.translation.width))
            }
            .onEnded { value in
                guard drag != nil else { return }
                let stayOpen = (drag ?? 0) > -drawerWidth * 0.35 && value.predictedEndTranslation.width > -drawerWidth * 0.5
                drag = nil
                withAnimation(.easeOut(duration: 0.2)) { sidebar.isOpen = stayOpen }
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
            sidebar.open()
            launchSidebar = ""
        }
    }
}
