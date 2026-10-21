import SwiftUI

/// 一次搜索命中的内容
struct SearchHit: Identifiable, Equatable {
    enum Kind: Hashable {
        case note, post, page

        var icon: String {
            switch self {
            case .note: return "note.text"
            case .post: return "doc.text"
            case .page: return "doc.plaintext"
            }
        }
        var color: Color {
            switch self {
            case .note: return Theme.headingMarker
            case .post: return Theme.accent
            case .page: return Theme.info
            }
        }
        var label: String {
            switch self {
            case .note: return "本地笔记"
            case .post: return "网站文章"
            case .page: return "页面"
            }
        }
        var sectionTitle: String {
            switch self {
            case .note: return "笔记"
            case .post: return "文章"
            case .page: return "页面"
            }
        }
    }

    let id: String            // note: path，其它: kind-cid
    let kind: Kind
    let title: String
    let snippet: String
    let detail: String        // 日期 / 状态 / 分类
    let date: Date
}

enum SearchEngine {
    /// 在笔记、文章、页面里做不区分大小写的全文搜索，每组最多 8 条，按时间倒序
    static func run(query raw: String, notes: [Note], posts: [TSPost], pages: [TSPage],
                    kinds: Set<SearchHit.Kind> = Set(SearchHit.Kind.allCasesOrdered),
                    metaFilter: MetaFilter? = nil) -> [SearchHit] {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 1 else { return [] }
        var hits: [SearchHit] = []

        if kinds.contains(.note) {
            for n in notes {
                guard let m = match(title: n.title, body: n.text, q: q) else { continue }
                hits.append(SearchHit(id: "note-\(n.path)", kind: .note,
                                      title: n.title.isEmpty ? "未命名笔记" : n.title,
                                      snippet: m.snippet,
                                      detail: relative(n.updated), date: n.updated))
            }
        }
        if kinds.contains(.post) {
            let scoped: [TSPost]
            switch metaFilter {
            case .category(let name): scoped = posts.filter { $0.categories.contains(name) }
            case .tag(let name): scoped = posts.filter { $0.tags.contains(name) }
            case nil: scoped = posts
            }
            for p in scoped {
                guard let m = match(title: p.title, body: p.content, q: q) else { continue }
                let extra = ([p.categories, p.tags].flatMap { $0 }.prefix(2)).joined(separator: " · ")
                hits.append(SearchHit(id: "post-\(p.cid)", kind: .post,
                                      title: p.title.isEmpty ? "未命名" : p.title,
                                      snippet: m.snippet,
                                      detail: "\(p.status == TSStatus.published ? "已发布" : "草稿")"
                                        + (extra.isEmpty ? "" : " · \(extra)"),
                                      date: p.modified))
            }
        }
        if kinds.contains(.page) {
            for p in pages {
                guard let m = match(title: p.title, body: p.content, q: q) else { continue }
                hits.append(SearchHit(id: "page-\(p.cid)", kind: .page,
                                      title: p.title.isEmpty ? "未命名页面" : p.title,
                                      snippet: m.snippet, detail: relative(p.created), date: p.created))
            }
        }

        let grouped = Dictionary(grouping: hits, by: { $0.kind })
        var out: [SearchHit] = []
        for kind in [SearchHit.Kind.note, .post, .page] {
            let items = (grouped[kind] ?? []).sorted { $0.date > $1.date }.prefix(8)
            out.append(contentsOf: items)
        }
        return out
    }

    private struct Match { let snippet: String; let found: String }

    private static func match(title: String, body: String, q: String) -> Match? {
        let plain = plainText(body)
        if title.range(of: q, options: .caseInsensitive) != nil {
            let head = plain.isEmpty ? title : String(plain.prefix(80))
            return Match(snippet: head, found: q)
        }
        guard let r = plain.range(of: q, options: .caseInsensitive) else { return nil }
        let lo = max(plain.startIndex,
                     plain.index(r.lowerBound, offsetBy: -34, limitedBy: plain.startIndex) ?? plain.startIndex)
        let hi = min(plain.endIndex,
                     plain.index(r.upperBound, offsetBy: 68, limitedBy: plain.endIndex) ?? plain.endIndex)
        var s = String(plain[lo..<hi])
        if lo > plain.startIndex { s = "…" + s }
        if hi < plain.endIndex { s += "…" }
        return Match(snippet: s, found: q)
    }

