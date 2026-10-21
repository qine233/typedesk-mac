import SwiftUI

struct CommentsListView: View {
    @EnvironmentObject var state: AppState

    private var grouped: [(pending: [TSComment], approved: [TSComment])] {
        let pending = state.comments.filter { $0.status == "pending" }
        let approved = state.comments.filter { $0.status != "pending" && $0.status != "spam" }
        return [(pending, approved)]
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader("评论") {
                Button { Task { await state.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textSecondary)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)
            }

            if state.comments.isEmpty {
                EmptyStateView(title: "暂无评论", subtitle: "连接网站后会自动拉取最近评论\n可直接在这里通过或驳回")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(grouped, id: \.0.count) { g in
                            if !g.pending.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("待审核").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.statusDraft)
                                    ForEach(g.pending) { c in row(c, pending: true) }
                                }
                            }
                            if !g.approved.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("已通过").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.textLight)
                                    ForEach(g.approved) { c in row(c, pending: false) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    private func row(_ c: TSComment, pending: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(c.author.isEmpty ? "匿名" : c.author)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textStrong)
                Text("《\(c.postTitle)》")
                    .font(.system(size: 11)).foregroundColor(Theme.accent).lineLimit(1)
                Spacer()
                Text(c.created, style: .date).font(.system(size: 10)).foregroundColor(Theme.textLight)
            }
            Text(c.content.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12)).foregroundColor(Theme.textMain).lineLimit(3)
            HStack(spacing: 8) {
                if pending {
                    action("通过", "checkmark.circle", Theme.statusPublish) { Task { await state.setComment(c, status: "approved") } }
                    action("垃圾", "xmark.circle", Theme.danger) { Task { await state.setComment(c, status: "spam") } }
                } else if c.status == "approved" {
                    action("撤回", "arrow.uturn.backward.circle", Theme.statusDraft) { Task { await state.setComment(c, status: "pending") } }
                } else {
                    action("恢复", "checkmark.circle", Theme.statusPublish) { Task { await state.setComment(c, status: "approved") } }
                }
                action("删除", "trash", Theme.danger) { Task { await state.deleteComment(c) } }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func action(_ title: String, _ icon: String, _ color: Color, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 11))
            }
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }
}

struct MetaListView: View {
    enum Kind { case categories, tags }
    let kind: Kind
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(kind == .categories ? "分类" : "标签") { EmptyView() }
            Text("点一行可以在文章列表里按它筛选")
                .font(.system(size: 10)).foregroundColor(Theme.textLight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 6) {
                    if kind == .categories {
                        ForEach(state.categories) { cat in
                            MetaRow(icon: "folder.fill", color: Theme.info, name: cat.name,
                                    count: state.posts.filter { $0.categories.contains(cat.name) }.count,
                                    unit: "篇",
                                    active: state.metaFilter == .category(cat.name)) {
                                state.metaFilter = .category(cat.name)
                                state.pane = .posts(DocFilter.all)
                            }
                        }
                    } else {
                        ForEach(state.tags) { tag in
                            MetaRow(icon: "tag.fill", color: Theme.statusDraft, name: tag.name,
                                    count: tag.count, unit: "篇",
                                    active: state.metaFilter == .tag(tag.name)) {
                                state.metaFilter = .tag(tag.name)
                                state.pane = .posts(DocFilter.all)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

private struct MetaRow: View {
    let icon: String
    let color: Color
    let name: String
    let count: Int
    let unit: String
    let active: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 11))
            Text(name).font(.system(size: 13)).foregroundColor(Theme.textMain)
            Spacer()
            if hover && !active {
                Text("筛选文章").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.accent)
            } else {
                Text("\(count) \(unit)").font(.system(size: 11)).foregroundColor(Theme.textLight)
            }
        }
        .padding(10)
        .background(active ? Theme.accentBg : (hover ? Theme.surfaceSoft : Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd)
            .stroke(active ? Theme.accent : (hover ? Theme.cardBorder : Theme.cardBorder), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.13), value: hover)
    }
}
