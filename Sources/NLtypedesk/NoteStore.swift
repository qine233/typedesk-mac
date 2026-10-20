import Foundation
import SwiftUI

struct Note: Identifiable, Equatable {
    var id: String { path }
    var path: String
    var title: String
    var text: String
    var updated: Date
}

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let dir: URL
    private let mapURL: URL
    private var cidMap: [String: Int] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InkDesk/Notes", isDirectory: true)
        dir = base
        mapURL = base.deletingLastPathComponent().appendingPathComponent("syncmap.json")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: mapURL),
           let map = try? JSONDecoder().decode([String: Int].self, from: data) {
            cidMap = map
        }
        reload()
    }

    /// 本地笔记 ↔ 站点草稿 cid 的映射（自动同步用）
    func remoteCid(for path: String) -> Int { cidMap[path] ?? 0 }

    func setRemoteCid(_ path: String, _ cid: Int) {
        cidMap[path] = cid
        if let data = try? JSONEncoder().encode(cidMap) {
            try? data.write(to: mapURL)
        }
    }

    func clearRemoteCid(_ path: String) {
        cidMap.removeValue(forKey: path)
        if let data = try? JSONEncoder().encode(cidMap) {
            try? data.write(to: mapURL)
        }
    }

    func reload() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        notes = files.filter { $0.pathExtension == "md" }.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let mod = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
            let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
            let title = firstLine.hasPrefix("# ") ? String(firstLine.dropFirst(2)) : url.deletingPathExtension().lastPathComponent
            return Note(path: url.path, title: title, text: text, updated: mod)
        }
        .sorted { $0.updated > $1.updated }
    }

    @discardableResult
    func create(title: String = "未命名笔记") -> Note {
        let name = Self.fileName(for: title)
        let url = dir.appendingPathComponent(name)
        let body = "# \(title)\n\n"
        try? body.write(to: url, atomically: true, encoding: .utf8)
        reload()
        return notes.first { $0.path == url.path } ?? Note(path: url.path, title: title, text: body, updated: Date())
    }

    func save(_ note: Note) {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? note.text.write(to: URL(fileURLWithPath: note.path), atomically: true, encoding: .utf8)
        reload()
    }

    func delete(_ note: Note) {
        try? FileManager.default.removeItem(atPath: note.path)
        clearRemoteCid(note.path)
        reload()
    }

    static func fileName(for title: String) -> String {
        let safe = title.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>| \n"))
            .filter { !$0.isEmpty }.joined(separator: "-")
        let base = safe.isEmpty ? "note" : String(safe.prefix(40))
        return base + "-\(Int(Date().timeIntervalSince1970)).md"
    }
}
