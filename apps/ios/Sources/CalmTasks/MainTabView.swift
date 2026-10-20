import SwiftUI
import CalmCore

struct MainTabView: View {
    @EnvironmentObject var store: BoardStore
    @AppStorage("calm.tab") private var tab = 0
    @State private var newTask = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                TodayView()
                    .tabItem { Label("Oggi", systemImage: "calendar") }
                    .tag(0)
                NavigationStack { BoardScreen(project: nil, title: "Task") }
                    .tabItem { Label("Task", systemImage: "checklist") }
                    .tag(1)
                ProjectsView()
                    .tabItem { Label("Progetti", systemImage: "folder") }
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
        .sheet(isPresented: $newTask) { NewTaskView(project: nil) }
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
    }
}
