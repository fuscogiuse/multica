import SwiftUI
import CalmCore

/// A task dropped on another one.
struct MergePair: Identifiable {
    let source: Issue
    let target: Issue
    var id: String { source.id + ">" + target.id }
}

/// Asks whether to join two tasks, then does it. The kept task gets the other one's notes and comments,
/// the earlier due date and the higher priority. The other task goes to Annullato with a link back.
struct MergeDialog: ViewModifier {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @Binding var pair: MergePair?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Unire i due task?",
            isPresented: Binding(get: { pair != nil }, set: { if !$0 { pair = nil } }),
            titleVisibility: .visible,
            presenting: pair
        ) { pair in
            Button("Tieni «\(short(pair.target.title))»") { run(source: pair.source, target: pair.target) }
            Button("Tieni «\(short(pair.source.title))»") { run(source: pair.target, target: pair.source) }
            Button("Annulla", role: .cancel) {}
        } message: { pair in
            Text("«\(pair.source.title)» e «\(pair.target.title)» diventano un solo task. Note e commenti di entrambi restano.")
        }
    }

    private func short(_ title: String) -> String {
        title.count > 28 ? String(title.prefix(27)) + "…" : title
    }

    private func run(source: Issue, target: Issue) {
        Task {
            let client = model.auth.client
            let comments = (try? await client?.comments(issueId: source.id)) ?? []
            let description = IssueMerge.mergedDescription(target: target, source: source, sourceComments: comments)
            let due = IssueMerge.mergedDueDay(target, source)
            await store.update(target, UpdateIssueBody(
                description: description,
                priority: IssueMerge.mergedPriority(target, source),
                dueDate: due))
            await store.move(source, to: "cancelled")
            _ = try? await client?.addComment(issueId: target.id,
                content: "Unito con \(source.identifier): \(source.title)")
            _ = try? await client?.addComment(issueId: source.id,
                content: "Unito in \(target.identifier): \(target.title)")
        }
    }
}

extension View {
    func mergeDialog(_ pair: Binding<MergePair?>) -> some View { modifier(MergeDialog(pair: pair)) }
}
