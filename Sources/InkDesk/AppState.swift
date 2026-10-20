import SwiftUI

enum DocFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case draft = "草稿"
    case published = "已发布"

    var id: String { rawValue }
}

enum Pane: Hashable {
    case notes
    case posts(DocFilter)
    case categories
    case tags
    case pages
    case comments
    case health
    case bills
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @AppStorage("siteURL") var siteURL: String = "https://www.zhouzhou.work"
    @AppStorage("username") var username: String = ""
    @Published var password: String = Keychain.get("typecho.password")
    /// 站点数据接口密钥（X-Noline-Key），只进 Keychain，不进日志
    @Published var siteKey: String = Keychain.get("noline.key")

    @Published var connected = false
    @Published var blogName = ""
    @Published var posts: [TSPost] = []
    @Published var categories: [TSCategory] = []
    @Published var tags: [TSTag] = []
    @Published var pages: [TSPage] = []
    @Published var comments: [TSComment] = []
    @Published var loading = false
    @Published var lastError: String?

    // 站点数据（健康 / 记账）
    @Published var healthData: HealthData?
    @Published var billsData: BillsData?
    @Published var billRecords: [Bill] = []
    @Published var siteDataLoading = false
    @Published var siteDataError: String?

    var pendingComments: Int { comments.filter { $0.status == "pending" }.count }

    /// 站点数据功能的「今天」：优先服务器视角
    var serverToday: String { NLDate.today(server: billsData?.span?.today ?? healthData?.last) }

    func saveCredentials() {
        Keychain.set(password, for: "typecho.password")
        Keychain.set(siteKey, for: "noline.key")
    }

    var api: TypechoAPI? {
        guard let url = URL(string: siteURL), !username.isEmpty, !password.isEmpty else { return nil }
        return TypechoAPI(site: url, username: username, password: password)
    }

    var noline: NolineClient? {
        guard let url = URL(string: siteURL), !siteKey.isEmpty else { return nil }
        return NolineClient(site: url, key: siteKey)
    }

    func refresh() async {
        guard var api else {
            lastError = RPCError.notConfigured.localizedDescription
            return
        }
        loading = true
        defer { loading = false }
        do {
            blogName = try await api.login()
            connected = true
            posts = try await api.getRecentPosts(50)
            categories = try await api.getCategories()
            tags = try await api.getTags()
            pages = (try? await api.getPages()) ?? []
            comments = (try? await api.getComments(40)) ?? []
            lastError = nil
        } catch {
            connected = false
            lastError = error.localizedDescription
        }
        await refreshSiteData()
    }

    // MARK: 站点数据

    func refreshSiteData() async {
        guard let c = noline else {
            siteDataError = siteKey.isEmpty ? "还没配置站点密钥" : "先配置站点地址"
            return
        }
        siteDataLoading = true
        defer { siteDataLoading = false }
        do {
            async let h = c.health()
            async let b = c.bills()
            async let r = c.billsRecords(limit: 200)
            healthData = try await h
            billsData = try await b
            billRecords = (try? await r)?.records ?? []
            siteDataError = nil
        } catch {
            siteDataError = error.localizedDescription
        }
    }

    /// 403 有两种来源（密钥错 / 只读模式），用 GET health 判别后给出准确文案
    func reportNolineError(_ error: Error, isWrite: Bool) async {
        if let e = error as? NolineError, e.code == 403, isWrite {
            if let c = noline {
                if (try? await c.health()) != nil {
                    lastError = "站点是只读模式：请到后台插件设置里开启「数据写入（健康 / 记账）」"
                } else {
                    lastError = "站点密钥不正确，请到设置里核对"
                }
            }
            return
        }
        lastError = error.localizedDescription
    }

    func saveHealthRecord(date: String, weight: Double, fat: Double?, note: String) async throws {
        guard let c = noline else { throw NolineError(code: 401, message: nil) }
        var rec: [String: Any] = ["date": date, "weight": weight]
        // 整天整体覆盖：fat/note 必须完整回传，缺了会把那天原有字段抹掉
        if let fat { rec["fat"] = fat }
        rec["note"] = note
        do {
            let r = try await c.postHealth([rec])
            if let invalid = r.invalid, !invalid.isEmpty {
                throw NolineError(code: 400, message: "这些日期被拒绝：\(invalid.joined(separator: "、"))")
            }
            await refreshSiteData()
        } catch {
            await reportNolineError(error, isWrite: true)
            throw error
        }
    }

    func deleteHealthRecord(date: String) async {
        guard let c = noline else { return }
        do {
            _ = try await c.deleteHealth(date: date)
            await refreshSiteData()
        } catch {
            await reportNolineError(error, isWrite: true)
        }
    }

