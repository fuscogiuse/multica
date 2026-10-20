import SwiftUI
import CalmCore

/// What the Task tab shows, chosen from the sidebar.
enum BoardScope: Hashable {
    case all
    case area(String)
    case project(String)
}

/// Open and close state of the sidebar, shared with the screens that carry the menu button.
@MainActor
final class SidebarState: ObservableObject {
    @Published var isOpen = false
    @Published var startsInManageMode = false
    func open() { isOpen = true }
    func close() { isOpen = false }
}

/// Clients the user chose to hide from the sidebar. Stored on this device as a comma separated list of project ids.
enum HiddenProjects {
    static let storageKey = "calm.hiddenProjects"
    static func set(_ raw: String) -> Set<String> { Set(raw.split(separator: ",").map(String.init)) }
    static func toggled(_ id: String, in raw: String) -> String {
        var ids = set(raw)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        return ids.sorted().joined(separator: ",")
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var sidebar: SidebarState

    @AppStorage(HiddenProjects.storageKey) private var hiddenRaw = ""
    @AppStorage("calm.openAreas") private var openRaw = ""

    @State private var manage = false
    @State private var revealed: Set<String> = []

    let onToday: () -> Void
    let onScope: (BoardScope) -> Void

    private var hidden: Set<String> { HiddenProjects.set(hiddenRaw) }
    private var openAreas: Set<String> { Collapsed.set(openRaw) }

    private func openCount(_ project: Project) -> Int {
        let resolver = store.resolver(for: project)
        return store.issues(in: project).filter { resolver.column(for: $0) != nil }.count
    }

    private var todayCount: Int {
        Today.dueOrOverdue(store.issues, resolver: store.resolver(for: nil), today: Today.dayString()).count
    }

    private var allOpenCount: Int {
        let resolver = store.resolver(for: nil)
        return store.issues.filter { resolver.column(for: $0) != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 2) {
                    row(icon: "calendar", title: "Oggi", count: todayCount, accent: true) { onToday() }
                    row(icon: "checklist", title: "Tutti i task", count: allOpenCount, accent: false) { onScope(.all) }

                    HStack {
                        Text("Aree").font(.system(size: 12, weight: .semibold)).foregroundStyle(Calm.muted)
                        Spacer()
                        Button(manage ? "Fine" : "Gestisci") { withAnimation { manage.toggle() } }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Calm.primary)
                            .frame(minHeight: 36)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 14)

                    ForEach(store.companies) { company in
                        areaSection(id: company.id, name: company.name, colorHex: company.color,
                                    projects: store.projects(in: company), scope: .area(company.id))
                    }
                    let loose = store.projects(in: nil)
                    if !loose.isEmpty {
                        areaSection(id: "none", name: "Senza area", colorHex: nil, projects: loose, scope: nil)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
            }
            footer
        }
        .frame(maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            if sidebar.startsInManageMode { manage = true; sidebar.startsInManageMode = false }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8).fill(Calm.primary)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
            Text("Calm Tasks").font(.system(size: 17, weight: .semibold)).foregroundStyle(Calm.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            Text("basato su Multica")
                .font(.system(size: 12))
                .foregroundStyle(Calm.muted)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
    }

    private func row(icon: String, title: String, count: Int, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Calm.soft).frame(width: 22)
                Text(title).font(.system(size: 16)).foregroundStyle(Calm.ink)
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.system(size: 12, weight: accent ? .semibold : .regular))
                        .foregroundStyle(accent ? Calm.primary : Calm.muted)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func areaSection(id: String, name: String, colorHex: String?, projects: [Project], scope: BoardScope?) -> some View {
        let isOpen = openAreas.contains(id)
        let hiddenHere = projects.filter { hidden.contains($0.id) }
        let visible = projects.filter { !hidden.contains($0.id) }
        let total = projects.reduce(0) { $0 + openCount($1) }

        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { openRaw = Collapsed.toggled(id, in: openRaw) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Calm.muted)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isOpen ? "Chiudi" : "Apri") l'elenco di \(name)")

            Button {
                if let scope { onScope(scope) } else {
                    withAnimation(.easeInOut(duration: 0.18)) { openRaw = Collapsed.toggled(id, in: openRaw) }
                }
            } label: {
                HStack(spacing: 10) {
                    Circle().fill(colorHex.flatMap { Color(hexString: $0) } ?? Calm.muted).frame(width: 10, height: 10)
                    Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Calm.ink)
                    Spacer()
                    Text("\(total)").font(.system(size: 12)).foregroundStyle(Calm.muted)
                }
                .padding(.trailing, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apri la vista di \(name), \(total) task")
        }

        if isOpen {
            VStack(spacing: 0) {
                ForEach(manage ? projects : visible) { project in
                    if manage {
                        manageRow(project)
                    } else {
                        projectRow(title: project.title, count: openCount(project), dimmed: false, bold: false) {
                            onScope(.project(project.id))
                        }
                    }
                }
                if !manage, !hiddenHere.isEmpty {
                    Button {
                        withAnimation { if revealed.contains(id) { revealed.remove(id) } else { revealed.insert(id) } }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash").font(.system(size: 12))
                            Text(hiddenHere.count == 1 ? "1 cliente nascosto" : "\(hiddenHere.count) clienti nascosti")
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .foregroundStyle(Calm.muted)
                        .padding(.leading, 10)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if revealed.contains(id) {
                        ForEach(hiddenHere) { project in
                            projectRow(title: project.title, count: openCount(project), dimmed: true, bold: false) {
                                onScope(.project(project.id))
                            }
                        }
                    }
                }
            }
            .padding(.leading, 26)
            .padding(.bottom, 4)
        }
    }

    private func projectRow(title: String, count: Int?, dimmed: Bool, bold: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: bold ? .semibold : .regular))
                    .foregroundStyle(dimmed ? Calm.muted : Calm.ink)
                    .lineLimit(1)
                Spacer()
                if let count { Text("\(count)").font(.system(size: 12)).foregroundStyle(Calm.muted) }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func manageRow(_ project: Project) -> some View {
        let isHidden = hidden.contains(project.id)
        return HStack {
            Text(project.title)
                .font(.system(size: 15))
                .foregroundStyle(isHidden ? Calm.muted : Calm.ink)
                .lineLimit(1)
            Spacer()
            Button {
                hiddenRaw = HiddenProjects.toggled(project.id, in: hiddenRaw)
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 17))
                    .foregroundStyle(isHidden ? Calm.muted : Calm.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHidden ? "Mostra \(project.title)" : "Nascondi \(project.title)")
        }
        .padding(.leading, 10)
        .frame(minHeight: 44)
        .background(isHidden ? Color(hex: 0xFAF9F7) : Color.clear)
    }
}
