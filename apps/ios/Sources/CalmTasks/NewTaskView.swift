import SwiftUI
import CalmCore

struct NewTaskView: View {
    @EnvironmentObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    /// Put the new task straight into this status. Nil uses the first column of the project.
    var status: String?
    /// Start listening as soon as the sheet opens.
    var startDictation = false

    @StateObject private var dictation = Dictation()
    @State private var title = ""
    @State private var typedBeforeDictation = ""
    @State private var projectId: String?
    @State private var priority: Priority = .none
    @State private var hasDue = false
    @State private var due = Date()
    @State private var saving = false
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Cosa c'è da fare?", text: $title, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(1...4)
                        Button {
                            Task { await toggleDictation() }
                        } label: {
                            Image(systemName: dictation.isListening ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(dictation.isListening ? Calm.red : Calm.primary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dictation.isListening ? "Ferma la dettatura" : "Detta il task")
                    }
                    if dictation.isListening {
                        Label("Sto ascoltando…", systemImage: "waveform")
                            .font(.footnote).foregroundStyle(Calm.muted)
                    }
                    if let message = dictation.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(Calm.red)
                    }
                }
                Section {
                    Picker("Progetto", selection: $projectId) {
                        Text("Nessuno").tag(String?.none)
                        ForEach(store.projects) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    Picker("Priorità", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { Text($0.italian).tag($0) }
                    }
                    Toggle("Scadenza", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Giorno", selection: $due, displayedComponents: .date)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Calm.warm)
            .navigationTitle("Nuovo task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { stopAndDismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") { save() }
                        .fontWeight(.semibold)
                        .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { projectId = project?.id }
            .task { if startDictation { await toggleDictation() } }
            .onChange(of: dictation.transcript) { _, text in
                guard dictation.isListening || !text.isEmpty else { return }
                let prefix = typedBeforeDictation.trimmingCharacters(in: .whitespaces)
                title = prefix.isEmpty ? text : prefix + " " + text
            }
        }
        // Stays at half height until the user drags it up. The keyboard does not open on its own.
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private func toggleDictation() async {
        if !dictation.isListening { typedBeforeDictation = title }
        await dictation.toggle()
    }

    private func stopAndDismiss() {
        dictation.stop()
        dismiss()
    }

    private func save() {
        dictation.stop()
        saving = true
        let chosen = store.project(projectId)
        let firstKey = status ?? store.resolver(for: chosen).columns.first?.key ?? "todo"
        let body = CreateIssueBody(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            status: firstKey,
            priority: priority.rawValue,
            projectId: projectId,
            dueDate: hasDue ? DateText.day(from: due) : nil)
        Task {
            let created = await store.create(body)
            saving = false
            if created != nil { dismiss() }
        }
    }
}
