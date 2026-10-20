import SwiftUI
import CalmCore

/// Calm palette, from packages/views/calm/shared.tsx.
enum Calm {
    static let ink = Color(hex: 0x111827)
    static let muted = Color(hex: 0x6B7280)
    static let soft = Color(hex: 0x374151)
    /// The accent the user picked in Altro › Aspetto. Blue by default (the Aria style).
    static var primary: Color { Accent.current.color }
    static let checkbox = Color(hex: 0xC5CBD5)
    static let card = Color(hex: 0xF7F8FA)
    static let field = Color(hex: 0xF3F4F6)
    static let late = Color(hex: 0xC2410C)
    static let warm = Color.white
    static let sand = Color(hex: 0xF1F3F6)
    static let green = Color(hex: 0x058527)
    static let blue = Color(hex: 0x246FE0)
    static let orange = Color(hex: 0xEB8909)
    static let red = Color(hex: 0xD1453B)
    /// The floating bar: a calm, slightly muted red.
    static let bar = Color(hex: 0xD9665C)
    static let line = Color(hex: 0xEEF0F3)

    static func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .urgent, .high: return red
        case .medium: return orange
        case .low: return blue
        case .none: return Color.black.opacity(0.3)
        }
    }

    static func statusColor(_ entry: StatusEntry?) -> Color {
        if let hex = entry?.color, let color = Color(hexString: hex) { return color }
        return Color.black.opacity(0.3)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }
}

struct CalmPillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Calm.soft)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(Capsule().strokeBorder(Calm.line, lineWidth: 1))
    }
}

extension View {
    func calmPill() -> some View { modifier(CalmPillStyle()) }
}

/// Accent colours the user can pick.
enum Accent: String, CaseIterable, Identifiable {
    case blue, red, green, violet, orange, graphite

    static let storageKey = "calm.accent"
    static var current: Accent {
        Accent(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .blue
    }

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(hex: 0x2F6FEB)
        case .red: return Color(hex: 0xDC4C3E)
        case .green: return Color(hex: 0x1F7A5C)
        case .violet: return Color(hex: 0x6D5DE8)
        case .orange: return Color(hex: 0xD9620F)
        case .graphite: return Color(hex: 0x374151)
        }
    }

    var name: String {
        switch self {
        case .blue: return "Blu"
        case .red: return "Rosso"
        case .green: return "Verde"
        case .violet: return "Viola"
        case .orange: return "Arancio"
        case .graphite: return "Grafite"
        }
    }
}

enum DateText {
    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM"
        return f
    }()

    static func date(from day: String) -> Date? { parser.date(from: day) }
    static func day(from date: Date) -> String { parser.string(from: date) }

    static func short(_ day: String) -> String {
        guard let date = parser.date(from: day) else { return day }
        return shortFormatter.string(from: date)
    }

    static func isOverdue(_ day: String) -> Bool { day < Today.dayString() }

    /// "Oggi", "Domani", or the short date.
    static func relative(_ day: String) -> String {
        let today = Today.dayString()
        if day == today { return "Oggi" }
        if let date = date(from: today), let next = Calendar.current.date(byAdding: .day, value: 1, to: date),
           day == Self.day(from: next) { return "Domani" }
        return short(day)
    }
}

extension MentionText {
    /// A comment as styled text: mentions look like chips ("@Name", coloured, on a soft background).
    static func attributed(_ markup: String) -> AttributedString {
        var out = AttributedString()
        for segment in segments(markup) {
            switch segment {
            case .text(let text):
                out += AttributedString(text)
            case .mention(let name, _):
                var chip = AttributedString("\u{2009}@\(name)\u{2009}")
                chip.foregroundColor = Calm.primary
                chip.backgroundColor = Calm.primary.opacity(0.12)
                chip.font = .system(size: 15, weight: .semibold)
                out += chip
            }
        }
        return out
    }
}
