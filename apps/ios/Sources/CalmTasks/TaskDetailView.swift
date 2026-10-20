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
    @State private var mentionables: [Mentionable] = []
    @State private var chosenMentions: [Mentionable] = []
    @State private var loadedId: String?
    @State private var editingNotes = false
    @State private var showDate = false
    @FocusState private var focus: Field?

    private enum Field { case title, notes, comment }

    private var mentionSuggestions: [Mentionable] {
        guard focus == .comment, let query = MentionText.activeQuery(in: newComment) else { return [] }
        return MentionText.suggestions(mentionables, matching: query.text)
    }

    private func pick(_ person: Mentionable) {
        guard let query = MentionText.activeQuery(in: newComment) else { return }
        newComment = MentionText.inserting(person, over: query, in: newComment)
        if !chosenMentions.contains(person) { chosenMentions.append(person) }
    }

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
                HStack(alignment: .top, spacing: 14) {
                    Button { Task { await store.move(issue, to: resolver.doneKey) } } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Calm.checkbox, lineWidth: 2)
                            .frame(width: 26, height: 26)
                            .padding(.top, 4)
                            .frame(width: 36, height: 40, alignment: .top)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Segna come fatto")
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Titolo", text: $title, axis: .vertical)
                            .font(.system(size: 24, weight: .bold))
                            .focused($focus, equals: .title)
                            .onSubmit { saveTitle(issue) }
                            .submitLabel(.done)
                        Text(issue.identifier).font(.system(size: 13)).foregroundStyle(Calm.muted)
                    }
                }

                VStack(spacing: 0) {
                    propertyRow(icon: "folder", label: "Cliente", value: project?.title ?? "Nessuno")
                    Menu {
                        ForEach(resolver.columns) { column in
                            Button(column.name) { Task { await store.move(issue, to: column.key) } }
                        }
                    } label: {
                        propertyRow(icon: "circle.dashed", label: "Stato", value: resolver.name(for: issue.status),
                                    valueColor: Calm.primary, chevron: true)
                    }
                    Button { showDate = true } label: {
                        propertyRow(icon: "calendar", label: "Scadenza",
                                    value: issue.dueDay.map { DateText.relative($0) } ?? "Nessuna",
                                    valueColor: issue.dueDay.map { DateText.isOverdue($0) ? Calm.late : Calm.ink } ?? Calm.muted,
                                    chevron: true)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showDate) { DueDateSheet(issue: issue) }
                    Menu {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Button(priority.italian) { Task { await store.update(issue, UpdateIssueBody(priority: priority.rawValue)) } }
                        }
                    } label: {
                        propertyRow(icon: "flag", label: "Priorità", value: issue.priorityValue.italian, chevron: true)
                    }
                    if issue.assigneeType == "agent" {
                        propertyRow(icon: "sparkles", label: "Agente",
                                    value: mentionables.first { $0.id == issue.assigneeId }?.name ?? "Agente")
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Calm.line).frame(height: 1) }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Note").font(.footnote.weight(.medium)).foregroundStyle(Calm.soft)
                        Spacer()
                        if editingNotes {
                            Button("Fine") { commitEdits(issue); editingNotes = false; focus = nil }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Calm.primary)
                        } else if !notes.isEmpty {
                            Button("Modifica") { editingNotes = true; focus = .notes }
                                .font(.system(size: 14))
                                .foregroundStyle(Calm.primary)
                        }
                    }
                    if editingNotes {
                        TextEditor(text: $notes)
                            .frame(minHeight: 200)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Calm.line))
                            .focused($focus, equals: .notes)
                    } else if notes.isEmpty {
                        Button { editingNotes = true; focus = .notes } label: {
                            Text("Aggiungi note…")
                                .font(.system(size: 15)).foregroundStyle(Calm.muted)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Calm.line))
                        }
                        .buttonStyle(.plain)
                    } else {
                        MarkdownText(source: notes, size: 16)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { editingNotes = true; focus = .notes }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Commenti").font(.footnote.weight(.medium)).foregroundStyle(Calm.soft)
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.authorType == "agent" ? "Agente" : "Tu")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(Calm.muted)
                            MarkdownText(source: comment.content)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Calm.card))
                    }
                    if !mentionSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(mentionSuggestions) { person in
                                Button { pick(person) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: person.kind == .agent ? "sparkles" : "person.fill")
                                            .font(.system(size: 13)).foregroundStyle(Calm.primary).frame(width: 20)
                                        Text(person.name).font(.system(size: 15)).foregroundStyle(Calm.ink).lineLimit(1)
                                        Spacer()
                                        Text(person.kind == .agent ? "Agente" : "Membro")
                                            .font(.system(size: 12)).foregroundStyle(Calm.muted)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if person.id != mentionSuggestions.last?.id { Divider() }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Calm.line))
                    }
                    HStack {
                        TextField("Scrivi un commento, @ per un agente", text: $newComment, axis: .vertical)
                            .focused($focus, equals: .comment)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 50)
                            .background(Capsule().fill(Calm.field))
                        Button { Task { await sendComment(issue) } } label: {
                            Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(Circle().fill(Calm.primary))
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

    private func propertyRow(icon: String, label: String, value: String, valueColor: Color = Calm.ink, chevron: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Calm.muted).frame(width: 22)
            Text(label).font(.system(size: 16)).foregroundStyle(Calm.muted)
            Spacer()
            Text(value).font(.system(size: 16, weight: valueColor == Calm.primary ? .semibold : .regular)).foregroundStyle(valueColor).lineLimit(1)
            if chevron {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(Calm.checkbox)
            }
        }
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) { Rectangle().fill(Calm.line).frame(height: 1) }
        .contentShape(Rectangle())
    }

    private func dueButton(_ issue: Issue) -> some View {
        Button { showDate = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 13))
                Text(issue.dueDay.map { DateText.relative($0) } ?? "Scadenza")
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .foregroundStyle(issue.dueDay.map { DateText.isOverdue($0) ? Calm.red : Calm.ink } ?? Calm.soft)
            .calmPill()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDate) { DueDateSheet(issue: issue) }
    }

    // MARK: Actions

    private func load() async {
        guard let issue, loadedId != issue.id else { return }
        loadedId = issue.id
        title = issue.title
        notes = issue.description ?? ""
        if let client = model.auth.client {
            comments = (try? await client.comments(issueId: issue.id)) ?? []
            mentionables = await client.mentionables()
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
        let typed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty, let client = model.auth.client else { return }
        // "@Name" becomes the markup that makes the server start the agent.
        let text = MentionText.toMarkup(typed, mentions: chosenMentions)
        do {
            let comment = try await client.addComment(issueId: issue.id, content: text)
            comments.append(comment)
            newComment = ""
            chosenMentions = []
        } catch {
            store.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
