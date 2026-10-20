import Foundation

struct TSPost: Identifiable, Equatable {
    var cid: Int
    var title: String
    var content: String          // markdown 或 HTML（取决于站点设置）
    var categories: [String]
    var tags: [String]
    var slug: String
    var status: String           // publish / draft / pending
    var created: Date
    var modified: Date
    var link: String
    var allowComment: Bool

    var id: Int { cid }
}

struct TSCategory: Identifiable, Equatable, Hashable {
    var mid: Int
    var name: String
    var slug: String
    var description: String
    var count: Int

    var id: Int { mid }
}

struct TSTag: Identifiable, Equatable, Hashable {
    var mid: Int
    var name: String
    var slug: String
    var count: Int

    var id: Int { mid }
}

enum TSStatus {
    static let published = "publish"
    static let draft = "draft"
}

struct TypechoAPI {
    var client: XMLRPCClient

    var endpoint: URL
    var username: String
    var password: String

    init(site: URL, username: String, password: String) {
        let base = site.absoluteString.hasSuffix("/") ? site.absoluteString : site.absoluteString + "/"
        self.endpoint = URL(string: base + "action/xmlrpc")!
        self.username = username
        self.password = password
        self.client = XMLRPCClient(endpoint: endpoint, username: username, password: password)
    }

    @discardableResult
    mutating func login() async throws -> String {
        let blogs = try await client.call("blogger.getUsersBlogs",
                                          [.int(1), .string(username), .string(password)])
        guard let first = blogs.arrayValue?.first?.structValue else { throw RPCError.badResponse }
        let name = first["blogName"]?.stringValue ?? ""
        if let id = first["blogid"]?.intValue { client.blogId = id }
        return name
    }

    private var auth: [RPCValue] { [.string(username), .string(password)] }

    func getPost(_ cid: Int) async throws -> TSPost {
        let r = try await client.call("metaWeblog.getPost", [.int(cid)] + auth)
        return Self.parsePost(r.structValue ?? [:])
    }

    mutating func getRecentPosts(_ num: Int = 50) async throws -> [TSPost] {
        let r = try await client.call("metaWeblog.getRecentPosts",
                                      [.int(client.blogId)] + auth + [.int(num)])
        return r.arrayValue?.compactMap { Self.parsePost($0.structValue ?? [:]) } ?? []
    }

    func deletePost(_ cid: Int) async throws {
        _ = try await client.call("blogger.deletePost",
                                  [.int(client.blogId), .int(cid)] + auth + [.bool(true)])
    }

    func publish(_ post: TSPost, asPublish: Bool) async throws -> Int {
        var struct_: [String: RPCValue] = [
            "title": .string(post.title.isEmpty ? "未命名" : post.title),
            "description": .string(post.content),
            "mt_keywords": .string(post.tags.joined(separator: ", ")),
            "categories": .array(post.categories.map { .string($0) }),
            "mt_allow_comments": .int(post.allowComment ? 1 : 0),
        ]
        if !post.slug.isEmpty { struct_["wp_slug"] = .string(post.slug) }
        if post.cid > 0 {
            _ = try await client.call("metaWeblog.editPost",
                                      [.int(post.cid)] + auth + [.struct_(struct_), .bool(asPublish)])
            return post.cid
        } else {
            let r = try await client.call("metaWeblog.newPost",
                                          [.int(client.blogId)] + auth + [.struct_(struct_), .bool(asPublish)])
            return r.intValue ?? 0
        }
    }

    func getCategories() async throws -> [TSCategory] {
        let r = try await client.call("metaWeblog.getCategories", [.int(client.blogId)] + auth)
        return r.arrayValue?.compactMap { v in
            guard let s = v.structValue else { return nil }
            return TSCategory(mid: s["categoryId"]?.intValue ?? 0,
                              name: s["categoryName"]?.stringValue ?? "",
                              slug: s["htmlURL"]?.stringValue ?? "",
                              description: s["categoryDescription"]?.stringValue ?? "",
                              count: 0)
        } ?? []
    }

    func getTags() async throws -> [TSTag] {
        let r = try await client.call("wp.getTags", [.int(client.blogId)] + auth)
        return r.arrayValue?.compactMap { v in
            guard let s = v.structValue else { return nil }
            return TSTag(mid: s["tag_id"]?.intValue ?? 0,
                         name: s["name"]?.stringValue ?? "",
                         slug: s["slug"]?.stringValue ?? "",
                         count: s["count"]?.intValue ?? 0)
        } ?? []
    }

    static func parsePost(_ s: [String: RPCValue]) -> TSPost {
        TSPost(
            cid: s["postid"]?.intValue ?? 0,
            title: s["title"]?.stringValue ?? "",
            content: s["description"]?.stringValue ?? "",
            categories: s["categories"]?.arrayValue?.compactMap { $0.stringValue } ?? [],
            tags: (s["mt_keywords"]?.stringValue ?? "")
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            slug: s["wp_slug"]?.stringValue ?? "",
            status: s["post_status"]?.stringValue ?? "publish",
            created: s["dateCreated"]?.dateValue ?? Date(),
            modified: s["date_modified"]?.dateValue ?? s["dateCreated"]?.dateValue ?? Date(),
            link: s["link"]?.stringValue ?? "",
            allowComment: (s["mt_allow_comments"]?.intValue ?? 1) != 0
        )
    }
}
