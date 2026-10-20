import Foundation

/// 把 Typecho 通过 XML-RPC 返回的 HTML 正文转成 Markdown。
/// 只在内容确实是 HTML（出现块级闭合标签）时转换；已是 Markdown 的正文原样返回。
enum HTMLToMarkdown {

    static func looksLikeHTML(_ s: String) -> Bool {
        s.range(of: "</(?:p|div|h[1-6]|li|ul|ol|blockquote|pre|section|article|figure)\\b",
                options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func convert(_ html: String) -> String {
        guard looksLikeHTML(html) else { return html }
        var renderer = Renderer()
        var out = renderer.render(html)
        out = out.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 实体解码

    private static let namedEntities: [String: String] = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
        "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        "&copy;": "©", "&reg;": "®", "&trade;": "™", "&middot;": "·",
        "&laquo;": "«", "&raquo;": "»", "&ldquo;": "“", "&rdquo;": "”",
        "&lsquo;": "‘", "&rsquo;": "’",
    ]

    static func unescape(_ s: String) -> String {
        var out = s
        for (k, v) in namedEntities { out = out.replacingOccurrences(of: k, with: v) }
        while let m = out.range(of: "&#(x)?([0-9a-fA-F]{1,6});", options: .regularExpression) {
            let raw = String(out[m])
            let hex = raw.hasPrefix("&#x") || raw.hasPrefix("&#X")
            let digits = raw.dropFirst(hex ? 3 : 2).dropLast()
            if let code = UInt32(digits, radix: hex ? 16 : 10),
               let scalar = Unicode.Scalar(code) {
                out.replaceSubrange(m, with: String(Character(scalar)))
            } else {
                break
            }
        }
        return out
    }

    // MARK: - 分词

    private struct Token {
        enum Kind { case text, open, close, selfClose }
        let kind: Kind
        let name: String
        let attrs: [String: String]
        let text: String
    }

    private static func tokenize(_ html: String) -> [Token] {
        let chars = Array(html)
        var tokens: [Token] = []
        var textBuf: [Character] = []
        var skipUntil: String? = nil
        var i = chars.startIndex

        func flushText() {
            if !textBuf.isEmpty {
                tokens.append(Token(kind: .text, name: "", attrs: [:], text: String(textBuf)))
                textBuf.removeAll()
            }
        }

        while i < chars.endIndex {
            if chars[i] == "<", let j = chars[i...].firstIndex(of: ">") {
                let inner = Array(chars[chars.index(after: i)..<j])
                let token = parseTag(inner)
                if skipUntil == nil {
                    flushText()
                    tokens.append(token)
                    if token.kind == .open && (token.name == "script" || token.name == "style") {
                        skipUntil = token.name
                    }
                } else if token.kind == .close && token.name == skipUntil {
                    skipUntil = nil
                }
                i = chars.index(after: j)
                continue
            }
            if skipUntil == nil { textBuf.append(chars[i]) }
            i = chars.index(after: i)
        }
        flushText()
        return tokens
    }

    private static func parseTag(_ inner: [Character]) -> Token {
        var s = String(inner)
        var kind: Token.Kind = .open
        if s.hasPrefix("/") { kind = .close; s = String(s.dropFirst()) }
        if s.hasSuffix("/") {
            if kind == .open { kind = .selfClose }
            s = String(s.dropLast())
        }
        s = s.trimmingCharacters(in: .whitespaces)

        let nameChars = s.prefix { !$0.isWhitespace }
        let name = nameChars.lowercased()
        var attrs: [String: String] = [:]
        let rest = Array(s.dropFirst(nameChars.count))
        var i = 0
        while i < rest.count {
            while i < rest.count, rest[i] == " " || rest[i] == "\t" || rest[i] == "\n" { i += 1 }
            var key = ""
            while i < rest.count, rest[i] != "=", rest[i] != " " { key.append(rest[i]); i += 1 }
            key = key.lowercased()
            while i < rest.count, rest[i] == " " { i += 1 }
            guard i < rest.count, rest[i] == "=" else {
                if !key.isEmpty { attrs[key] = "" }
                continue
            }
            i += 1
            var val = ""
            if i < rest.count, rest[i] == "\"" || rest[i] == "'" {
                let quote = rest[i]; i += 1
                while i < rest.count, rest[i] != quote { val.append(rest[i]); i += 1 }
                if i < rest.count { i += 1 }
            } else {
                while i < rest.count, !rest[i].isWhitespace { val.append(rest[i]); i += 1 }
            }
            if !key.isEmpty { attrs[key] = unescape(val) }
        }
        return Token(kind: kind, name: name, attrs: attrs, text: "")
    }

    // MARK: - 渲染

    private struct Renderer {
        struct Frame {
            enum Kind {
                case document, para, soft, heading(Int), list(ordered: Bool, count: Int),
                     li, quote, pre, code, bold, italic, strike, plain, link(String)
            }
            var kind: Kind
            var text = ""
            var lang = ""
        }

        var stack: [Frame] = [Frame(kind: .document)]

        mutating func render(_ html: String) -> String {
            for token in HTMLToMarkdown.tokenize(html) {
                switch token.kind {
                case .text:
                    if insidePre() {
                        append(token.text)
                    } else {
                        let collapsed = token.text
                            .replacingOccurrences(of: "[ \t\r\n\u{0C}]+", with: " ", options: .regularExpression)
                        if collapsed == " " {
                            // 块级容器之间的纯空白没有意义；帧首空白也无意义
                            switch stack[stack.count - 1].kind {
                            case .document, .list, .quote: continue
                            default:
                                if stack[stack.count - 1].text.isEmpty { continue }
                            }
                        }
                        append(HTMLToMarkdown.unescape(collapsed))
                    }
                case .open:
                    handleOpen(token)
                case .selfClose:
                    handleSelfClosed(token)
                case .close:
                    handleClose(token.name)
                }
            }
            while stack.count > 1 { popFrame() }
            return stack[stack.count - 1].text
        }

        // 辅助

        private func insidePre() -> Bool {
            stack.contains { if case .pre = $0.kind { return true }; return false }
        }

        private mutating func append(_ s: String) {
            guard !s.isEmpty else { return }
            stack[stack.count - 1].text += s
        }

        private func imageMarkdown(_ t: Token) -> String {
            let src = t.attrs["src"] ?? ""
            guard !src.isEmpty else { return "" }
            return "![\(t.attrs["alt"] ?? "")](\(src))"
        }

        private mutating func handleSelfClosed(_ t: Token) {
            switch t.name {
            case "br", "source", "track", "wbr": append("\n")
            case "hr": breakBlock("\n---\n")
            case "img": append(imageMarkdown(t))
            default: break
            }
        }

        private mutating func handleOpen(_ t: Token) {
            if insidePre() {
                // 从 <code class="language-x"> 里取语言标注
                if t.name == "code", let idx = stack.lastIndex(where: { if case .pre = $0.kind { return true }; return false }) {
                    for cls in (t.attrs["class"] ?? "").split(separator: " ") {
                        let c = String(cls)
                        if c.hasPrefix("language-") { stack[idx].lang = String(c.dropFirst(9)); break }
                        if c.hasPrefix("lang-") { stack[idx].lang = String(c.dropFirst(5)); break }
                    }
                }
                return
            }
            switch t.name {
            case "p": stack.append(Frame(kind: .para))
            case "div", "section", "article", "main", "header", "footer", "aside", "figure", "figcaption":
                stack.append(Frame(kind: .soft))
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let n = Int(t.name.dropFirst()) ?? 1
                stack.append(Frame(kind: .heading(n)))
            case "ul": stack.append(Frame(kind: .list(ordered: false, count: 0)))
            case "ol": stack.append(Frame(kind: .list(ordered: true, count: 0)))
            case "li": stack.append(Frame(kind: .li))
            case "blockquote": stack.append(Frame(kind: .quote))
            case "pre": stack.append(Frame(kind: .pre))
            case "code": stack.append(Frame(kind: .code))
            case "strong", "b": stack.append(Frame(kind: .bold))
            case "em", "i": stack.append(Frame(kind: .italic))
            case "del", "s", "strike": stack.append(Frame(kind: .strike))
            case "u", "ins", "mark", "span", "font", "small", "sub", "sup":
                stack.append(Frame(kind: .plain))
            case "a": stack.append(Frame(kind: .link(t.attrs["href"] ?? "")))
            case "img": append(imageMarkdown(t))
            case "br": append("\n")
            case "hr": breakBlock("\n---\n")
            case "iframe", "embed", "video", "audio":
                let src = t.attrs["src"] ?? ""
                if !src.isEmpty { append("[嵌入内容：\(src)]") }
            default:
                break   // 未知标签：文本内容保留
            }
        }

        private func matches(_ kind: Frame.Kind, _ name: String) -> Bool {
            switch (kind, name) {
            case (.para, "p"),
                 (.soft, "div"), (.soft, "section"), (.soft, "article"), (.soft, "main"),
                 (.soft, "header"), (.soft, "footer"), (.soft, "aside"), (.soft, "figure"), (.soft, "figcaption"),
                 (.list, "ul"), (.list, "ol"), (.li, "li"), (.quote, "blockquote"),
                 (.pre, "pre"), (.code, "code"),
                 (.bold, "strong"), (.bold, "b"), (.italic, "em"), (.italic, "i"),
                 (.strike, "del"), (.strike, "s"), (.strike, "strike"),
                 (.plain, "u"), (.plain, "ins"), (.plain, "mark"), (.plain, "span"), (.plain, "font"),
                 (.plain, "small"), (.plain, "sub"), (.plain, "sup"), (.link, "a"):
                return true
            case (.heading, _): return name.count == 2 && name.hasPrefix("h")
            default: return false
            }
        }

        private mutating func handleClose(_ name: String) {
            guard stack.count > 1 else { return }
            var found: Int?
            for i in stride(from: stack.count - 1, through: 1, by: -1) where matches(stack[i].kind, name) {
                found = i
                break
            }
            guard let index = found else { return }
            while stack.count - 1 > index { popFrame() }
            popFrame()
        }

        private mutating func breakBlock(_ s: String) {
            if case .para = stack[stack.count - 1].kind { popFrame() }
            else if case .soft = stack[stack.count - 1].kind { popFrame() }
            stack[stack.count - 1].text += s
        }

        /// 弹出栈顶帧，把成果写进父帧
        private mutating func popFrame() {
            guard stack.count > 1 else { return }
            let frame = stack.removeLast()
            var out = ""

            switch frame.kind {
            case .document:
                stack.append(frame)
                return
            case .para, .soft:
                let t = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
                out = t.isEmpty ? "" : t + "\n\n"
            case .heading(let n):
                let t = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
                out = t.isEmpty ? "" : String(repeating: "#", count: n) + " " + t + "\n\n"
            case .list(let ordered, _):
                var text = frame.text
                if case .li = stack[stack.count - 1].kind {
                    // 嵌套列表：缩进后挂进父 li
                    text = text.split(separator: "\n", omittingEmptySubsequences: false)
                        .map { $0.isEmpty ? "" : "  " + $0 }
                        .joined(separator: "\n")
                    out = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n" + text
                } else {
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    out = text.isEmpty ? "" : text + "\n\n"
                }
                _ = ordered
            case .li:
                var marker = "- "
                var parent = stack.count - 1
                while parent >= 1 {
                    if case .list(let ordered, var count) = stack[parent].kind {
                        if ordered {
                            count += 1
                            stack[parent].kind = .list(ordered: true, count: count)
                            marker = "\(count). "
                        }
                        break
                    }
                    if case .document = stack[parent].kind { break }
                    parent -= 1
                }
                if case .list(ordered: false, _) = stack[parent].kind { marker = "- " }
                let t = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
                out = t.isEmpty ? "" : marker + t + "\n"
            case .quote:
                let t = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                out = t.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? ">" : "> " + $0 }
                    .joined(separator: "\n") + "\n\n"
            case .pre:
                let t = HTMLToMarkdown.unescape(frame.text)
                    .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                out = "```" + frame.lang + "\n" + t + "\n```\n\n"
            case .code:
                let t = frame.text.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                let fences = t.contains("``") ? "``" : "`"
                out = fences + t + fences
            case .bold:
                out = wrap(frame.text, "**")
            case .italic:
                out = wrap(frame.text, "*")
            case .strike:
                out = wrap(frame.text, "~~")
            case .plain:
                out = frame.text
            case .link(let href):
                let t = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty || t == href {
                    out = href
                } else {
                    out = "[\(t)](\(href))"
                }
            }
            append(out)
        }

        /// `**text**`：首尾空白挪到标记外，避免 `** x **`
        private func wrap(_ text: String, _ mark: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return text }
            let leading = String(text.prefix(while: { $0 == " " || $0 == "\n" }))
            let trailingCount = text.reversed().prefix(while: { $0 == " " || $0 == "\n" }).count
            let trailing = String(text.suffix(trailingCount))
            return leading + mark + trimmed + mark + trailing
        }
    }
}
