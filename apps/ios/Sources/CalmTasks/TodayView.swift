import SwiftUI
import CalmCore

/// Due today and overdue. The caller wraps it in a NavigationStack.
struct TodayView: View {
    @EnvironmentObject var store: BoardStore
    @AppStorage(Density.storageKey) private var densityRaw = Density.medium.rawValue

    private var density: Density { Density(rawValue: densityRaw) ?? .medium }

    var body: some View {
        let resolver = store.resolver(for: nil)
        let due = Today.dueOrOverdue(store.issues, resolver: resolver, today: Today.dayString())
        VStack(spacing: 0) {
            ScreenHeader(subtitle: "\(TodayHeader.date) · \(due.count) task") {
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "star.fill").font(.system(size: 22)).foregroundStyle(Color(hex: 0xF5B301))
                    LargeTitle(text: "Oggi")
                }
            }
            List {
                if due.isEmpty && store.hasLoaded {
                    ContentUnavailableView("Niente per oggi", systemImage: "sun.max", description: Text("Nessun task in scadenza."))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(due) { issue in
                    let r = store.resolver(for: store.project(issue.projectId))
                    RowLink(value: issue) {
                        TaskRow(issue: issue, resolver: r, density: density, projectName: store.project(issue.projectId)?.title)
                    }
                    .dsListRow()
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { Task { await store.move(issue, to: r.doneKey) } } label: { Label("Fatto", systemImage: "checkmark") }
                            .tint(Calm.green)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, density == .compact ? DS.Size.rowCompact : DS.Size.rowMedium)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .refreshable { await store.refresh() }
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Issue.self) { issue in TaskDetailView(issueId: issue.id) }
    }
}

enum TodayHeader {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()
    static var date: String { formatter.string(from: Date()).capitalized(with: Locale(identifier: "it_IT")) }
}
