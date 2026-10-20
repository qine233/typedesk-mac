import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var noteStore: NoteStore
    @State private var section: SidebarSection = .notes
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                switch section {
                case .notes: NotesSection().environmentObject(noteStore)
                case .posts: PostsSection()
                case .meta: MetaSection()
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $section) {
                ForEach(SidebarSection.allCases) { s in
                    Label(s.rawValue, systemImage: s.symbol)
                        .font(.system(size: 13))
                        .tag(s)
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.connected ? Theme.statusPublish : Theme.textLight)
                        .frame(width: 8, height: 8)
                    Text(state.connected ? state.blogName : "未连接")
                        .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Button {
                    showSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var testing = false
    @State private var testOK: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("连接设置").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(Theme.textLight) }
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("站点地址").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                    TextField("https://www.zhouzhou.work", text: $state.siteURL)
                        .textFieldStyle(.roundedBorder).frame(width: 280)
                }
                GridRow {
                    Text("用户名").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                    TextField("Typecho 管理员用户名", text: $state.username)
                        .textFieldStyle(.roundedBorder).frame(width: 280)
                }
                GridRow {
                    Text("密码").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                    SecureField("登录密码", text: $state.password)
                        .textFieldStyle(.roundedBorder).frame(width: 280)
                        .onSubmit { state.saveCredentials() }
                }
            }

            HStack(spacing: 10) {
                Button {
                    testing = true
                    testOK = nil
                    state.saveCredentials()
                    Task {
                        await state.refresh()
                        testing = false
                        testOK = state.connected
                    }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("测试连接")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)

                if let testOK {
                    Text(testOK ? "连接成功" : "连接失败")
                        .font(.system(size: 12))
                        .foregroundColor(testOK ? Theme.statusPublish : Theme.danger)
                }
            }
            .padding(.top, 14)

            if let err = state.lastError, testOK == false {
                Text(err).font(.system(size: 11)).foregroundColor(Theme.statusDraft).padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("提示：需在 Typecho 后台启用 XML-RPC 服务；若希望正文按 Markdown 渲染，请开启「在 XML-RPC 中使用 Markdown」选项。")
                    .font(.system(size: 11)).foregroundColor(Theme.textLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
        }
        .padding(18)
        .frame(width: 420)
        .background(Theme.card)
    }
}
