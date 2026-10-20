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
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @AppStorage("siteURL") var siteURL: String = "https://www.zhouzhou.work"
    @AppStorage("username") var username: String = ""
    @Published var password: String = Keychain.get("typecho.password")

    @Published var connected = false
    @Published var blogName = ""
    @Published var posts: [TSPost] = []
    @Published var categories: [TSCategory] = []
    @Published var tags: [TSTag] = []
    @Published var pages: [TSPage] = []
    @Published var comments: [TSComment] = []
    @Published var loading = false
    @Published var lastError: String?

    var pendingComments: Int { comments.filter { $0.status == "pending" }.count }

    func saveCredentials() {
        Keychain.set(password, for: "typecho.password")
    }

    var api: TypechoAPI? {
        guard let url = URL(string: siteURL), !username.isEmpty, !password.isEmpty else { return nil }
        return TypechoAPI(site: url, username: username, password: password)
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
    }

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
