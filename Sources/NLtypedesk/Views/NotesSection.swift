import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var state: AppState

    let note: Note
    var onBack: (() -> Void)?

    @State private var text = ""
    @State private var mode: EditorMode = .write
    @State private var publishing = false
    @State private var publishedFlash = false
    @State private var saveTask: Task<Void, Never>?
    @State private var savedFlash = false
    @State private var syncing = false
    @State private var syncedFlash = false

    /// 已同步到站点的正文，避免同内容重复提交（editPost 全量覆盖）
    @MainActor static var lastSynced: [String: String] = [:]

    private var title: String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return first.hasPrefix("# ") ? String(first.dropFirst(2)) : "未命名笔记"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let onBack {
                    Button { onBack() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26).background(Theme.surfaceSoft)
                            .clipShape(Circle()).foregroundColor(Theme.textMain)
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.textStrong)
                    .lineLimit(1)

                Spacer()

                Picker("", selection: $mode) {
                    ForEach(EditorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()

                if publishedFlash {
                    Label("已发布", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundColor(Theme.statusPublish)
                        .transition(.opacity)
                }

                Menu {
                    Button("存为草稿") { Task { await publish(publish: false) } }
                    Button("发布到网站") { Task { await publish(publish: true) } }
                } label: {
                    if publishing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card)
            Divider().overlay(Theme.cardBorder)

            switch mode {
            case .write: MarkdownEditor(text: $text).background(Theme.bg)
            case .preview: MarkdownPreview(source: text)
            case .split:
                HSplitView {
                    MarkdownEditor(text: $text).frame(minWidth: 300)
                    MarkdownPreview(source: text).frame(minWidth: 300)
                }
            }

            Divider().overlay(Theme.cardBorder)
            HStack(spacing: 14) {
                Text("\(TextStats.count(text)) 词").font(.system(size: 11)).foregroundColor(Theme.textLight)
                Text("本机 Markdown 文件").font(.system(size: 10)).foregroundColor(Theme.textLight).opacity(0.7)
                if noteStore.remoteCid(for: note.path) > 0 {
                    Text("已关联站点草稿 #\(noteStore.remoteCid(for: note.path))")
                        .font(.system(size: 10)).foregroundColor(Theme.textLight).opacity(0.7)
                }
                Spacer()
                if syncing {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("同步草稿…").font(.system(size: 11)).foregroundColor(Theme.textLight)
                    }
                    .transition(.opacity)
                }
                if syncedFlash {
                    Text("草稿已同步到网站").font(.system(size: 11)).foregroundColor(Theme.statusPublish)
                        .transition(.opacity)
                }
                if savedFlash {
                    Text("已保存").font(.system(size: 11)).foregroundColor(Theme.statusPublish)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Theme.card)
        }
        .onAppear { text = note.text }
        .onChange(of: text) { newValue in
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                var updated = note
                updated.text = newValue
                noteStore.save(updated)
                withAnimation { savedFlash = true }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation { savedFlash = false }
                await syncDraft(newValue)
            }
        }
    }

    /// 自动把笔记同步成 Typecho 草稿：首次 newPost 拿 cid 记住，之后一律 editPost
    private func syncDraft(_ newText: String) async {
        guard state.api != nil else { return }
        let t = title
        var body = newText
        if body.hasPrefix("# \(t)\n") { body = String(body.dropFirst(t.count + 3)) }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, t != "未命名笔记",
              NoteEditorView.lastSynced[note.path] != body else { return }
        syncing = true
        let ok = await state.syncNoteDraft(path: note.path, title: t, body: body, via: noteStore)
        syncing = false
        if ok {
            NoteEditorView.lastSynced[note.path] = body
            withAnimation { syncedFlash = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { syncedFlash = false }
        }
    }

    private func publish(publish: Bool) async {
        publishing = true
        defer { publishing = false }
        var body = text
        if body.hasPrefix("# \(title)\n") { body = String(body.dropFirst(title.count + 3)) }
        let cid = noteStore.remoteCid(for: note.path)
        let post = TSPost(cid: cid, title: title, content: body, categories: [], tags: [],
                          slug: "", status: TSStatus.draft, created: Date(), modified: Date(),
                          link: "", allowComment: true)
        if let newCid = await state.publish(post, publish: publish) {
            if newCid > 0 { noteStore.setRemoteCid(note.path, newCid) }
            NoteEditorView.lastSynced[note.path] = body
            withAnimation { publishedFlash = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { publishedFlash = false }
        }
    }
}
