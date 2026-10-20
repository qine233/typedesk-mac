import SwiftUI
import AppKit

struct SidebarRow: View {
    let icon: String
    let color: Color
    let title: String
    let count: Int?
    let badge: Int?
    @State private var hover = false

    init(_ icon: String, _ color: Color, _ title: String, count: Int? = nil, badge: Int? = nil) {
        self.icon = icon; self.color = color; self.title = title; self.count = count; self.badge = badge
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18)
            Text(title).font(.system(size: 13))
            Spacer()
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Theme.danger)
                    .clipShape(Capsule())
            } else if let count {
                Text("\(count)").font(.system(size: 11)).foregroundColor(Theme.textLight)
                    .opacity(hover ? 0 : 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var notes: NoteStore
    @State private var pane: Pane = .notes
    @State private var selectedNote: Note?
    @State private var editingPost: TSPost?
    @State private var editingPage: TSPage?
    @State private var showSettings = false
    @State private var filter = DocFilter.all

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            middle
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task { if !state.connected { await state.refresh() } }
    }

    // MARK: 侧栏

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accent, Theme.headingMarker.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text("NLtypedesk").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textStrong)
                    Text(state.connected ? state.blogName : "未连接网站")
                        .font(.system(size: 10)).foregroundColor(Theme.textLight).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            List(selection: $pane) {
                Section("写作") {
                    SidebarRow("note.text", Theme.headingMarker, "本地笔记", count: notes.notes.count)
                        .tag(Pane.notes)
                    SidebarRow("doc.text", Theme.accent, "全部文章", count: state.posts.count)
                        .tag(Pane.posts(DocFilter.all))
                    SidebarRow("moon.doc", Theme.statusDraft, "草稿",
                               count: state.posts.filter { $0.status != TSStatus.published }.count)
                        .tag(Pane.posts(DocFilter.draft))
                    SidebarRow("checkmark.seal", Theme.statusPublish, "已发布",
                               count: state.posts.filter { $0.status == TSStatus.published }.count)
                        .tag(Pane.posts(DocFilter.published))
                }
                Section("站点管理") {
                    SidebarRow("folder", Theme.info, "分类", count: state.categories.count)
                        .tag(Pane.categories)
                    SidebarRow("tag", Theme.statusDraft, "标签", count: state.tags.count)
                        .tag(Pane.tags)
                    SidebarRow("doc.plaintext", Theme.textSecondary, "页面", count: state.pages.count)
                        .tag(Pane.pages)
                    SidebarRow("bubble.left.text", Theme.accent, "评论",
                               badge: state.pendingComments)
                        .tag(Pane.comments)
                }
                Section("站点数据") {
                    SidebarRow("heart.text.square", Theme.statusPublish, "健康记录",
                               count: state.healthData?.count)
                        .tag(Pane.health)
                    SidebarRow("cart", Theme.headingMarker, "买菜记账",
                               count: state.billsData?.count)
                        .tag(Pane.bills)
                }
            }
            .listStyle(.sidebar)

            Divider().overlay(Theme.borderSoft)
            HStack {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").foregroundColor(Theme.textSecondary)
                }.buttonStyle(.plain)
                Button { Task { await state.refresh() } } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(state.loading ? Theme.textLight : Theme.accent)
                        .rotationEffect(.degrees(state.loading ? 360 : 0))
                        .animation(state.loading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                   value: state.loading)
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 230)
    }

    // MARK: 中栏

    @ViewBuilder
    private var middle: some View {
        switch pane {
        case .notes:
            notesList
        case .posts(let f):
            postsList(f)
        case .pages:
            pagesList
        case .comments:
            CommentsListView().frame(minWidth: 360)
        case .categories:
            MetaListView(kind: .categories)
        case .tags:
            MetaListView(kind: .tags)
        case .health:
            HealthMiddleListView()
        case .bills:
            BillsMiddleListView()
        }
    }

    private var notesList: some View {
        VStack(spacing: 0) {
            PaneHeader("本地笔记") {
                Button { selectedNote = notes.create() } label: { paneButton("新建", "plus") }
            }
            if notes.notes.isEmpty {
                EmptyStateView(title: "写下第一篇笔记", subtitle: "笔记保存在本机\n随时可一键发布到网站")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(notes.notes) { note in
                            NoteRow(note: note, active: selectedNote?.path == note.path)
                                .onTapGesture { selectedNote = note }
                                .contextMenu {
                                    Button("删除", role: .destructive) {
                                        notes.delete(note)
                                        if selectedNote?.path == note.path { selectedNote = nil }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 14)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    private func postsList(_ f: DocFilter) -> some View {
        VStack(spacing: 0) {
            PaneHeader("网站文章") {
                Button {
                    selectedNote = nil
                    editingPage = nil
                    editingPost = TSPost(cid: 0, title: "", content: "", categories: [], tags: [],
                                         slug: "", status: TSStatus.draft, created: Date(), modified: Date(),
                                         link: "", allowComment: true)
                } label: { paneButton("新文章", "square.and.pencil") }
            }
            Picker("", selection: $filter) {
                ForEach(DocFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(.horizontal, 10).padding(.bottom, 8)
            .fixedSize()

            if state.posts.isEmpty && !state.loading {
                EmptyStateView(title: "还没有文章", subtitle: "在设置中连接网站后自动同步\n点击左上角刷新按钮重试")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredPosts(f)) { post in
                            PostRow(post: post, active: editingPost?.cid == post.cid && post.cid != 0)
                                .onTapGesture {
                                    selectedNote = nil
                                    editingPage = nil
                                    Task { editingPost = await state.loadPost(post.cid) ?? post }
                                }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 14)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    private var pagesList: some View {
        VStack(spacing: 0) {
            PaneHeader("页面") {
                Button {
                    editingPage = TSPage(cid: 0, title: "", content: "", created: Date())
                } label: { paneButton("新建页面", "plus") }
            }
            if state.pages.isEmpty {
                EmptyStateView(title: "暂无独立页面", subtitle: "关于我、友情链接等单页可在此管理")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.pages) { page in
                            PageRow(page: page, active: editingPage?.cid == page.cid && page.cid != 0)
                                .onTapGesture {
                                    Task { editingPage = await state.loadPage(page.cid) ?? page }
                                }
                                .contextMenu {
                                    Button("删除", role: .destructive) { Task { await state.deletePage(page) } }
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    private func filteredPosts(_ f: DocFilter) -> [TSPost] {
        switch f {
        case .all: return state.posts
        case .draft: return state.posts.filter { $0.status != TSStatus.published }
        case .published: return state.posts.filter { $0.status == TSStatus.published }
        }
    }

    private func paneButton(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.accent).foregroundColor(.white)
        .clipShape(Capsule())
    }

    // MARK: 右栏

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            ErrorBanner(message: $state.lastError)
            if let post = editingPost {
                PostEditorView(post: post, onBack: { editingPost = nil },
                               onDelete: { Task { await state.delete(post); editingPost = nil } })
                    .id("post-\(post.cid)-\(post.created.timeIntervalSince1970)")
                    .environmentObject(state)
            } else if let page = editingPage {
                PageEditorView(page: page, onBack: { editingPage = nil })
                    .id("page-\(page.cid)")
                    .environmentObject(state)
            } else if let note = selectedNote {
                NoteEditorView(note: note, onBack: nil)
                    .id("note-\(note.path)")
                    .environmentObject(state)
                    .environmentObject(notes)
            } else if pane == .health {
                HealthDetailView().environmentObject(state)
            } else if pane == .bills {
                BillsDetailView().environmentObject(state)
            } else {
                placeholder
            }
        }
        .frame(minWidth: 460)
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            EmptyInkIllustration()
            Text("从左侧选择内容开始写作")
                .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.textMain)
            Text("新文章 ⌘⇧N · 新笔记 ⌘N · 预览 ⇧⌘P")
                .font(.system(size: 11)).foregroundColor(Theme.textLight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

struct PaneHeader: View {
    let title: String
    var trailing: AnyView?
    init(_ title: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.textStrong)
            Spacer()
            trailing
        }
        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 10)
    }
}
