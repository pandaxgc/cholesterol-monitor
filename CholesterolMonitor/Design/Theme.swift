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
    static let bg = Color(light: 0xFFFFFF, dark: 0x000000)
    static let surface = Color(light: 0xF5F5F7, dark: 0x1C1C1E)
    static let text = Color(light: 0x181818, dark: 0xF5F5F7)
    static let textSecondary = Color(light: 0x6A6A6A, dark: 0xA1A1A6)
    static let textMuted = textSecondary
    static let border = Color(light: 0xE8E8ED, dark: 0x2C2C2E)
    static let fill = Color(light: 0xEBEBF0, dark: 0x2C2C2E)
    static let fillStrong = Color(light: 0xDCDCE0, dark: 0x3A3A3C)
    static let accent = Color(light: 0x1F6F63, dark: 0x4FB3A3)
    static let accentFg = Color(light: 0xFFFFFF, dark: 0x04201C)
    static let warn = Color(light: 0xB05A36, dark: 0xD9845E)
    static let warnText = warn
    static let warnFg = Color(light: 0xFFFFFF, dark: 0x2A1206)
    static let kb = Color(light: 0xF5F5F7, dark: 0x1C1C1E)
    static let kbFn = Color(light: 0xE3E3E8, dark: 0x3A3A3C)
    static let key = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let toastBg = Color(light: 0x181818, dark: 0xF5F5F7)
    static let toastFg = Color(light: 0xFFFFFF, dark: 0x181818)

    static let radius: CGFloat = 24
    static let gutter: CGFloat = 24
    static let cellX: CGFloat = 24
    static let cellY: CGFloat = 20

    /// 余额大数字：页面里唯一的大号数据，不随系统文本样式缩放。
    static let display = Font.custom("Geist", fixedSize: 56).weight(.bold)
    static let groupTitle = Font.gTitle

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

    /// 打包的 Geist 字体在启动时注册，不依赖 Info.plist。
    static func registerFonts() {
        for name in ["Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        if let title = UIFont(name: "Geist-Bold", size: 18) {
            nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title), .foregroundColor: UIColor(Theme.text)]
        }
        if let large = UIFont(name: "Geist-Bold", size: 32) {
            nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .foregroundColor: UIColor(Theme.text)]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

extension Font {
    /// 标题 18、正文 16、辅助 14；层级靠字重和颜色区分。
    static let gTitle = Font.custom("Geist", size: 18, relativeTo: .headline).weight(.bold)
    static let gBody = Font.custom("Geist", size: 16, relativeTo: .body)
    static let gSmall = Font.custom("Geist", size: 14, relativeTo: .subheadline)
}

/// Reicon 线性图标：24×24 透明框，线宽 1.5。调用处沿用 SF Symbols 的名字，在这里换成对应的 Reicon。
struct Icon: View {
    let name: String
    var size: CGFloat = 24

    init(_ name: String, size: CGFloat = 24) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(Icon.asset(name))
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    static func asset(_ name: String) -> String {
        let map = [
            "magnifyingglass": "search", "plus": "add", "pencil": "edit", "doc.text": "document-text", "doc.text.fill": "document-text",
            "checkmark": "check", "arrow.down.doc": "document-download", "xmark": "x", "xmark.circle.fill": "x-circle",
            "text.bubble.fill": "message-text", "shield.fill": "shield", "person": "user", "list.bullet": "list",
            "gauge.with.needle": "gauge", "flask.fill": "flask", "doc.on.doc": "copy", "chart.bar.fill": "chart-bar",
            "book.closed.fill": "book", "fork.knife": "fork-knife", "exclamationmark.triangle": "alert-triangle",
        ]
        return "re." + (map[name] ?? name.replacingOccurrences(of: ".", with: "-"))
    }
}

/// 只保留中性色：功能图标不再用彩色底块。
enum TileTone {
    case accent, blue, purple, orange, red, gray, dark
}
