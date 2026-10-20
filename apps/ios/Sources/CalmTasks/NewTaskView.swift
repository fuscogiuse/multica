import SwiftUI
import CalmCore

struct NewTaskView: View {
    @EnvironmentObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    /// Put the new task straight into this status. Nil uses the first column of the project.
    var status: String?

    @State private var title = ""
    @State private var projectId: String?
    @State private var priority: Priority = .none
    @State private var hasDue = false
    @State private var due = Date()
    @State private var saving = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Cosa c'è da fare?", text: $title, axis: .vertical)
                        .focused($focused)
                        .font(.system(size: 17))
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
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") { save() }
                        .fontWeight(.semibold)
                        .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                projectId = project?.id
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
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
