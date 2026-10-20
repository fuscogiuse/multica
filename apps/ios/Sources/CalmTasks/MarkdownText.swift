import SwiftUI
import CalmCore

/// Renders the markdown that Multica descriptions and comments use: **bold**, *italic*, `code`, links,
/// headings, bullet and numbered lists, quotes. Mentions show as chips. Plain Text would show the raw symbols.
struct MarkdownText: View {
    let source: String
    var size: CGFloat = 15

    private enum Line {
        case blank
        case heading(Int, String)
        case bullet(String)
        case numbered(String, String)
        case quote(String)
        case body(String)
    }

    private var lines: [Line] {
        source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n").map(parse)
    }

    private func parse(_ raw: String) -> Line {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { return .blank }

        let hashes = line.prefix { $0 == "#" }
        if (1...4).contains(hashes.count) {
            let rest = line.dropFirst(hashes.count)
            if rest.hasPrefix(" ") { return .heading(hashes.count, rest.trimmingCharacters(in: .whitespaces)) }
        }
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return .bullet(String(line.dropFirst(marker.count)))
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, digits.count <= 3 {
            let rest = line.dropFirst(digits.count)
            if let sep = rest.first, sep == "." || sep == ")", rest.dropFirst().hasPrefix(" ") {
                return .numbered(String(digits), rest.dropFirst(2).trimmingCharacters(in: .whitespaces))
            }
        }
        if line.hasPrefix(">") {
            return .quote(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        return .body(line)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in row(line) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Calm.primary)
    }

    @ViewBuilder
    private func row(_ line: Line) -> some View {
        switch line {
        case .blank:
            Color.clear.frame(height: 4)
        case .heading(let level, let text):
            Text(MarkdownText.inline(text, size: size + CGFloat(max(0, 4 - level)), weight: .bold))
                .padding(.top, 4)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(.system(size: size)).foregroundStyle(Calm.muted)
                Text(MarkdownText.inline(text, size: size))
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").font(.system(size: size)).foregroundStyle(Calm.muted)
                Text(MarkdownText.inline(text, size: size))
            }
        case .quote(let text):
            HStack(spacing: 8) {
                Rectangle().fill(Calm.line.opacity(2)).frame(width: 3)
                Text(MarkdownText.inline(text, size: size)).foregroundStyle(Calm.soft)
            }
        case .body(let text):
            Text(MarkdownText.inline(text, size: size))
        }
    }

    /// One line of inline markdown as styled text. `[@Name](mention://…)` becomes a chip.
    static func inline(_ text: String, size: CGFloat, weight: Font.Weight = .regular) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
        attributed.font = .system(size: size, weight: weight)
        attributed.foregroundColor = Calm.ink
        for run in attributed.runs {
            guard let url = run.link else {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attributed[run.range].font = .system(size: size - 1, design: .monospaced)
                    attributed[run.range].backgroundColor = Calm.sand
                }
                continue
            }
            if url.scheme == "mention" {
                attributed[run.range].link = nil
                attributed[run.range].foregroundColor = Calm.primary
                attributed[run.range].backgroundColor = Calm.primary.opacity(0.12)
                attributed[run.range].font = .system(size: size, weight: .semibold)
            } else {
                attributed[run.range].foregroundColor = Calm.primary
                attributed[run.range].underlineStyle = .single
            }
        }
        return attributed
    }
}

/// Lays children out in rows and wraps to the next row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
