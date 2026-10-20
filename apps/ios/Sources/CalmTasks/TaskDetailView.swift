import SwiftUI
import CalmCore

struct TaskDetailView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    let issueId: String

    @State private var title = ""
    @State private var notes = ""
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var loadedId: String?
    @State private var hasDue = false
    @State private var dueDate = Date()
    @FocusState private var focus: Field?

    private enum Field { case title, notes, comment }

    private var issue: Issue? { store.issues.first { $0.id == issueId } }

    var body: some View {
        Group {
            if let issue {
                content(issue)
            } else {
                ContentUnavailableView("Task non trovato", systemImage: "questionmark.circle")
            }
        }
        .background(Calm.warm.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(_ issue: Issue) -> some View {
        let project = store.project(issue.projectId)
        let resolver = store.resolver(for: project)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Titolo", text: $title, axis: .vertical)
                    .font(.system(size: 22, weight: .semibold))
                    .focused($focus, equals: .title)
                    .onSubmit { saveTitle(issue) }
                    .submitLabel(.done)

                Text([project?.title, issue.identifier].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Calm.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        statusMenu(issue, resolver: resolver)
                        priorityMenu(issue)
                        dueControl(issue)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Note").font(.footnote.weight(.medium)).foregroundStyle(Calm.soft)
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Calm.line))
                        .focused($focus, equals: .notes)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Commenti").font(.footnote.weight(.medium)).foregroundStyle(Calm.soft)
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.authorType == "agent" ? "Agente" : "Tu")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(Calm.muted)
                            Text(comment.content).font(.system(size: 15)).foregroundStyle(Calm.ink)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                    }
                    HStack {
                        TextField("Scrivi un commento", text: $newComment, axis: .vertical)
                            .focused($focus, equals: .comment)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                        Button { Task { await sendComment(issue) } } label: {
                            Image(systemName: "paperplane.fill").frame(width: 44, height: 44)
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Invia")
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fatto") { commitEdits(issue); focus = nil }
            }
        }
        .onDisappear { commitEdits(issue) }
    }

    // MARK: Pills

    private func statusMenu(_ issue: Issue, resolver: BoardResolver) -> some View {
        Menu {
            ForEach(resolver.columns) { column in
                Button(column.name) { Task { await store.move(issue, to: column.key) } }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Calm.statusColor(resolver.entry(for: issue.status))).frame(width: 9, height: 9)
                Text(resolver.name(for: issue.status))
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .calmPill()
        }
    }

    private func priorityMenu(_ issue: Issue) -> some View {
        Menu {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button(priority.italian) { Task { await store.update(issue, UpdateIssueBody(priority: priority.rawValue)) } }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Calm.priorityColor(issue.priorityValue)).frame(width: 9, height: 9)
                Text(issue.priorityValue == .none ? "Priorità" : issue.priorityValue.italian)
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .calmPill()
        }
    }

    private func dueControl(_ issue: Issue) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $hasDue)
                .labelsHidden()
                .onChange(of: hasDue) { _, on in
                    if !on, issue.dueDay != nil { Task { await store.update(issue, UpdateIssueBody(clearDueDate: true)) } }
                    if on, issue.dueDay == nil { Task { await store.update(issue, UpdateIssueBody(dueDate: DateText.day(from: dueDate))) } }
                }
            if hasDue {
                DatePicker("", selection: $dueDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: dueDate) { _, date in
                        Task { await store.update(issue, UpdateIssueBody(dueDate: DateText.day(from: date))) }
                    }
            } else {
                Text("Scadenza").font(.system(size: 13)).foregroundStyle(Calm.soft)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Capsule().strokeBorder(Calm.line, lineWidth: 1))
    }

    // MARK: Actions

    private func load() async {
        guard let issue, loadedId != issue.id else { return }
        loadedId = issue.id
        title = issue.title
        notes = issue.description ?? ""
        if let day = issue.dueDay, let date = DateText.date(from: day) { hasDue = true; dueDate = date }
        if let client = model.auth.client {
            comments = (try? await client.comments(issueId: issue.id)) ?? []
        }
    }

    private func saveTitle(_ issue: Issue) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != issue.title else { return }
        Task { await store.update(issue, UpdateIssueBody(title: trimmed)) }
    }

    private func commitEdits(_ issue: Issue) {
        saveTitle(issue)
        if notes != (issue.description ?? "") {
            Task { await store.update(issue, UpdateIssueBody(description: notes)) }
        }
    }

    private func sendComment(_ issue: Issue) async {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = model.auth.client else { return }
        do {
            let comment = try await client.addComment(issueId: issue.id, content: text)
            comments.append(comment)
            newComment = ""
        } catch {
            store.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
