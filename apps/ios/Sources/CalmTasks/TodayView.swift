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
        VStack(alignment: .leading, spacing: 0) {
            HStack { MenuButton(); Spacer() }
                .padding(.horizontal, 8)
                .frame(height: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill").font(.system(size: 24)).foregroundStyle(Color(hex: 0xF5B301))
                    Text("Oggi").font(.system(size: 32, weight: .heavy)).tracking(-0.5).foregroundStyle(Calm.ink)
                }
                Text("\(TodayHeader.date) · \(due.count) task").font(.system(size: 15)).foregroundStyle(Calm.muted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        List {
            if due.isEmpty && store.hasLoaded {
                ContentUnavailableView("Niente per oggi", systemImage: "sun.max", description: Text("Nessun task in scadenza."))
                    .listRowBackground(Color.clear)
            }
            ForEach(due) { issue in
                NavigationLink(value: issue) {
                    TaskRow(issue: issue, resolver: store.resolver(for: store.project(issue.projectId)), density: density,
                            projectName: store.project(issue.projectId)?.title) {
                        let r = store.resolver(for: store.project(issue.projectId))
                        Task { await store.move(issue, to: r.doneKey) }
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)
        .background(Calm.warm)
        .refreshable { await store.refresh() }
        }
        .background(Calm.warm.ignoresSafeArea())
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
