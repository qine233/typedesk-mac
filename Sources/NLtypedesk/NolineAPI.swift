import Foundation

// MARK: - 错误

struct NolineError: Error, LocalizedError {
    let code: Int
    let message: String

    init(code: Int, message: String?) {
        self.code = code
        self.message = message ?? NolineError.defaultText(code)
    }

    static func defaultText(_ code: Int) -> String {
        switch code {
        case 400: return "请求体不合法"
        case 401: return "没有带密钥，请在设置中填写站点密钥"
        case 403: return "密钥不正确，或站点是只读模式"
        case 404: return "接口路径不存在"
        case 405: return "请求方法不支持"
        case 503: return "站点那边没开接口，或后台还没有设置密钥"
        case 500: return "服务器数据目录不可写，请检查 usr/uploads/noline_api 权限"
        default: return "未知错误"
        }
    }

    var errorDescription: String? { "\(message)（\(code)）" }
}

/// 忽略服务器 data 内容的占位解码类型
struct NoData: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

// MARK: - URL 形态

enum NolineURLForm: Int, CaseIterable {
    case rewrite = 0   // /api/x
    case indexPHP = 1  // /index.php/api/x
    case query = 2     // ?noline_api=x
}

// MARK: - 模型

struct PingData: Codable {
    let name: String?
    let url: String?
    let theme: String?
    let plugin: String?
    let time: String?
}

struct BMIInterval: Codable { let low: Double; let high: Double }
struct BMILimits: Codable { let thin: Double?; let normal: Double?; let obese: Double? }

struct HealthProfile: Codable {
    let height: Double?
    let gender: String?
    let target_weight: Double?
    let ideal: BMIInterval?
    let bmi_ranges: BMILimits?
}

struct HealthRecord: Codable, Identifiable, Equatable {
    let date: String
    let weight: Double
    let delta: Double?
    let bmi: Double?
    let category: String?
    let fat: Double?
    let note: String?
    var id: String { date }
}

struct HealthStats: Codable { let min: Double; let max: Double; let avg: Double }
struct HealthGoal: Codable { let target: Double?; let remaining: Double?; let done: Bool? }
struct HealthChange: Codable { let span: Int?; let from_date: String?; let delta: Double? }

struct HealthData: Codable {
    let profile: HealthProfile?
    let count: Int?
    let first: String?
    let last: String?
    let latest: HealthRecord?
    let stats: HealthStats?
    let series: [HealthRecord]?
    let goal: HealthGoal?
    let changes: [String: HealthChange]?
}

struct HealthRecordsData: Codable { let total: Int?; let records: [HealthRecord] }
struct HealthPostResponse: Codable { let saved: Int; let total: Int?; let invalid: [String]? }
struct HealthDeleteResponse: Codable { let deleted: String?; let total: Int? }

struct Bill: Codable, Identifiable, Equatable {
    let id: String
    let date: String
    let title: String
    let amount: Double
    let kind: String?
    let shop: String?
    let note: String?
}

struct BillKind: Codable, Identifiable, Hashable {
    let kind: String
    let label: String
    var id: String { kind }
}

struct BillTop: Codable { let date: String?; let title: String?; let amount: Double? }

struct BillAggregate: Codable {
    let start: String?
    let end: String?
    let amount: Double
    let count: Int
    let days: Int?
    let avg_day: Double?
    let avg_bill: Double?
    let max: BillTop?
}

struct BillMonth: Codable { let month: String; let amount: Double; let count: Int? }
struct BillKindShare: Codable { let kind: String; let amount: Double; let count: Int?; let share: Double? }
struct BillDayGroup: Codable { let date: String; let amount: Double; let count: Int?; let items: [Bill] }

struct BillsSpan: Codable {
    let today: String?
    let weekday: Int?
    let week_start: String?
    let week_end: String?
    let month_start: String?
    let month_end: String?
    let month_days: Int?
    let month_day_of: Int?
}

struct BillsData: Codable {
    let count: Int?
    let currency: String?
    let first: String?
    let last: String?
    let kinds: [BillKind]?
    let kinds_month: [BillKindShare]?
    let totals: BillAggregate?
    let week: BillAggregate?
    let prev_week: BillAggregate?
    let month: BillAggregate?
    let prev_month: BillAggregate?
    let year: BillAggregate?
    let months: [BillMonth]?
    let by_date: [BillDayGroup]?
    let recent: [Bill]?
    let span: BillsSpan?
}

struct BillsRecordsData: Codable { let total: Int?; let amount: Double?; let records: [Bill] }
struct BillsPostResponse: Codable { let saved: Int; let total: Int?; let ids: [String]?; let invalid: [String]? }

