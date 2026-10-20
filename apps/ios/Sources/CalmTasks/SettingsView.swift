import SwiftUI
import CalmCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: BoardStore
    @State private var confirmSignOut = false
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    @AppStorage(Accent.storageKey) private var accentRaw = Accent.blue.rawValue

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
                Section("Colore") {
                    HStack(spacing: 12) {
                        ForEach(Accent.allCases) { accent in
                            Button { accentRaw = accent.rawValue } label: {
                                Circle().fill(accent.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 3).padding(2).opacity(accentRaw == accent.rawValue ? 1 : 0))
                                    .overlay(Circle().strokeBorder(accent.color, lineWidth: 2).padding(-3).opacity(accentRaw == accent.rawValue ? 1 : 0))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accent.name)
                            .accessibilityAddTraits(accentRaw == accent.rawValue ? .isSelected : [])
                        }
                    }
                    Text("Ora: \(Accent(rawValue: accentRaw)?.name ?? "Blu")").font(.footnote).foregroundStyle(Calm.muted)
                }
                Section("Aspetto") {
                    Picker("Lista", selection: $densityRaw) {
                        ForEach(Density.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
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
