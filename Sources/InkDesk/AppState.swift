import SwiftUI

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
    @Published var loading = false
    @Published var lastError: String?

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

    /// 返回发布后的 cid；publish=false 存为草稿
    func publish(_ post: TSPost, publish: Bool) async -> Int? {
        guard var api else {
            lastError = RPCError.notConfigured.localizedDescription
            return nil
        }
        loading = true
        defer { loading = false }
        do {
            let cid = try await api.publish(post, asPublish: publish)
            // 草稿在 Typecho 中是独立记录，编辑草稿即另存；直接刷新列表即可
            posts = try await api.getRecentPosts(50)
            if !categories.isEmpty || !tags.isEmpty {
                categories = try await api.getCategories()
                tags = try await api.getTags()
            }
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
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case notes = "本地笔记"
    case posts = "网站文章"
    case meta = "分类与标签"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .notes: return "note.text"
        case .posts: return "doc.text"
        case .meta: return "tag"
        }
    }
}
