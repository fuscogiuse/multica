import SwiftUI
import CalmCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: BoardStore
    @State private var confirmSignOut = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Server", value: model.session?.serverURL.host ?? "-")
                    Button("Aggiorna ora") { Task { await store.refresh() } }
                    Button("Esci", role: .destructive) { confirmSignOut = true }
                }
                Section("Informazioni") {
                    LabeledContent("Versione", value: version)
                    Text("Calm Tasks è basato su Multica.")
                        .font(.footnote).foregroundStyle(Calm.muted)
                    Link("Multica su GitHub", destination: URL(string: "https://github.com/multica-ai/multica")!)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Calm.warm)
            .navigationTitle("Altro")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Uscire da Calm Tasks?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Esci", role: .destructive) { model.signOut() }
            }
        }
    }
}