    /// 去掉 Markdown / HTML 痕迹，只留可读文本
    static func plainText(_ s: String) -> String {
        var t = s
        if HTMLToMarkdown.looksLikeHTML(t) { t = HTMLToMarkdown.convert(t) }
        t = t.replacingOccurrences(of: "`", with: "")
        t = t.replacingOccurrences(of: "*", with: "")
        t = t.replacingOccurrences(of: "#", with: "")
        t = t.replacingOccurrences(of: ">", with: "")
        t = t.replacingOccurrences(of: "\n", with: " ")
        t = t.replacingOccurrences(of: "  ", with: " ")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 把片段按命中词切成 (文本, 是否命中) 的若干段，用于高亮
    static func highlight(_ text: String, _ q: String) -> [(String, Bool)] {
        guard !q.isEmpty else { return [(text, false)] }
        var parts: [(String, Bool)] = []
        var rest = Substring(text)
        while let r = rest.range(of: q, options: .caseInsensitive) {
            if r.lowerBound != rest.startIndex {
                parts.append((String(rest[rest.startIndex..<r.lowerBound]), false))
            }
            parts.append((String(rest[r]), true))
            rest = rest[r.upperBound...]
        }
        if !rest.isEmpty { parts.append((String(rest), false)) }
        return parts
    }

    static func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

/// ⌘K 命令面板式搜索
struct SearchPalette: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var notes: NoteStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [SearchHit] = []
    @State private var kindsOn: Set<SearchHit.Kind> = Set(SearchHit.Kind.allCasesOrdered)
    @State private var respectMetaFilter = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider().overlay(Theme.borderSoft)
            content
            footer
        }
        .frame(width: 640, height: 460)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        .onAppear { inputFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.accent)
            TextField("搜索笔记、文章、页面…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($inputFocused)
                .onChange(of: query) { _ in recompute() }
                .onSubmit {
                    let list = query.trimmingCharacters(in: .whitespaces).isEmpty
                        ? (recents.first?.items ?? []) : results
                    if let first = list.first { open(first) }
                }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textLight)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private func recompute() {
        results = SearchEngine.run(query: query, notes: notes.notes,
                                   posts: state.posts, pages: state.pages,
                                   kinds: kindsOn,
                                   metaFilter: respectMetaFilter ? state.metaFilter : nil)
    }