struct AccentInfo: Codable {
    let hex: String?
    let rgb: String?
    let luminance: Double?
    let on: String?
    let dark: String?
}

/// GET /api/theme：App 只用 accent（跟随博客换肤），不读写 14 项配置本身
struct ThemeData: Codable { let accent: AccentInfo? }

// MARK: - 客户端

final class NolineClient {
    let siteBase: String
    let key: String

    private static let formDefaultsKey = "noline.urlForm"
    static var cachedForm: NolineURLForm? {
        get { (UserDefaults.standard.object(forKey: formDefaultsKey) as? Int).flatMap(NolineURLForm.init(rawValue:)) }
        set {
            if let v = newValue { UserDefaults.standard.set(v.rawValue, forKey: formDefaultsKey) }
            else { UserDefaults.standard.removeObject(forKey: formDefaultsKey) }
        }
    }

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    init(site: URL, key: String) {
        let s = site.absoluteString
        siteBase = s.hasSuffix("/") ? s : s + "/"
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: 请求核心

    private struct Envelope<T: Decodable>: Decodable {
        let code: Int
        let message: String?
        let data: T?
    }

    private func makeURL(path: String, query: [String: String], form: NolineURLForm) -> URL? {
        var items = query.filter { !$0.value.isEmpty }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var comps: URLComponents
        switch form {
        case .rewrite:
            guard let c = URLComponents(string: siteBase + "api/" + path) else { return nil }
            comps = c
        case .indexPHP:
            guard let c = URLComponents(string: siteBase + "index.php/api/" + path) else { return nil }
            comps = c
        case .query:
            guard let c = URLComponents(string: siteBase) else { return nil }
            comps = c
            items.insert(URLQueryItem(name: "noline_api", value: path), at: 0)
        }
        if !items.isEmpty { comps.queryItems = items }
        return comps.url
    }

    private func send(_ method: String, url: URL, json: Any?, resendSafe: Bool) async throws -> (Data, Int) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if !key.isEmpty { req.setValue(key, forHTTPHeaderField: "X-Noline-Key") }
        if let json {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        var attempt = 0
        let maxAttempts = resendSafe ? 4 : 1   // 网络失败最多重试 3 次
        while true {
            do {
                let (data, response) = try await session.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                return (data, status)
            } catch {
                attempt += 1
                if !resendSafe || attempt >= maxAttempts {
                    throw NolineError(code: -1, message: "网络失败：\(error.localizedDescription)")
                }
                let ns = UInt64(0.4 * pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    private func decode<T: Decodable>(_ data: Data, status: Int, as type: T.Type) throws -> T {
        guard let env = try? JSONDecoder().decode(Envelope<T>.self, from: data) else {
            throw NolineError(code: status, message: "响应不是接口格式（HTTP \(status)）")
        }
        if env.code != 0 { throw NolineError(code: env.code, message: env.message) }
        if let payload = env.data { return payload }
        if type == NoData.self { return NoData() as! T }
        throw NolineError(code: status, message: "响应缺少 data")
    }

    /// 探测三种 URL 形态并缓存第一个通的
    func ensureForm() async throws -> NolineURLForm {
        if let f = Self.cachedForm { return f }
        for f in NolineURLForm.allCases {
            guard let url = makeURL(path: "ping", query: [:], form: f) else { continue }
            if let (data, status) = try? await send("GET", url: url, json: nil, resendSafe: true),
               (try? decode(data, status: status, as: PingData.self)) != nil {
                Self.cachedForm = f
                return f
            }
        }
        throw NolineError(code: 503, message: "连不上站点接口，请检查站点地址或伪静态设置")
    }

    func request<T: Decodable>(_ method: String, path: String,
                               query: [String: String] = [:],
                               json: Any? = nil,
                               resendSafe: Bool = true) async throws -> T {
        let form = try await ensureForm()
        guard let url = makeURL(path: path, query: query, form: form) else {
            throw NolineError(code: -1, message: "站点地址无法解析")
        }
        let (data, status) = try await send(method, url: url, json: json, resendSafe: resendSafe)
        do {
            return try decode(data, status: status, as: T.self)
        } catch let e as NolineError where e.code == 404 && resendSafe && path != "ping" {
            // 路径 404：可能是 URL 形态变了，重新探测一次
            Self.cachedForm = nil
            let newForm = try await ensureForm()
            guard newForm != form, let retryURL = makeURL(path: path, query: query, form: newForm) else { throw e }
            let (d2, s2) = try await send(method, url: retryURL, json: json, resendSafe: resendSafe)
            return try decode(d2, status: s2, as: T.self)
        }
    }

    // MARK: 端点

    func ping() async throws -> PingData {
        try await request("GET", path: "ping")
    }

    func health() async throws -> HealthData {
        try await request("GET", path: "health")
    }

    func theme() async throws -> ThemeData {
        try await request("GET", path: "theme")
    }

    func healthRecords(from: String? = nil, to: String? = nil, limit: Int? = nil) async throws -> HealthRecordsData {
        var q: [String: String] = [:]
        if let from { q["from"] = from }
        if let to { q["to"] = to }
        if let limit { q["limit"] = String(limit) }
        return try await request("GET", path: "health/records", query: q)
    }

    /// POST：整天整体覆盖。records 元素必须携带完整对象（date/weight/fat/note），否则那天字段会被抹掉。
    func postHealth(_ records: [[String: Any]]) async throws -> HealthPostResponse {
        let json: [String: Any] = records.count == 1 ? records[0] : ["records": records]
        return try await request("POST", path: "health/records", json: json)
    }

    /// 删除某天；404 视为已删除（成功）
    @discardableResult
    func deleteHealth(date: String) async throws -> Bool {
        do {
            _ = try await request("DELETE", path: "health/records", query: ["date": date]) as NoData
            return true
        } catch let e as NolineError where e.code == 404 { return true }
    }

    func bills() async throws -> BillsData {
        try await request("GET", path: "bills")
    }

    func billsRecords(from: String? = nil, to: String? = nil, kind: String? = nil, limit: Int? = nil) async throws -> BillsRecordsData {
        var q: [String: String] = [:]
        if let from { q["from"] = from }
        if let to { q["to"] = to }
        if let kind { q["kind"] = kind }
        if let limit { q["limit"] = String(limit) }
        return try await request("GET", path: "bills/records", query: q)
    }

    /// POST：永远只新增，不幂等——超时不能盲目重放（resendSafe: false）。
    func postBills(_ records: [[String: Any]]) async throws -> BillsPostResponse {
        let json: [String: Any] = records.count == 1 ? records[0] : ["records": records]
        return try await request("POST", path: "bills/records", json: json, resendSafe: false)
    }

    /// 记账 POST 超时后的补查：按日期 + 品名 + 金额认领那笔。
    func claimBill(date: String, title: String, amount: Double) async -> Bill? {
        guard let data = try? await billsRecords(from: date, to: date, limit: 0) else { return nil }
        return data.records.first { $0.title == title && abs($0.amount - amount) < 0.005 }
    }

    func updateBill(id: String, fields: [String: Any]) async throws {
        var json = fields
        json["id"] = id
        _ = try await request("PUT", path: "bills/records", json: json) as NoData
    }

    /// 按 id 删除；404 视为服务器已经没有它了（成功）
    @discardableResult
    func deleteBill(id: String) async throws -> Bool {
        do {
            _ = try await request("DELETE", path: "bills/records", query: ["id": id]) as NoData
            return true
        } catch let e as NolineError where e.code == 404 { return true }
    }
}

// MARK: - 日期与格式工具

enum NLDate {
    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 优先用服务器视角的今天（§7.5），拿不到再退本机日期
    static func today(server: String?) -> String {
        if let server, isValid(server) { return server }
        return fmt.string(from: Date())
    }

    static func isValid(_ s: String) -> Bool { fmt.date(from: s) != nil }

    static func date(_ s: String) -> Date? { fmt.date(from: s) }

    static func string(_ d: Date) -> String { fmt.string(from: d) }

    static func shortMD(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3 else { return s }
        return "\(Int(p[1]) ?? 0)/\(Int(p[2]) ?? 0)"
    }

    static func monthLabel(_ m: String) -> String {
        let p = m.split(separator: "-")
        guard p.count == 2, let n = Int(p[1]) else { return m }
        return "\(n)月"
    }
}

enum NLFormat {
    static func money(_ v: Double) -> String { String(format: "%.2f", v) }
    static func weight(_ v: Double) -> String { String(format: "%.1f", v) }
    static func signedWeight(_ v: Double) -> String { String(format: v > 0 ? "+%.1f" : "%.1f", v) }
    static func signedMoney(_ v: Double) -> String { String(format: v > 0 ? "+%.2f" : "%.2f", v) }

    static let bmiCategories = ["thin": "偏瘦", "normal": "正常", "over": "偏重", "obese": "肥胖"]
    static func bmiCategory(_ c: String?) -> String { c.flatMap { bmiCategories[$0] } ?? c ?? "—" }
}
