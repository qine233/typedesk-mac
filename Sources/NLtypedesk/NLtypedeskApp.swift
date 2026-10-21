import SwiftUI

@main
struct NLtypedeskApp: App {
    @StateObject private var state = AppState.shared
    @StateObject private var noteStore = NoteStore()

    var body: some Scene {
        WindowGroup("NLtypedesk") {
            RootView()
                .environmentObject(state)
                .environmentObject(noteStore)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建笔记") { state.newNoteTick += 1 }
                    .keyboardShortcut("n", modifiers: .command)
                Button("新文章") { state.newPostTick += 1 }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("搜索…") { state.searchPresented = true }
                    .keyboardShortcut("k", modifiers: .command)
            }
            CommandMenu("面板") {
                Button("本地笔记") { state.pane = .notes }
                    .keyboardShortcut("1", modifiers: .command)
                Button("全部文章") { state.pane = .posts(.all) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("草稿箱") { state.pane = .posts(.draft) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("已发布") { state.pane = .posts(.published) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("页面") { state.pane = .pages }
                    .keyboardShortcut("5", modifiers: .command)
                Button("评论") { state.pane = .comments }
                    .keyboardShortcut("6", modifiers: .command)
                Button("健康记录") { state.pane = .health }
                    .keyboardShortcut("7", modifiers: .command)
                Button("买菜记账") { state.pane = .bills }
                    .keyboardShortcut("8", modifiers: .command)
            }
        }
    }
}