    /// 类型开关 + 是否沿用当前的分类/标签筛选
    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(SearchHit.Kind.allCasesOrdered, id: \.self) { kind in
                let on = kindsOn.contains(kind)
                Button {
                    if on {
                        if kindsOn.count > 1 { kindsOn.remove(kind) }
                    } else {
                        kindsOn.insert(kind)
                    }
                    recompute()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: kind.icon).font(.system(size: 9, weight: .bold))
                        Text(kind.sectionTitle).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(on ? Theme.accent : Theme.textLight)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(on ? Theme.accentBg : Color.clear)
                    .overlay(Capsule().stroke(on ? Theme.accent.opacity(0.45) : Theme.cardBorder, lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if state.metaFilter != nil {
                Button {
                    respectMetaFilter.toggle()
                    recompute()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: respectMetaFilter ? "line.3.horizontal.decrease.circle.fill"
                                                           : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10))
                        Text(state.metaFilter?.label ?? "")
                            .font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .foregroundColor(respectMetaFilter ? Theme.accent : Theme.textLight)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(respectMetaFilter ? Theme.accentBg : Color.clear)
                    .overlay(Capsule().stroke(respectMetaFilter ? Theme.accent.opacity(0.45) : Theme.cardBorder,
                                             lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("只搜当前分类/标签下的文章")
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    private var grouped: [(kind: SearchHit.Kind, items: [SearchHit])] {
        SearchHit.Kind.allCasesOrdered.compactMap { kind -> (SearchHit.Kind, [SearchHit])? in
            let items = results.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    /// 空查询时展示「最近」，面板一打开就有东西可点
    private var recents: [(kind: SearchHit.Kind, items: [SearchHit])] {
        var list: [SearchHit] = []
        for n in notes.notes.sorted(by: { $0.updated > $1.updated }).prefix(4) {
            let body = SearchEngine.plainText(n.text)
            list.append(SearchHit(id: "note-\(n.path)", kind: .note,
                                  title: n.title.isEmpty ? "未命名笔记" : n.title,
                                  snippet: String(body.prefix(70)),
                                  detail: SearchEngine.relative(n.updated), date: n.updated))
        }
        for p in state.posts.sorted(by: { $0.modified > $1.modified }).prefix(5) {
            list.append(SearchHit(id: "post-\(p.cid)", kind: .post,
                                  title: p.title.isEmpty ? "未命名" : p.title,
                                  snippet: String(SearchEngine.plainText(p.content).prefix(70)),
                                  detail: p.status == TSStatus.published ? "已发布" : "草稿",
                                  date: p.modified))
        }
        return SearchHit.Kind.allCasesOrdered.compactMap { kind -> (SearchHit.Kind, [SearchHit])? in
            let items = list.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    @ViewBuilder
    private var content: some View {
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let pairs = searching ? grouped : recents
        if pairs.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: searching ? "magnifyingglass" : "sparkles")
                    .font(.system(size: 24)).foregroundColor(Theme.textLight)
                Text(searching ? "没有找到「\(query)」" : "还没有内容")
                    .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textMain)
                Text(searching ? "站点数据（体重 / 记账）请在对应面板里查"
                               : "输入关键词，同时搜本地笔记与站点内容")
                    .font(.system(size: 11)).foregroundColor(Theme.textLight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !searching {
                        Text("最近")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textLight)
                            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 2)
                    }
                    ForEach(pairs, id: \.kind) { pair in
                        SearchGroupSection(kind: pair.kind, items: pair.items,
                                           query: searching ? query : "", open: open)
                    }
                }
                .padding(.vertical, 6)
            }
            .background(Theme.bg)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HintKey(title: "回车", desc: "打开第一条")
            HintKey(title: "Esc", desc: "关闭")
            Spacer()
            Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                 ? "最近 \(recents.reduce(0) { $0 + $1.items.count }) 条"
                 : "\(results.count) 条结果")
                .font(.system(size: 10)).foregroundColor(Theme.textLight)
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surfaceSoft)
    }

    private func open(_ hit: SearchHit) {
        switch hit.kind {
        case .note:
            state.pane = .notes
            state.openNotePath = hit.id.hasPrefix("note-") ? String(hit.id.dropFirst(5)) : hit.id
        case .post:
            state.pane = .posts(DocFilter.all)
            state.openPostCid = Int(hit.id.split(separator: "-").last.map(String.init) ?? "")
        case .page:
            state.pane = .pages
            state.openPageCid = Int(hit.id.split(separator: "-").last.map(String.init) ?? "")
        }
        dismiss()
    }
}

private struct SearchGroupSection: View {
    let kind: SearchHit.Kind
    let items: [SearchHit]
    let query: String
    let open: (SearchHit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind.sectionTitle)
                .font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textLight)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            ForEach(items) { hit in
                SearchHitRow(hit: hit, query: query)
                    .onTapGesture { open(hit) }
                    .id(hit.id)
            }
        }
    }
}

private struct SearchHitRow: View {
    let hit: SearchHit
    let query: String
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hit.kind.icon)
                .font(.system(size: 12, weight: .semibold)).foregroundColor(hit.kind.color)
                .frame(width: 20, height: 20)
                .background(hit.kind.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 2) {
                HighlightText(text: hit.title, query: query, size: 13, weight: .medium)
                if !hit.snippet.isEmpty && hit.snippet != hit.title {
                    HighlightText(text: hit.snippet, query: query, size: 11, weight: .regular,
                                  base: Theme.textLight)
                }
            }
            Spacer(minLength: 8)
            Text(hit.detail).font(.system(size: 10)).foregroundColor(Theme.textLight).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(hover ? Theme.accentBg : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

struct HighlightText: View {
    let text: String
    let query: String
    let size: CGFloat
    let weight: Font.Weight
    var base: Color = Theme.textStrong

    var body: some View {
        let parts = SearchEngine.highlight(text, query)
        parts.reduce(Text("")) { acc, part in
            let t = Text(part.0).font(.system(size: size, weight: part.1 ? .semibold : weight))
            return acc + t.foregroundColor(part.1 ? Theme.accent : base)
        }
        .lineLimit(2)
    }
}

private struct HintKey: View {
    let title: String
    let desc: String
    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Theme.card).overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.cardBorder, lineWidth: 1))
            Text(desc).font(.system(size: 10)).foregroundColor(Theme.textLight)
        }
    }
}

extension SearchHit.Kind {
    static let allCasesOrdered: [SearchHit.Kind] = [.note, .post, .page]
}
