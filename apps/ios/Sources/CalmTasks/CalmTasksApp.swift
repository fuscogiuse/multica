import SwiftUI
import CalmCore

@main
struct CalmTasksApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Calm.primary)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    guard model.phase == .ready else { return }
                    if phase == .active { model.resumeSocket() }
                    if phase == .background { model.stopSocket() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    /// Changing the accent rebuilds the screens so every view picks up the new colour.
    @AppStorage(Accent.storageKey) private var accent = Accent.blue.rawValue

    var body: some View {
        switch model.phase {
        case .onboarding:
            OnboardingView()
        case .ready:
            if let store = model.store {
                MainTabView().environmentObject(store).tint(Calm.primary).id(accent)
            } else {
                ProgressView()
            }
        }
    }
}
