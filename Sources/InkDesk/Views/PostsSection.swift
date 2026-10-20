import SwiftUI

struct PostsSection: View {
    @EnvironmentObject var state: AppState
    @State private var editing: TSPost?
    @State private var searchText = ""

    private var filtered: [TSPost] {
        guard !searchText.isEmpty else { return state.posts }
        let q = searchText.lowercased()
        return state.posts.filter { $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if let post = editing {
                PostEditorView(post: post, isNew: post.cid == 0, onBack: { editing = nil })
                    .environmentObject(state)
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ErrorBanner(message: $state.lastError)
            HStack {
                Text("网站文章").font(.system(size: 17, weight: .bold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button {
                    editing = TSPost(cid: 0, title: "", content: "", categories: [], tags: [],
                                     slug: "", status: TSStatus.draft, created: Date(), modified: Date(),
                                     link: "", allowComment: true)
                } label: {
                    Label("新文章", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.accent).foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if state.loading && state.posts.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if state.posts.isEmpty {
                EmptyStateView(title: "还没有拉到文章",
                               subtitle: "登录成功后会自动同步最近 50 篇\n若为空请先在设置中连接网站")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { post in
                            PostRow(post: post)
                                .onTapGesture { select(post) }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Theme.bg)
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索文章")
        .refreshable { await state.refresh() }
    }

    private func select(_ post: TSPost) {
        Task {
            if let full = await state.loadPost(post.cid) {
                editing = full
            } else {
                editing = post
            }
        }
    }
}

struct PostRow: View {
    let post: TSPost
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(post.title.isEmpty ? "未命名" : post.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textStrong)
                        .lineLimit(1)
                    StatusPill(status: post.status)
                }
                Text(post.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(90))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textLight)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(post.modified, style: .date)
                        .font(.system(size: 11)).foregroundColor(Theme.textLight)
                    ForEach(post.categories, id: \.self) { c in
                        Text(c).font(.system(size: 11))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.accentBg)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Image(systemName: hover ? "chevron.right.circle.fill" : "chevron.right.circle")
                .foregroundColor(hover ? Theme.accent : Theme.textLight)
                .scaleEffect(hover ? 1.1 : 1)
                .animation(.spring(response: 0.25), value: hover)
        }
        .padding(12)
        .inkCard(hover: hover)
        .onHover { hover = $0 }
        .contextMenu {
            Button("在浏览器打开") {
                if let url = URL(string: post.link) { NSWorkspace.shared.open(url) }
            }
            Button("删除", role: .destructive) {}
        }
    }
}
