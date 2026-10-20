import SwiftUI
import AppKit

final class EditorBridge {
    weak var textView: NSTextView?
    func insert(_ s: String) {
        if let tv = textView {
            tv.insertText(s, replacementRange: tv.selectedRange())
        }
    }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var bridge: EditorBridge? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.allowsUndo = true
        tv.isRichText = false
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.textColor = .labelColor
        tv.insertionPointColor = .controlAccentColor
        tv.textContainerInset = NSSize(width: 12, height: 16)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.minSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        context.coordinator.textView = tv
        bridge?.textView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            if sel.lowerBound <= tv.string.count { tv.setSelectedRange(sel) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var textView: NSTextView?
        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
