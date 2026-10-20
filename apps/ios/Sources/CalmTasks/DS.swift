import SwiftUI

/// The design system for every screen: one spacing scale, one type scale, one set of radii and row heights.
/// Screens use these names only, never raw numbers, so spacing and sizes stay the same everywhere.
enum DS {
    /// Spacing scale on a 4 pt grid.
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    /// Left and right margin of every screen.
    static let gutter: CGFloat = 20

    enum Radius {
        static let s: CGFloat = 7
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Text {
        static let largeTitle = Font.system(size: 30, weight: .heavy)
        static let title = Font.system(size: 22, weight: .bold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 16)
        static let callout = Font.system(size: 15)
        static let section = Font.system(size: 14, weight: .bold)
        static let footnote = Font.system(size: 13)
        static let caption = Font.system(size: 12, weight: .medium)
    }

    /// Heights.
    enum Size {
        static let topBar: CGFloat = 44
        static let iconButton: CGFloat = 44
        static let rowMedium: CGFloat = 66
        static let rowSingle: CGFloat = 54
        static let rowCompact: CGFloat = 46
        static let section: CGFloat = 40
        static let property: CGFloat = 48
        static let checkbox: CGFloat = 22
        static let checkboxCompact: CGFloat = 18
        static let field: CGFloat = 48
    }
}

/// Top of every main screen: a 44 pt bar of icon buttons, then the large title and its subtitle.
struct ScreenHeader<Title: View, Trailing: View>: View {
    let subtitle: String?
    @ViewBuilder var title: () -> Title
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                MenuButton()
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.horizontal, DS.gutter - (DS.Size.iconButton - 22) / 2)
            .frame(height: DS.Size.topBar)

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                title()
                if let subtitle {
                    Text(subtitle).font(DS.Text.callout).foregroundStyle(Calm.muted).lineLimit(1)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.top, DS.Space.xs)
            .padding(.bottom, DS.Space.m)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(subtitle: String?, @ViewBuilder title: @escaping () -> Title) {
        self.subtitle = subtitle
        self.title = title
        self.trailing = { EmptyView() }
    }
}

/// A plain large title for ScreenHeader.
struct LargeTitle: View {
    let text: String
    var body: some View {
        Text(text).font(DS.Text.largeTitle).tracking(-0.4).foregroundStyle(Calm.ink).lineLimit(1)
    }
}

/// An icon-only button with a 44 pt target and a 22 pt glyph.
struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color = Calm.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: DS.Size.iconButton, height: DS.Size.iconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The 44 pt glyph used as a Menu label, same look as IconButton.
struct IconLabel: View {
    let systemName: String
    var tint: Color = Calm.ink
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: DS.Size.iconButton, height: DS.Size.iconButton)
            .contentShape(Rectangle())
    }
}

extension View {
    /// List row with the design-system margins, no separator and no system chevron.
    func dsListRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: DS.gutter, bottom: 0, trailing: DS.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.white)
    }
}

/// Wraps a row so it navigates without the system chevron.
struct RowLink<Value: Hashable, Content: View>: View {
    let value: Value
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            NavigationLink(value: value) { EmptyView() }.opacity(0)
            content()
        }
    }
}

/// The title of a group of tasks, the same in Lista and Kanban: name in the accent colour, count, fold arrow.
struct SectionTitle: View {
    let name: String
    let count: Int
    var isFolded = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Text(name).font(DS.Text.section).foregroundStyle(Calm.primary)
            Text("\(count)").font(DS.Text.footnote).foregroundStyle(Calm.muted)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Calm.muted)
                .rotationEffect(.degrees(isFolded ? -90 : 0))
        }
        .frame(height: DS.Size.section)
        .padding(.top, DS.Space.s)
        .contentShape(Rectangle())
    }
}
