import SwiftUI

private func hexRGB(_ s: String) -> (Double, Double, Double) {
    var str = s.trimmingCharacters(in: .whitespaces).lowercased()
    if str.hasPrefix("#") { str.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: str).scanHexInt64(&v)
    guard str.count == 6 else { return (0, 0, 0) }
    return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
}

private func dyn(_ light: String, _ dark: String, lightA: Double = 1, darkA: Double = 1) -> Color {
    let (lr, lg, lb) = hexRGB(light)
    let (dr, dg, db) = hexRGB(dark)
    return Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(red: isDark ? dr : lr, green: isDark ? dg : lg, blue: isDark ? db : lb,
                       alpha: isDark ? darkA : lightA)
    })
}

/// 令牌取自 noline design.min.css（light :root / [data-theme=dark]）
enum Theme {
    // 品牌
    static let accent = dyn("#425aef", "#8a9bff")
    static let accentHover = dyn("#3549c9", "#a3b2ff")
    static let accentBg = dyn("#425aef", "#8a9bff", lightA: 0.10, darkA: 0.18)
    static let accentRing = dyn("#425aef", "#8a9bff", lightA: 0.35, darkA: 0.45)
    /// 标题标记暖黄，用于点缀
    static let headingMarker = dyn("#f2ba4b", "#e8c476")

    // 表面
    static let bg = dyn("#f7f9fe", "#17191d")
    static let card = dyn("#ffffff", "#1b1c20")
    static let surfaceSoft = dyn("#f7f7f9", "#21232a")
    static let surfaceSunken = dyn("#f2f5f8", "#0f1013")
    static let glassBg = dyn("#ffffff", "#17191d", lightA: 0.72, darkA: 0.72)

    // 描边
    static let cardBorder = dyn("#e3e8f7", "#3d3d3f")
    static let borderSoft = dyn("#363636", "#f7f7fa", lightA: 0.07, darkA: 0.07)
    static let borderStrong = dyn("#363636", "#f7f7fa", lightA: 0.20, darkA: 0.16)

    // 文字（ink 54,54,54 / 247,247,250，层级 1/.90/.78/.50 — .86/.66/.46）
    static let textStrong = dyn("#363636", "#f7f7fa")
    static let textMain = dyn("#363636", "#f7f7fa", lightA: 0.90, darkA: 0.86)
    static let textSecondary = dyn("#363636", "#f7f7fa", lightA: 0.78, darkA: 0.66)
    static let textLight = dyn("#363636", "#f7f7fa", lightA: 0.50, darkA: 0.46)

    // 状态（verb / health）
    static let statusPublish = dyn("#2f7a44", "#6ec389")
    static let statusDraft = dyn("#a8600f", "#e0b25c")
    static let danger = dyn("#b3352f", "#e57373")
    static let info = dyn("#2f7f8c", "#58bdd0")

    // 圆角
    static let radiusMd: CGFloat = 8
    static let radiusLg: CGFloat = 12
    static let radiusImg: CGFloat = 16
    static let radiusPill: CGFloat = 999
}

struct CardBackground: ViewModifier {
    var hover: Bool = false
    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .stroke(hover ? Theme.accent : Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}

extension View {
    func inkCard(hover: Bool = false) -> some View { modifier(CardBackground(hover: hover)) }
}
