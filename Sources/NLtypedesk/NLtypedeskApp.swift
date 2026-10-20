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
    }
}
