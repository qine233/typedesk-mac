import SwiftUI

struct StatusPill: View {
    let status: String
    var body: some View {
        let published = status == TSStatus.published
        Text(published ? "已发布" : (status == "pending" ? "待审" : "草稿"))
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((published ? Theme.statusPublish : Theme.statusDraft).opacity(0.12))
            .foregroundColor(published ? Theme.statusPublish : Theme.statusDraft)
            .clipShape(Capsule())
    }
}

/// 空态插画：纸页 + 墨水瓶 + 暖黄日轮（呼应 --heading-marker）
struct EmptyInkIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.headingMarker.opacity(0.35))
                .frame(width: 54, height: 54)
                .offset(x: 34, y: -40)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cardBorder))
                .frame(width: 72, height: 92)
                .rotationEffect(.degrees(-6))
                .offset(x: -26, y: 4)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.surfaceSoft)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cardBorder))
                .frame(width: 72, height: 92)
                .rotationEffect(.degrees(4))
                .offset(x: 6, y: 0)
            // 三条文字线
            VStack(alignment: .leading, spacing: 8) {
                line(38); line(48); line(28)
            }
            .offset(x: 8, y: -14)
            // 墨水瓶
            VStack(spacing: 0) {
                Rectangle().fill(Theme.accent.opacity(0.8)).frame(width: 10, height: 6)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.accent.opacity(0.55))
                    .frame(width: 24, height: 20)
            }
            .offset(x: 46, y: 34)
        }
        .frame(width: 140, height: 130)
    }

    private func line(_ w: CGFloat) -> some View {
        Capsule().fill(Theme.borderStrong).frame(width: w, height: 4)
    }
}

struct EmptyStateView: View {
    var title: String
    var subtitle: String
    var body: some View {
        VStack(spacing: 16) {
            EmptyInkIllustration()
            Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(Theme.textMain)
            Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.textLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    @Binding var message: String?
    var body: some View {
        if let message {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.statusDraft)
                Text(message).font(.system(size: 12)).foregroundColor(Theme.textMain).lineLimit(2)
                Spacer()
                Button { self.message = nil } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundColor(Theme.textLight)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.statusDraft.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            .padding(.horizontal, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
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
