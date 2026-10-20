import Foundation

enum RPCValue {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case date(Date)
    case array([RPCValue])
    case struct_([String: RPCValue])
    case base64(Data)

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .bool(let b): return b ? "1" : "0"
        case .double(let d): return String(d)
        default: return nil
        }
    }
    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .string(let s): return Int(s)
        default: return nil
        }
    }
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        if case .int(let i) = self { return i != 0 }
        return nil
    }
    var dateValue: Date? {
        if case .date(let d) = self { return d }
        if case .string(let s) = self { return RPCDate.parse(s) }
        return nil
    }
    var arrayValue: [RPCValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    var structValue: [String: RPCValue]? {
        if case .struct_(let s) = self { return s }
        return nil
    }
    subscript(key: String) -> RPCValue? {
        structValue?[key]
    }
}

enum RPCDate {
    static func string(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd'T'HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }
    static func parse(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        for f in ["yyyyMMdd'T'HH:mm:ssZ", "yyyyMMdd'T'HH:mm:ss", "yyyyMMdd'T'HH:mm:ss.SSSZ"] {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = f
            if let d = fmt.date(from: trimmed) { return d }
        }
        return nil
    }
}

enum XMLEncoder {
    static func text(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func value(_ v: RPCValue) -> String {
        switch v {
        case .string(let s): return "<value><string>\(text(s))</string></value>\n"
        case .int(let i): return "<value><int>\(i)</int></value>\n"
        case .bool(let b): return "<value><boolean>\(b ? 1 : 0)</boolean></value>\n"
        case .double(let d): return "<value><double>\(d)</double></value>\n"
        case .date(let dt): return "<value><dateTime.iso8601>\(RPCDate.string(from: dt))</dateTime.iso8601></value>\n"
        case .base64(let data): return "<value><base64>\(data.base64EncodedString())</base64></value>\n"
        case .array(let items):
            var s = "<value><array><data>\n"
            for i in items { s += value(i) }
            return s + "</data></array></value>\n"
        case .struct_(let members):
            var s = "<value><struct>\n"
            for (k, val) in members {
                s += "<member><name>\(text(k))</name>" + value(val) + "</member>\n"
            }
            return s + "</struct></value>\n"
        }
    }

    static func encode(method: String, params: [RPCValue]) -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<methodCall><methodName>\(text(method))</methodName><params>\n"
        for p in params { xml += "<param>" + value(p) + "</param>\n" }
        xml += "</params></methodCall>"
        return Data(xml.utf8)
    }
}

final class XMLRPCHandler: NSObject, XMLParserDelegate {
    private enum Container {
        case array([RPCValue])
        case object([String: RPCValue], pendingKey: String?)
    }

    private var containers: [Container] = []
    private var faultStruct: [String: RPCValue]?
    private var text = ""
    var result: RPCValue?
    var methodName: String?

    var faultResponse: (code: Int, string: String)? {
        guard let f = faultStruct else { return nil }
        return (f["faultCode"]?.intValue ?? -1, f["faultString"]?.stringValue ?? "未知错误")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
               qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "string", "int", "i4", "boolean", "double", "dateTime.iso8601", "base64", "name", "value":
            text = ""
        case "array":
            containers.append(.array([]))
        case "struct":
            containers.append(.object([:], pendingKey: nil))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
               qualifiedName qName: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "name":
            if case .object(let members, _) = containers.last {
                containers[containers.count - 1] = .object(members, pendingKey: trimmed)
            }
        case "string": emitScalar(.string(text))
        case "int", "i4": emitScalar(.int(Int(trimmed) ?? 0))
        case "boolean": emitScalar(.bool(trimmed == "1"))
        case "double": emitScalar(.double(Double(trimmed) ?? 0))
        case "dateTime.iso8601": emitScalar(.date(RPCDate.parse(trimmed) ?? Date()))
        case "base64": emitScalar(.base64(Data(base64Encoded: text.replacingOccurrences(of: "\n", with: "")) ?? Data()))
        case "array", "struct": closeContainer()
        case "fault": faultStruct = result?.structValue
        default: break
        }
    }

    private func emitScalar(_ v: RPCValue) { append(v) }

    private func closeContainer() {
        guard let last = containers.popLast() else { return }
        switch last {
        case .array(let items): append(.array(items))
        case .object(let members, _): append(.struct_(members))
        }
    }

    private func append(_ v: RPCValue) {
        guard !containers.isEmpty else {
            result = v
            return
        }
        switch containers[containers.count - 1] {
        case .array(var items):
            items.append(v)
            containers[containers.count - 1] = .array(items)
        case .object(var members, let key):
            if let key = key {
                members[key] = v
                containers[containers.count - 1] = .object(members, pendingKey: nil)
            } else {
                containers[containers.count - 1] = .object(members, pendingKey: nil)
            }
        }
    }
}

enum RPCError: LocalizedError {
    case badResponse
    case notConfigured
    case fault(code: Int, message: String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "服务器返回了无法解析的响应"
        case .notConfigured: return "尚未配置站点，请在设置中填写地址与账号"
        case .fault(let c, let m): return "[\(c)] \(m)"
        case .network(let e): return "网络错误：\(e.localizedDescription)"
        }
    }
}

struct XMLRPCClient {
    var endpoint: URL
    var username: String
    var password: String
    var blogId: Int = 1

    func call(_ method: String, _ params: [RPCValue] = []) async throws -> RPCValue {
        let body = XMLEncoder.encode(method: method, params: params)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 20

        let resp: (Data, URLResponse)
        do { resp = try await URLSession.shared.data(for: req) }
        catch { throw RPCError.network(error) }

        guard let http = resp.1 as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RPCError.badResponse
        }
        let handler = XMLRPCHandler()
        let parser = XMLParser(data: resp.0)
        parser.delegate = handler
        guard parser.parse(), let value = handler.result else { throw RPCError.badResponse }
        if let f = handler.faultResponse { throw RPCError.fault(code: f.code, message: f.string) }
        return value
    }
}
