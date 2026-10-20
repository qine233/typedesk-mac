import SwiftUI
import AppKit

enum EditorMode: String, CaseIterable, Identifiable {
    case write = "写作"
    case split = "分屏"
    case preview = "预览"
    var id: String { rawValue }
}

struct PostEditorView: View {
    @EnvironmentObject var state: AppState

    @State var post: TSPost
    var onBack: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var mode: EditorMode = .write
    @State private var tagsInput = ""
    @State private var saving = false
    @State private var savedFlash = false
    @State private var showInspector = false
    @State private var uploadingImage = false
    @State private var dirty = false
    private let bridge = EditorBridge()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider().overlay(Theme.cardBorder)
                editorArea
                Divider().overlay(Theme.cardBorder)
                statusBar
            }
            if showInspector {
                Divider().overlay(Theme.cardBorder)
                InspectorView(post: $post, tagsInput: $tagsInput,
                              uploadingImage: $uploadingImage, onUpload: uploadImage,
                              onDelete: onDelete, isNew: post.cid == 0)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Theme.bg)
        .onAppear { tagsInput = post.tags.joined(separator: ", ") }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showInspector)
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 10) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26).background(Theme.surfaceSoft)
                    .clipShape(Circle()).foregroundColor(Theme.textMain)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(".", modifiers: [.command])

            TextField("标题", text: $post.title)
                .textFieldStyle(.plain)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Theme.textStrong)
                .onChange(of: post.title) { _ in dirty = true }

            Picker("", selection: $mode) {
                ForEach(EditorMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()

            Toggle(isOn: $showInspector) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(showInspector ? Theme.accent : Theme.textSecondary)
            }
            .toggleStyle(.button).buttonStyle(.plain).labelsHidden()

            saveMenu
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.card)
    }

    private var saveMenu: some View {
        Menu {
            Button("保存为草稿") { Task { await save(publish: false) } }
            Button(post.cid == 0 ? "发布到网站" : "更新并发布") { Task { await save(publish: true) } }
        } label: {
            if saving {
                ProgressView().controlSize(.small).frame(width: 64, height: 22)
            } else {
                Text(post.cid == 0 ? "发布" : "保存")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Theme.accent).foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .keyboardShortcut("s", modifiers: [.command])
    }

    // MARK: 编辑区

    @ViewBuilder
    private var editorArea: some View {
        switch mode {
        case .write:
            MarkdownEditor(text: $post.content, bridge: bridge)
                .background(Theme.bg)
        case .preview:
            MarkdownPreview(source: post.content)
        case .split:
            HSplitView {
                MarkdownEditor(text: $post.content, bridge: bridge)
                    .background(Theme.bg)
                    .frame(minWidth: 300)
                MarkdownPreview(source: post.content)
                    .frame(minWidth: 300)
            }
        }
    }

    // MARK: 底部统计

    private var statusBar: some View {
        let words = TextStats.count(post.content)
        return HStack(spacing: 14) {
            Text("\(words) 词").foregroundColor(Theme.textLight).font(.system(size: 11))
            Text("\(TextStats.readingMinutes(words))阅读").foregroundColor(Theme.textLight).font(.system(size: 11))
            if post.cid > 0 { StatusPill(status: post.status) }
            Spacer()
            if savedFlash {
                Label("已保存", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundColor(Theme.statusPublish)
                    .transition(.opacity)
            } else if dirty {
                Text("未保存").font(.system(size: 11)).foregroundColor(Theme.statusDraft)
            }
            Text("本地草稿自动留存").font(.system(size: 10)).foregroundColor(Theme.textLight).opacity(0.7)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Theme.card)
    }

    // MARK: 动作

    private func save(publish: Bool) async {
        saving = true
        defer { saving = false }
        var p = post
        p.tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        post.tags = p.tags
        if let cid = await state.publish(p, publish: publish) {
            post.cid = cid
            post.status = publish ? TSStatus.published : TSStatus.draft
            dirty = false
            withAnimation(.spring(response: 0.3)) { savedFlash = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { savedFlash = false }
        }
    }

    private func uploadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        let type = url.pathExtension.lowercased() == "png" ? "image/png"
            : (url.pathExtension.lowercased() == "gif" ? "image/gif" : "image/jpeg")
        uploadingImage = true
        Task {
            if let link = await state.uploadImage(name: url.lastPathComponent, type: type, data: data) {
                bridge.insert("\n![\(url.deletingPathExtension().lastPathComponent)](\(link))\n")
                dirty = true
            }
            uploadingImage = false
        }
    }
}

// MARK: 检查器

struct InspectorView: View {
    @EnvironmentObject var state: AppState
    @Binding var post: TSPost
    @Binding var tagsInput: String
    @Binding var uploadingImage: Bool
    var onUpload: () -> Void
    var onDelete: () -> Void
    let isNew: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("发布") {
                    Menu {
                        ForEach(state.categories) { cat in
                            Button {
                                if post.categories.contains(cat.name) {
                                    post.categories.removeAll { $0 == cat.name }
                                } else {
                                    post.categories.append(cat.name)
                                }
                            } label: {
                                Label(cat.name, systemImage: post.categories.contains(cat.name) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: { EmptyView() }.frame(width: 0)

                    FlowLayout(spacing: 6) {
                        ForEach(post.categories, id: \.self) { c in
                            HStack(spacing: 4) {
                                Text(c).font(.system(size: 11))
                                Button { post.categories.removeAll { $0 == c } } label: {
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.accentBg).foregroundColor(Theme.accent)
                            .clipShape(Capsule())
                        }
                        Text("+ 添加分类").font(.system(size: 11)).foregroundColor(Theme.textLight)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay(Capsule().strokeBorder(Theme.borderStrong, style: .init(lineWidth: 1, dash: [3])))
                    }
                }

                section("标签") {
                    TextField("逗号分隔", text: $tagsInput)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12))
                }

                section("Slug") {
                    TextField("留空自动生成", text: $post.slug)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12))
                }

                section("讨论") {
                    Toggle("允许评论", isOn: $post.allowComment)
                        .font(.system(size: 12)).toggleStyle(.switch)
                }

                section("配图") {
                    Button(action: onUpload) {
                        HStack(spacing: 5) {
                            if uploadingImage { ProgressView().controlSize(.small) }
                            Label("上传并插入图片", systemImage: "photo.on.rectangle")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textMain)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                    }
                    .buttonStyle(.plain)
                }

                if !isNew, !post.link.isEmpty {
                    section("链接") {
                        Button {
                            if let url = URL(string: post.link) { NSWorkspace.shared.open(url) }
                        } label: {
                            Label("查看线上文章", systemImage: "arrow.up.right.square")
                                .font(.system(size: 12))
                        }.buttonStyle(.link)
                    }
                }

                if !isNew {
                    section("危险操作") {
                        Button(role: .destructive) { onDelete() } label: {
                            Label("删除这篇文章", systemImage: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(Theme.surfaceSoft)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textLight)
            content()
        }
    }
}
