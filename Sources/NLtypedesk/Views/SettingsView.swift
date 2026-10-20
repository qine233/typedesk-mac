import SwiftUI

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
                GridRow {
                    Text("站点数据密钥").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                    SecureField("NolineApi 插件密钥", text: $state.siteKey)
                        .textFieldStyle(.roundedBorder).frame(width: 280)
                        .onSubmit { state.saveCredentials() }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield").font(.system(size: 10)).foregroundColor(Theme.statusPublish)
                Text("账号密码与站点密钥都只存在系统钥匙串；密钥通过 X-Noline-Key 请求头发送，不进日志。健康记录 / 买菜记账需要此密钥（Typecho 后台 → NolineApi 插件设置）。")
                    .font(.system(size: 10)).foregroundColor(Theme.textLight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            if state.siteURL.hasPrefix("http://") {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 10)).foregroundColor(Theme.statusDraft)
                    Text("站点走的是明文 HTTP，密钥会以明文传输，建议先上 HTTPS 再启用写入。")
                        .font(.system(size: 10)).foregroundColor(Theme.statusDraft)
                }
                .padding(.top, 6)
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

            Text("提示：需在 Typecho 后台启用 XML-RPC 服务；若希望正文按 Markdown 存储，请开启「在 XML-RPC 中使用 Markdown」选项。")
                .font(.system(size: 11)).foregroundColor(Theme.textLight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(18)
        .frame(width: 430)
        .background(Theme.card)
    }
}
