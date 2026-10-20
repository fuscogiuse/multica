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

    var body: some View {
        switch model.phase {
        case .onboarding:
            OnboardingView()
        case .ready:
            if let store = model.store {
                MainTabView().environmentObject(store)
            } else {
                ProgressView()
            }
        }
    }
}
