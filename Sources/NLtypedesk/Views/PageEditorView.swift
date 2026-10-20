import SwiftUI

struct PageEditorView: View {
    @EnvironmentObject var state: AppState

    @State var page: TSPage
    var onBack: () -> Void = {}

    @State private var mode: EditorMode = .write
    @State private var saving = false
    @State private var savedFlash = false
    @State private var dirty = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26).background(Theme.surfaceSoft)
                        .clipShape(Circle()).foregroundColor(Theme.textMain)
                }.buttonStyle(.plain)

                TextField("页面标题", text: $page.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Theme.textStrong)
                    .onChange(of: page.title) { _ in dirty = true }

                Picker("", selection: $mode) {
                    ForEach(EditorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()

                Button { Task { await save() } } label: {
                    if saving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(page.cid == 0 ? "创建" : "保存")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card)
            Divider().overlay(Theme.cardBorder)

            switch mode {
            case .write: MarkdownEditor(text: $page.content).background(Theme.bg)
            case .preview: MarkdownPreview(source: page.content)
            case .split:
                HSplitView {
                    MarkdownEditor(text: $page.content).frame(minWidth: 300)
                    MarkdownPreview(source: page.content).frame(minWidth: 300)
                }
            }

            Divider().overlay(Theme.cardBorder)
            HStack(spacing: 14) {
                Text("\(TextStats.count(page.content)) 词")
                    .font(.system(size: 11)).foregroundColor(Theme.textLight)
                Spacer()
                if savedFlash {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundColor(Theme.statusPublish)
                } else if dirty {
                    Text("未保存").font(.system(size: 11)).foregroundColor(Theme.statusDraft)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Theme.card)
        }
        .background(Theme.bg)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let cid = await state.savePage(page) {
            page.cid = cid
            dirty = false
            withAnimation { savedFlash = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { savedFlash = false }
        }
    }
}
