import SwiftUI

struct PostEditorView: View {
    @EnvironmentObject var state: AppState

    @State var post: TSPost
    let isNew: Bool
    var onBack: () -> Void = {}

    @State private var tagsInput = ""
    @State private var showPreview = false
    @State private var saving = false
    @State private var savedFlash = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.cardBorder)
            editorArea
        }
        .background(Theme.bg)
        .onAppear { tagsInput = post.tags.joined(separator: ", ") }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Theme.surfaceSoft)
                        .clipShape(Circle())
                        .foregroundColor(Theme.textMain)
                }
                .buttonStyle(.plain)

                TextField("标题", text: $post.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.textStrong)

                if !isNew { StatusPill(status: post.status) }
                Spacer()

                if savedFlash {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.statusPublish)
                        .transition(.scale.combined(with: .opacity))
                }

                Menu {
                    Button("保存为草稿") { Task { await save(publish: false) } }
                    Button(isNew ? "发布到网站" : "更新并发布") { Task { await save(publish: true) } }
                } label: {
                    if saving {
                        ProgressView().controlSize(.small).frame(width: 70, height: 22)
                    } else {
                        Text(isNew ? "发布" : "保存")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.accent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(state.categories) { cat in
                        Button {
                            if post.categories.contains(cat.name) {
                                post.categories.removeAll { $0 == cat.name }
                            } else {
                                post.categories.append(cat.name)
                            }
                        } label: {
                            Label(cat.name, systemImage: post.categories.contains(cat.name) ? "checkmark" : "circle")
                        }
                    }
                } label: {
                    metaChip(post.categories.isEmpty ? "选择分类" : post.categories.joined(separator: " · "),
                            icon: "folder")
                }
                .buttonStyle(.plain)

                TextField("标签，逗号分隔", text: $tagsInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.surfaceSoft)
                    .clipShape(Capsule())
                    .frame(maxWidth: 220)

                Spacer()

                Toggle(isOn: $showPreview.animation(.easeInOut(duration: 0.2))) {
                    metaChip(showPreview ? "写作" : "预览", icon: showPreview ? "pencil" : "eye")
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card)
    }

    private func metaChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 12)).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.surfaceSoft)
        .foregroundColor(Theme.textSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.borderSoft, lineWidth: 1))
    }

    @ViewBuilder
    private var editorArea: some View {
        if showPreview {
            MarkdownPreview(source: post.content)
        } else {
            MarkdownEditor(text: $post.content)
                .background(Theme.bg)
        }
    }

    private func save(publish: Bool) async {
        saving = true
        var p = post
        p.tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let cid = await state.publish(p, publish: publish) {
            post.cid = cid
            post.status = publish ? TSStatus.published : TSStatus.draft
            withAnimation(.spring(response: 0.3)) { savedFlash = true }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { savedFlash = false }
        }
        saving = false
    }
}
