import SwiftUI
import CalmCore

/// What the Task tab shows, chosen from the sidebar.
enum BoardScope: Hashable {
    case all
    case area(String)
    case project(String)
}

/// Position of the sidebar, shared with the screens that carry the menu button.
/// `x` runs from -width (closed) to 0 (open). Only the sidebar layer and the menu button watch it,
/// so dragging does not redraw the screens underneath.
@MainActor
final class SidebarState: ObservableObject {
    static let width: CGFloat = 308

    @Published var x: CGFloat = -SidebarState.width

    var isVisible: Bool { x > -Self.width + 0.5 }
    var isOpen: Bool { x > -Self.width / 2 }
    var progress: Double { Double(max(0, min(1, 1 + x / Self.width))) }

    func open() { settle(open: true) }
    func close() { settle(open: false) }

    func settle(open: Bool) {
        withAnimation(.interpolatingSpring(stiffness: 260, damping: 30)) { x = open ? 0 : -Self.width }
    }

    func follow(_ translation: CGFloat, from start: CGFloat) {
        x = max(-Self.width, min(0, start + translation))
    }
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

struct SidebarView: View, Equatable {
    /// The inputs are closures, so the sidebar is redrawn only when the data it watches changes, not on every drag step.
    static func == (lhs: SidebarView, rhs: SidebarView) -> Bool { true }

    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var sidebar: SidebarState

    @AppStorage(HiddenProjects.storageKey) private var hiddenRaw = ""
    @State private var showManage = false

    let onToday: () -> Void
    let onScope: (BoardScope) -> Void

    private var hidden: Set<String> { HiddenProjects.set(hiddenRaw) }

    private func openCount(_ project: Project) -> Int { store.openCounts[project.id] ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 2) {
                    row(icon: "calendar", title: "Oggi", count: store.todayCount, accent: true) { onToday() }
                    row(icon: "checklist", title: "Tutti i task", count: store.allOpenCount, accent: false) { onScope(.all) }

                    Text("Aree")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Calm.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(store.companies) { company in
                        areaRow(id: company.id, name: company.name, colorHex: company.color,
                                projects: store.projects(in: company), scope: .area(company.id))
                    }
                    let loose = store.projects(in: nil)
                    if !loose.isEmpty {
                        areaRow(id: "none", name: "Senza area", colorHex: nil, projects: loose, scope: nil)
                    }

                    Button { showManage = true } label: {
                        Label("Gestisci i clienti", systemImage: "eye.slash")
                            .font(.system(size: 14))
                            .foregroundStyle(Calm.primary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                    Text("Tocca un'area per aprirla. Tieni premuto per scegliere un cliente.")
                        .font(.system(size: 12))
                        .foregroundStyle(Calm.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
            }
            footer
        }
        .frame(maxHeight: .infinity)
        .background(Color.white)
        .sheet(isPresented: $showManage) { ManageClientsView() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8).fill(Calm.primary)
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white))
            Text("Calm Tasks").font(.system(size: 19, weight: .semibold)).foregroundStyle(Calm.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
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
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Calm.soft).frame(width: 24)
                Text(title).font(.system(size: 16)).foregroundStyle(Calm.ink)
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.system(size: 13, weight: accent ? .semibold : .regular))
                        .foregroundStyle(accent ? Calm.primary : Calm.muted)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// An area. Tap opens it. Long press shows its clients, with a way to hide the ones used rarely.
    private func areaRow(id: String, name: String, colorHex: String?, projects: [Project], scope: BoardScope?) -> some View {
        let visible = projects.filter { !hidden.contains($0.id) }
        let hiddenHere = projects.filter { hidden.contains($0.id) }
        let total = projects.reduce(0) { $0 + openCount($1) }

        return Button {
            if let scope { onScope(scope) }
        } label: {
            HStack(spacing: 12) {
                Circle().fill(colorHex.flatMap { Color(hexString: $0) } ?? Calm.muted).frame(width: 11, height: 11)
                Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Calm.ink).lineLimit(1)
                Spacer()
                Text("\(total)").font(.system(size: 13)).foregroundStyle(Calm.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(total) task")
        .accessibilityHint("Tieni premuto per scegliere un cliente")
        .contextMenu {
            if let scope {
                Button { onScope(scope) } label: { Label("Tutti i progetti di \(name)", systemImage: "square.grid.2x2") }
            }
            if !visible.isEmpty {
                Section("Clienti") {
                    ForEach(visible) { project in
                        Button(project.title) { onScope(.project(project.id)) }
                    }
                }
            }
            Button { showManage = true } label: { Label("Nascondi più clienti…", systemImage: "eye.slash") }
            if !hiddenHere.isEmpty {
                Menu {
                    ForEach(hiddenHere) { project in
                        Menu(project.title) {
                            Button("Apri") { onScope(.project(project.id)) }
                            Button("Mostra di nuovo") { hiddenRaw = HiddenProjects.toggled(project.id, in: hiddenRaw) }
                        }
                    }
                } label: { Label("Nascosti (\(hiddenHere.count))", systemImage: "eye") }
            }
        }
    }
}

/// Choose which clients show in the sidebar, many at once.
struct ManageClientsView: View {
    @EnvironmentObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HiddenProjects.storageKey) private var hiddenRaw = ""

    private var hidden: Set<String> { HiddenProjects.set(hiddenRaw) }

    private func setHidden(_ ids: [String], _ on: Bool) {
        var all = hidden
        for id in ids { if on { all.insert(id) } else { all.remove(id) } }
        hiddenRaw = all.sorted().joined(separator: ",")
    }

    private func binding(_ project: Project) -> Binding<Bool> {
        Binding(get: { !hidden.contains(project.id) }, set: { setHidden([project.id], !$0) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.companies) { company in section(company.name, projects: store.projects(in: company)) }
                let loose = store.projects(in: nil)
                if !loose.isEmpty { section("Senza area", projects: loose) }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Clienti nella barra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() }.fontWeight(.semibold) } }
        }
        .presentationDetents([.large])
    }

    private func section(_ name: String, projects: [Project]) -> some View {
        let ids = projects.map(\.id)
        let allHidden = !ids.isEmpty && ids.allSatisfy { hidden.contains($0) }
        return Section {
            ForEach(projects) { project in
                Toggle(project.title, isOn: binding(project)).tint(Calm.primary)
            }
        } header: {
            HStack {
                Text(name)
                Spacer()
                Button(allHidden ? "Mostra tutti" : "Nascondi tutti") { setHidden(ids, !allHidden) }
                    .font(.system(size: 13, weight: .medium))
                    .textCase(nil)
            }
        }
    }
}
