import SwiftUI

struct MarkdownPreview: View {
    let source: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blockViews().enumerated()), id: \.offset) { _, view in
                    view
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.bg)
    }

    private enum Block {
        case heading(level: Int, text: String)
        case quote(text: String)
        case code(text: String)
        case listItem(ordered: Bool, index: Int, text: String)
        case paragraph(text: String)
    }

    private func blocks() -> [Block] {
        var out: [Block] = []
        var inCode = false
        var codeBuf: [String] = []
        var paraBuf: [String] = []
        var orderedIdx = 0

        func flushPara() {
            if !paraBuf.isEmpty {
                out.append(.paragraph(text: paraBuf.joined(separator: "\n")))
                paraBuf = []
            }
        }

        for raw in source.components(separatedBy: "\n") {
            let line = raw
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    out.append(.code(text: codeBuf.joined(separator: "\n")))
                    codeBuf = []
                    inCode = false
                } else {
                    flushPara()
                    inCode = true
                }
                continue
            }
            if inCode { codeBuf.append(line); continue }

            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { flushPara(); orderedIdx = 0; continue }

            if t.hasPrefix("#") {
                flushPara()
                let level = t.prefix(while: { $0 == "#" }).count
                out.append(.heading(level: min(level, 4), text: String(t.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
            } else if t.hasPrefix("> ") {
                flushPara()
                out.append(.quote(text: String(t.dropFirst(2))))
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                flushPara()
                out.append(.listItem(ordered: false, index: 0, text: String(t.dropFirst(2))))
            } else if let dot = t.firstIndex(of: "."), t[...t.index(before: dot)].allSatisfy({ $0.isNumber }),
                      t.hasPrefix("\(t[t.startIndex..<dot]). ") {
                orderedIdx += 1
                out.append(.listItem(ordered: true, index: orderedIdx,
                                     text: String(t.drop(while: { !$0.isWhitespace })).trimmingCharacters(in: .whitespaces)))
            } else {
                paraBuf.append(t)
            }
        }
        if inCode { out.append(.code(text: codeBuf.joined(separator: "\n"))) }
        flushPara()
        return out
    }

    private func inline(_ s: String) -> Text {
        let attributed = (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ))
        if let attributed {
            return Text(attributed)
                .font(.system(size: 15))
                .foregroundColor(Theme.textMain)
        }
        return Text(s).font(.system(size: 15)).foregroundColor(Theme.textMain)
    }

    private func blockViews() -> [AnyView] {
        blocks().map { block in
            switch block {
            case .heading(let level, let text):
                return AnyView(
                    (inline(text).font(headingFont(level)).bold())
                        .foregroundColor(Theme.textStrong)
                        .overlay(alignment: .leading) {
                            if level <= 2 {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Theme.headingMarker)
                                    .frame(width: 3)
                                    .offset(x: -10)
                            }
                        }
                        .padding(.top, level <= 2 ? 8 : 2)
                )
            case .quote(let text):
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(Theme.accent.opacity(0.5)).frame(width: 3)
                        inline(text).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 2)
                )
            case .code(let text):
                return AnyView(
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.textMain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.surfaceSunken)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                )
            case .listItem(let ordered, let index, let text):
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text(ordered ? "\(index)." : "•")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.accent)
                        inline(text)
                    }
                    .padding(.leading, 4)
                )
            case .paragraph(let text):
                return AnyView(inline(text))
            }
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 26, weight: .bold)
        case 2: return .system(size: 21, weight: .bold)
        case 3: return .system(size: 17, weight: .semibold)
        default: return .system(size: 15, weight: .semibold)
        }
    }
}
