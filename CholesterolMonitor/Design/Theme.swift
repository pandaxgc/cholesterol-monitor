// 设计令牌：与 web-prototype/public/styles.css 一致。主色与警示色来自 PRD §9.3。
import SwiftUI

extension Color {
    /// SwiftUI 可能在渲染线程解析动态颜色，所以 provider 不能隔离到主线程。
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(dynamicProvider: { @Sendable traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }))
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

enum Theme {
    static let bg = Color(light: 0xF2F2F7, dark: 0x1C1C1E)
    static let surface = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let textSecondary = Color(light: 0x48484A, dark: 0xC7C7CC)
    static let textMuted = Color(light: 0x6E6E73, dark: 0x9E9EA5)
    static let border = Color(uiColor: .separator)
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let fillStrong = Color(uiColor: .systemFill)
    static let accent = Color(light: 0x1F6F63, dark: 0x4FB3A3)
    static let accentFg = Color(light: 0xFFFFFF, dark: 0x04201C)
    static let warn = Color(light: 0xC4643C, dark: 0xE08A63)
    static let warnText = Color(light: 0xA3512F, dark: 0xE08A63)
    static let warnFg = Color(light: 0xFFFFFF, dark: 0x2A1206)
    static let kb = Color(light: 0xD1D4DB, dark: 0x232325)
    static let kbFn = Color(light: 0xABB0BC, dark: 0x48484A)
    static let key = Color(light: 0xFFFFFF, dark: 0x6B6B70)
    static let toastBg = Color(light: 0x000000, dark: 0xFFFFFF)
    static let toastFg = Color(light: 0xF2F2F7, dark: 0x1C1C1E)

    static let radius: CGFloat = 24
    static let gutter: CGFloat = 16
    static let cellX: CGFloat = 18
    static let cellY: CGFloat = 13

    /// 余额大数字：唯一不随系统文本样式缩放的字号。
    static let display = Font.system(size: 56, weight: .heavy, design: .rounded)
    /// 分组大标题
    static let groupTitle = Font.title3.weight(.bold)

    static func heat(_ level: Int) -> Color {
        switch level {
        case 1: accent.opacity(0.18)
        case 2: accent.opacity(0.38)
        case 3: accent.opacity(0.58)
        case 4: accent.opacity(0.8)
        case 5: accent
        default: fill
        }
    }
}

enum TileTone {
    case accent, blue, purple, orange, red, gray, dark

    var color: Color {
        switch self {
        case .accent: Theme.accent
        case .blue: Color(red: 0x34 / 255, green: 0x78 / 255, blue: 0xF6 / 255)
        case .purple: Color(red: 0xAF / 255, green: 0x52 / 255, blue: 0xDE / 255)
        case .orange: Color(red: 0xF0 / 255, green: 0x9A / 255, blue: 0x37 / 255)
        case .red: Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
        case .gray: Color(red: 0x63 / 255, green: 0x6A / 255, blue: 0x73 / 255)
        case .dark: Color(light: 0x1C1C1E, dark: 0x48484A)
        }
    }
}
