import SwiftUI

struct PostRow: View {
    let post: TSPost
    var active = false
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(post.title.isEmpty ? "未命名" : post.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textStrong)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if post.status != TSStatus.published { StatusPill(status: post.status) }
            }
            Text(post.content.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "#", with: "")
                .prefix(70))
                .font(.system(size: 11)).foregroundColor(Theme.textLight).lineLimit(1)
            HStack(spacing: 6) {
                Text(shortDate(post.modified))
                    .font(.system(size: 10)).foregroundColor(Theme.textLight)
                ForEach(post.categories.prefix(2), id: \.self) { c in
                    Text(c).font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Theme.accentBg).clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? Theme.accentBg : (hover ? Theme.surfaceSoft : Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(active ? Theme.accent : (hover ? Theme.cardBorder : .clear), lineWidth: 1)
        )
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .contextMenu {
            Button("在浏览器打开") {
                if let url = URL(string: post.link) { NSWorkspace.shared.open(url) }
            }
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

struct NoteRow: View {
    let note: Note
    var active = false
    var syncedCid = 0
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(note.title).font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textStrong).lineLimit(1)
                if syncedCid > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "icloud").font(.system(size: 8))
                        Text("草稿").font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(Theme.info)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.info.opacity(0.12))
                    .clipShape(Capsule())
                }
                Spacer(minLength: 4)
            }
            HStack {
                Text(note.text.split(separator: "\n").dropFirst().joined(separator: " ")
                    .replacingOccurrences(of: "#", with: "")
                    .prefix(60))
                    .font(.system(size: 11)).foregroundColor(Theme.textLight).lineLimit(1)
                Spacer()
                Text(relative(note.updated)).font(.system(size: 10)).foregroundColor(Theme.textLight)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? Theme.accentBg : (hover ? Theme.surfaceSoft : Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
            .stroke(active ? Theme.accent : (hover ? Theme.cardBorder : .clear), lineWidth: 1))
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

struct PageRow: View {
    let page: TSPage
    var active = false
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.plaintext").font(.system(size: 12)).foregroundColor(Theme.info)
            Text(page.title.isEmpty ? "未命名页面" : page.title)
                .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textStrong).lineLimit(1)
            Spacer()
        }
        .padding(10)
        .background(active ? Theme.accentBg : (hover ? Theme.surfaceSoft : Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
            .stroke(active ? Theme.accent : (hover ? Theme.cardBorder : .clear), lineWidth: 1))
        .onHover { hover = $0 }
    }
}

enum TextStats {
    static func count(_ s: String) -> Int {
        let cjk = s.unicodeScalars.filter {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value)
                || (0x3040...0x30FF).contains($0.value)
        }.count
        let latinWords = s.split(whereSeparator: { c in
            c.isWhitespace || c.isNewline || "，。！？；：、,.!?;:\"'()（）【】《》".contains(c)
        }).filter { chunk in chunk.contains { $0.isLetter || $0.isNumber } &&
            !chunk.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) } }.count
        return cjk + latinWords
    }

    static func readingMinutes(_ words: Int) -> String {
        let m = max(1, Int((Double(words) / 350.0).rounded(.up)))
        return "\(m) 分钟"
    }
}
