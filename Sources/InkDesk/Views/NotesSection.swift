import SwiftUI

struct NotesSection: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var state: AppState
    @State private var editingPath: String?
    @State private var showPublishSheet = false

    var body: some View {
        Group {
            if let path = editingPath, let note = noteStore.notes.first(where: { $0.path == path }) {
                NoteEditorView(note: note, onBack: { editingPath = nil })
                    .environmentObject(state)
                    .environmentObject(noteStore)
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack {
                Text("本地笔记").font(.system(size: 17, weight: .bold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button {
                    editingPath = noteStore.create().path
                } label: {
                    Label("新建笔记", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.accent).foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if noteStore.notes.isEmpty {
                EmptyStateView(title: "写下第一篇笔记",
                               subtitle: "笔记保存在本机，随时可以一键发布到 www.zhouzhou.work")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(noteStore.notes) { note in
                            NoteRow(note: note)
                                .onTapGesture { editingPath = note.path }
                                .contextMenu {
                                    Button("删除", role: .destructive) { noteStore.delete(note) }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Theme.bg)
    }
}

struct NoteRow: View {
    let note: Note
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.textStrong).lineLimit(1)
                Text(note.text.replacingOccurrences(of: "#", with: "")
                    .split(separator: "\n").dropFirst().joined(separator: " ")
                    .prefix(80))
                    .font(.system(size: 12)).foregroundColor(Theme.textLight).lineLimit(1)
            }
            Spacer()
            Text(note.updated, style: .relative)
                .font(.system(size: 11)).foregroundColor(Theme.textLight)
        }
        .padding(12)
        .inkCard(hover: hover)
        .onHover { hover = $0 }
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var state: AppState

    let note: Note
    var onBack: () -> Void

    @State private var text = ""
    @State private var showPreview = false
    @State private var publishing = false
    @State private var publishedFlash = false
    @State private var saveTask: Task<Void, Never>?

    private var title: String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return first.hasPrefix("# ") ? String(first.dropFirst(2)) : "未命名笔记"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30).background(Theme.surfaceSoft)
                        .clipShape(Circle()).foregroundColor(Theme.textMain)
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.textStrong)
                    .lineLimit(1)

                Spacer()

                if publishedFlash {
                    Text("已发布到网站 ✓").font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.statusPublish)
                        .transition(.opacity)
                }

                Menu {
                    Button("存为草稿") { Task { await publish(publish: false) } }
                        .disabled(publishing)
                    Button("发布到网站") { Task { await publish(publish: true) } }
                        .disabled(publishing)
                } label: {
                    if publishing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane")
                            .font(.system(size: 13))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.accentBg)
                            .foregroundColor(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showPreview.toggle() }
                } label: {
                    Image(systemName: showPreview ? "pencil" : "eye")
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.surfaceSoft)
                        .foregroundColor(Theme.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.card)
            Divider().overlay(Theme.cardBorder)

            if showPreview {
                MarkdownPreview(source: text)
            } else {
                MarkdownEditor(text: $text)
                    .background(Theme.bg)
            }
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
            }
        }
    }

    private func publish(publish: Bool) async {
        publishing = true
        defer { publishing = false }
        var body = text
        if body.hasPrefix("# \(title)\n") { body = String(body.dropFirst(title.count + 3)) }
        let post = TSPost(cid: 0, title: title, content: body, categories: [], tags: [],
                          slug: "", status: TSStatus.draft, created: Date(), modified: Date(),
                          link: "", allowComment: true)
        if await state.publish(post, publish: publish) != nil {
            withAnimation { publishedFlash = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { publishedFlash = false }
        }
    }
}
