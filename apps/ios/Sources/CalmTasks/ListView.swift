import SwiftUI
import CalmCore

struct ListView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @AppStorage(Collapsed.storageKey) private var collapsedRaw = ""
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue
    /// Empty sections start folded. These are the empty ones the user opened.
    @AppStorage("calm.expandedEmpty") private var expandedRaw = ""
    @State private var newTaskColumn: StatusEntry?
    @State private var dateIssue: Issue?
    @State private var deleteIssue: Issue?
    @State private var mergePair: MergePair?
    /// The client the list belongs to, used for the "Nuovo task" row.
    var project: Project?
    let resolver: BoardResolver
    let issues: [Issue]
    /// Show the client name on each row. Off when the screen is a single client.
    var showProject = true

    private var density: Density { Density(rawValue: densityRaw) ?? .medium }

    var body: some View {
        let grouped = resolver.group(issues)
        let folded = Collapsed.set(collapsedRaw)
        let expandedEmpty = Collapsed.set(expandedRaw)
        // Section titles are ordinary rows, not List headers: the system adds its own padding to headers.
        List {
            ForEach(resolver.columns) { column in
                let items = grouped[column.key] ?? []
                let isFolded = folded.contains(column.key) || (items.isEmpty && !expandedEmpty.contains(column.key))
                sectionRow(column, count: items.count, isFolded: isFolded, isEmpty: items.isEmpty)
                if !isFolded {
                    if items.isEmpty {
                        Button { newTaskColumn = column } label: {
                            HStack(spacing: DS.Space.s) {
                                Image(systemName: "plus").font(DS.Text.footnote.weight(.semibold))
                                Text("Nuovo task").font(DS.Text.callout)
                            }
                            .foregroundStyle(Calm.primary)
                            .frame(maxWidth: .infinity, minHeight: DS.Size.rowCompact, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .dsListRow()
                    }
                    ForEach(items) { issue in
                        RowLink(value: issue) {
                            TaskRow(issue: issue, resolver: resolver, density: density,
                                    projectName: showProject ? store.project(issue.projectId)?.title : nil)
                        }
                        .dsListRow()
                        // Long press and drag a task onto another one to join them.
                        .draggable(issue.id)
                        .dropDestination(for: String.self) { ids, _ in
                            guard let id = ids.first, id != issue.id,
                                  let source = store.issues.first(where: { $0.id == id }) else { return false }
                            mergePair = MergePair(source: source, target: issue)
                            return true
                        }
                        // Swipe right: done. Swipe left: date, archive, delete, like Mail.
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { Task { await store.move(issue, to: resolver.doneKey) } } label: {
                                Label("Fatto", systemImage: "checkmark")
                            }
                            .tint(Calm.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { Task { await model.investigate(issue) } } label: {
                                Label("AI", systemImage: "sparkles")
                            }
                            .tint(Accent.violet.color)
                            Button { Task { await store.move(issue, to: "cancelled") } } label: {
                                Label("Archivia", systemImage: "archivebox")
                            }
                            .tint(Calm.orange)
                            Button { dateIssue = issue } label: { Label("Data", systemImage: "calendar") }
                                .tint(Calm.blue)
                        }
                        .contextMenu {
                            MoveMenu(issue: issue, resolver: resolver)
                            Button { Task { await model.investigate(issue) } } label: {
                                Label("Fai indagare l'AI", systemImage: "sparkles")
                            }
                            Button(role: .destructive) { deleteIssue = issue } label: { Label("Elimina", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .background(Color.white)
        // Rows set their own heights from DS.Size.
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .refreshable { await store.refresh() }
        .sheet(item: $newTaskColumn) { column in
            NewTaskView(project: project, status: column.key)
        }
        .sheet(item: $dateIssue) { issue in DueDateSheet(issue: issue) }
        .mergeDialog($mergePair)
        .confirmationDialog("Eliminare questo task?", isPresented: Binding(
            get: { deleteIssue != nil }, set: { if !$0 { deleteIssue = nil } }), titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let issue = deleteIssue { Task { await store.delete(issue) } }
                deleteIssue = nil
            }
            Button("Annulla", role: .cancel) { deleteIssue = nil }
        } message: {
            Text(deleteIssue?.title ?? "")
        }
    }

    private func sectionRow(_ column: StatusEntry, count: Int, isFolded: Bool, isEmpty: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isFolded {
                    // Open it: clear any fold and, for an empty section, remember it was opened.
                    var keys = Collapsed.set(collapsedRaw); keys.remove(column.key)
                    collapsedRaw = keys.sorted().joined(separator: ",")
                    if isEmpty { expandedRaw = Collapsed.toggled(column.key, in: expandedRaw) }
                } else {
                    collapsedRaw = Collapsed.toggled(column.key, in: collapsedRaw)
                    var open = Collapsed.set(expandedRaw); open.remove(column.key)
                    expandedRaw = open.sorted().joined(separator: ",")
                }
            }
        } label: {
            SectionTitle(name: column.name, count: count, isFolded: isFolded)
        }
        .buttonStyle(.plain)
        .dsListRow()
        .accessibilityLabel("\(column.name), \(count) task, \(isFolded ? "chiusa" : "aperta")")
    }
}

/// Pick or clear the due date of one task.
struct DueDateSheet: View {
    @EnvironmentObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let issue: Issue
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    quick("Oggi", 0)
                    quick("Domani", 1)
                    quick("Tra una settimana", 7)
                }
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .navigationTitle("Scadenza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        Task { await store.update(issue, UpdateIssueBody(dueDate: DateText.day(from: date))) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    if issue.dueDay != nil {
                        Button("Togli la data", role: .destructive) {
                            Task { await store.update(issue, UpdateIssueBody(clearDueDate: true)) }
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                if let day = issue.dueDay, let existing = DateText.date(from: day) { date = existing }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func quick(_ title: String, _ days: Int) -> some View {
        Button(title) {
            if let target = Calendar.current.date(byAdding: .day, value: days, to: Date()) { date = target }
        }
        .font(.system(size: 14))
        .foregroundStyle(Calm.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Capsule().fill(Calm.sand))
        .buttonStyle(.plain)
    }

}
