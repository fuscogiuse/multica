import SwiftUI
import CalmCore

/// Calm palette, from packages/views/calm/shared.tsx.
enum Calm {
    static let ink = Color(hex: 0x202020)
    static let muted = Color(hex: 0x666666)
    static let soft = Color(hex: 0x4B4B4B)
    static let primary = Color(hex: 0xDC4C3E)
    static let warm = Color(hex: 0xFCFAF8)
    static let sand = Color(hex: 0xF6F4F1)
    static let green = Color(hex: 0x058527)
    static let blue = Color(hex: 0x246FE0)
    static let orange = Color(hex: 0xEB8909)
    static let red = Color(hex: 0xD1453B)
    static let line = Color.black.opacity(0.08)

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