    func addBill(date: String, title: String, amount: Double, kind: String, shop: String, note: String) async -> Bool {
        guard let c = noline else { return false }
        let rec: [String: Any] = ["date": date, "title": title, "amount": amount,
                                  "kind": kind, "shop": shop, "note": note]
        do {
            let r = try await c.postBills([rec])
            if let invalid = r.invalid, !invalid.isEmpty {
                lastError = "这些品名被拒绝：\(invalid.joined(separator: "、"))"
                return false
            }
            await refreshSiteData()
            return true
        } catch let e as NolineError where e.code == -1 {
            // POST 不幂等，超时不能盲目重放：先查那天的流水认领这笔
            if let claimed = await c.claimBill(date: date, title: title, amount: amount) {
                _ = claimed
                await refreshSiteData()
                return true
            }
            lastError = "网络失败，且未能确认这笔是否已记账，请稍后在流水里核对"
            return false
        } catch {
            await reportNolineError(error, isWrite: true)
            return false
        }
    }

    func updateBill(id: String, fields: [String: Any]) async -> Bool {
        guard let c = noline else { return false }
        do {
            try await c.updateBill(id: id, fields: fields)
            await refreshSiteData()
            return true
        } catch {
            await reportNolineError(error, isWrite: true)
            return false
        }
    }

    func deleteBill(id: String) async {
        guard let c = noline else { return }
        do {
            _ = try await c.deleteBill(id: id)
            await refreshSiteData()
        } catch {
            await reportNolineError(error, isWrite: true)
        }
    }

    // MARK: 文章 / 页面 / 评论

    func loadPost(_ cid: Int) async -> TSPost? {
        guard let api else { return nil }
        do { return try await api.getPost(cid) }
        catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func publish(_ post: TSPost, publish: Bool) async -> Int? {
        guard var api else {
            lastError = RPCError.notConfigured.localizedDescription
            return nil
        }
        loading = true
        defer { loading = false }
        do {
            let cid = try await api.publish(post, asPublish: publish)
            posts = try await api.getRecentPosts(50)
            categories = try await api.getCategories()
            tags = try await api.getTags()
            lastError = nil
            return cid == 0 ? post.cid : cid
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// 本地笔记自动同步为站点草稿：记住 cid，之后一律 editPost
    func syncNoteDraft(path: String, title: String, body: String, via store: NoteStore) async -> Bool {
        guard let api else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, title != "未命名笔记" else { return false }
        let cid = store.remoteCid(for: path)
        // 已经正式发布过的笔记不要再降级回草稿
        if cid > 0, let existing = posts.first(where: { $0.cid == cid }), existing.status == TSStatus.published {
            return false
        }
        let post = TSPost(cid: cid, title: title, content: body, categories: [], tags: [],
                          slug: "", status: TSStatus.draft, created: Date(), modified: Date(),
                          link: "", allowComment: true)
        do {
            let newCid = try await api.publish(post, asPublish: false)
            store.setRemoteCid(path, newCid == 0 ? cid : newCid)
            return true
        } catch {
            return false
        }
    }

    func delete(_ post: TSPost) async {
        guard let api else { return }
        do {
            try await api.deletePost(post.cid)
            posts.removeAll { $0.cid == post.cid }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // 页面
    func loadPage(_ cid: Int) async -> TSPage? {
        guard let api else { return nil }
        do { return try await api.getPage(cid) }
        catch { lastError = error.localizedDescription; return nil }
    }

    func savePage(_ page: TSPage) async -> Int? {
        guard let api else { return nil }
        do {
            let cid: Int
            if page.cid > 0 {
                try await api.updatePage(page)
                cid = page.cid
            } else {
                cid = try await api.createPage(page)
            }
            pages = try await api.getPages()
            return cid
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deletePage(_ page: TSPage) async {
        guard let api else { return }
        do {
            try await api.deletePage(page.cid)
            pages.removeAll { $0.cid == page.cid }
        } catch { lastError = error.localizedDescription }
    }

    // 评论
    func setComment(_ comment: TSComment, status: String) async {
        guard let api else { return }
        do {
            try await api.setCommentStatus(comment, status: status)
            if let i = comments.firstIndex(where: { $0.coid == comment.coid }) {
                comments[i].status = status
            }
        } catch { lastError = error.localizedDescription }
    }

    func deleteComment(_ comment: TSComment) async {
        guard let api else { return }
        do {
            try await api.deleteComment(comment)
            comments.removeAll { $0.coid == comment.coid }
        } catch { lastError = error.localizedDescription }
    }

    // 上传
    func uploadImage(name: String, type: String, data: Data) async -> String? {
        guard let api else { return nil }
        do {
            let url = try await api.uploadMedia(name: name, type: type, data: data)
            return url.isEmpty ? nil : url
        } catch {
            lastError = "图片上传失败：" + error.localizedDescription
            return nil
        }
    }
}
