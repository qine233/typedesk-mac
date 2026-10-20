import SwiftUI

struct MetaSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ErrorBanner(message: $state.lastError)
            HStack {
                Text("分类与标签").font(.system(size: 17, weight: .bold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button { Task { await state.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        Text("分类").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMain)
                        if state.categories.isEmpty {
                            hint("暂无分类，发布文章时填写分类会自动创建")
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(state.categories) { cat in chip(cat.name, accent: true) }
                            }
                        }
                    }
                    Group {
                        Text("标签").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMain)
                        if state.tags.isEmpty {
                            hint("暂无标签")
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(state.tags) { tag in chip(tag.name, accent: false) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Theme.bg)
        .task { if state.categories.isEmpty { await state.refresh() } }
    }

    private func hint(_ s: String) -> some View {
        Text(s).font(.system(size: 12)).foregroundColor(Theme.textLight)
    }

    private func chip(_ name: String, accent: Bool) -> some View {
        Text(name)
            .font(.system(size: 12))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(accent ? Theme.accentBg : Theme.surfaceSoft)
            .foregroundColor(accent ? Theme.accent : Theme.textSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(accent ? Theme.accent.opacity(0.25) : Theme.borderSoft, lineWidth: 1))
    }
}

/// 简单流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
