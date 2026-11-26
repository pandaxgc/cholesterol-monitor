// 通用组件：分组卡片、列表行、数值排版、等级标记、分段控件等。
// 层级靠字重和颜色建立：主要元素 600/700，次要文字用灰色而不是更小的字号。
import LipidDomain
import SwiftUI

// MARK: 数值排版

/// 数字加粗、主文本色；“约”和单位同字号，只用灰色降一级。没有数字的文本原样显示。
func amountText(_ text: String, font: Font = .body, number: Color = .primary, unit: Color = Theme.textMuted,
                weight: Font.Weight = .semibold, unitFont: Font? = nil) -> AttributedString {
    var out = AttributedString()
    guard text.contains(where: \.isNumber) else {
        var a = AttributedString(text)
        a.font = font.weight(weight)
        a.foregroundColor = number
        return a
    }
    var run = "", runIsNumber = false
    func flush() {
        guard !run.isEmpty else { return }
        var a = AttributedString(run)
        a.font = runIsNumber ? font.weight(weight).monospacedDigit() : (unitFont ?? font)
        a.foregroundColor = runIsNumber ? number : unit
        out += a
        run = ""
    }
    for ch in text {
        let isNumber = ch.isASCII && (ch.isNumber || (ch == "." && runIsNumber))
        if isNumber != runIsNumber { flush() }
        runIsNumber = isNumber
        run.append(ch)
    }
    flush()
    return out
}

struct Amount: View {
    let text: String
    var font: Font = .body
    var warn = false

    init(_ text: String, font: Font = .body, warn: Bool = false) {
        self.text = text
        self.font = font
        self.warn = warn
    }

    var body: some View {
        Text(amountText(text, font: font, number: warn ? Theme.warnText : .primary))
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: 小标记

/// 等级同时用图形和文字表达：实心圆点 / 半环 / 空心圆环。
struct GradeBadge: View {
    let grade: Grade

    var body: some View {
        HStack(spacing: 4) {
            shape.frame(width: 11, height: 11)
            Text(grade.label)
        }
        .font(.caption2.weight(grade == .c ? .semibold : .medium))
        .foregroundStyle(grade == .c ? Color.primary : Theme.textMuted)
        .padding(.leading, 5)
        .padding(.trailing, 7)
        .padding(.vertical, 3)
        .background(Theme.fill, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(grade.label)
    }

    @ViewBuilder private var shape: some View {
        switch grade {
        case .a: Circle().padding(1)
        case .b: Circle().trim(from: 0.5, to: 1).stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).padding(1.5).offset(y: 2)
        case .c: Circle().stroke(lineWidth: 1.8).padding(1.5)
        }
    }
}

struct TagLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.fill, in: Capsule())
            .fixedSize()
    }
}

/// 彩色圆角方块图标（设置与功能行）。
struct IconTile: View {
    let symbol: String
    var tone: TileTone = .accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tone == .accent ? Theme.accentFg : .white)
            .frame(width: 30, height: 30)
            .background(tone.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 行首的线性图标（主色）。
struct RowIcon: View {
    let symbol: String
    var danger = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(danger ? Theme.warnText : Theme.accent)
            .frame(width: 28)
            .accessibilityHidden(true)
    }
}

/// Emoji 是装饰性元素：读屏读食物名，不读 Emoji。
struct EmojiIcon: View {
    @Environment(Prefs.self) private var prefs
    let emoji: String
    var size: CGFloat?

    init(_ emoji: String, size: CGFloat? = nil) {
        self.emoji = emoji
        self.size = size
    }

    var body: some View {
        let s = size ?? CGFloat(prefs.emojiSize)
        Text(emoji)
            .font(.system(size: s))
            .frame(width: s * 1.25)
            .accessibilityHidden(true)
    }
}

// MARK: 分组卡片

/// 原生分组列表样式的卡片：标题在外，行在圆角卡片内，行间细分隔线。
struct CardGroup<Content: View>: View {
    var title: String?
    var right: String?
    var tag: String?
    var footer: String?
    var headline = false
    /// 分隔线的左缩进（从文字起始处开始）
    var separatorInset: CGFloat = Theme.cellX
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || right != nil {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let title {
                        Text(title)
                            .font(headline ? Theme.groupTitle : .footnote.weight(.semibold))
                            .foregroundStyle(headline ? Color.primary : Theme.textMuted)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let tag { TagLabel(tag) }
                    Spacer(minLength: 0)
                    if let right { Amount(right, font: headline ? .subheadline : .footnote) }
                }
                .padding(.horizontal, headline ? 8 : Theme.cellX)
                .padding(.bottom, headline ? 10 : 7)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { i, v in
                        if i > 0 {
                            Rectangle().fill(Theme.border).frame(height: 1 / 3).padding(.leading, separatorInset).padding(.trailing, Theme.cellX)
                        }
                        v
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(2)
                    .padding(.horizontal, Theme.cellX)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 28)
    }
}

/// 卡片里的一段正文。
struct CellText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.body)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.cellX)
            .padding(.vertical, 12)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: 列表行

enum RowStyle {
    case normal, guide, prefill, advice
}

/// 列表行：行首图标 + 标题（可带份量、等级）+ 副标题 + 行尾数值 / 控件。
struct LedgerRow<Lead: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var title: String
    var titleColor: Color = .primary
    var detail: String?
    var grade: Grade?
    var tag: String?
    var sub: String?
    var subAttributed: AttributedString?
    var value: String?
    var valueWarn = false
    var chevron = false
    var style: RowStyle = .normal
    @ViewBuilder var lead: Lead
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            lead.opacity(style == .prefill ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                titleLine
                if let subAttributed {
                    Text(subAttributed).font(.footnote)
                } else if let sub {
                    Text(sub).font(.footnote).foregroundStyle(Theme.textMuted)
                }
                // 大字号下数值换到第二行
                if typeSize.isAccessibilitySize, let value { Amount(value, warn: valueWarn).opacity(style == .prefill ? 0.5 : 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize, let value { Amount(value, warn: valueWarn).opacity(style == .prefill ? 0.5 : 1) }
            trailing
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textMuted.opacity(0.55))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.cellX)
        .padding(.vertical, Theme.cellY)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(style == .guide || style == .advice ? .body : .body.weight(.semibold))
                .foregroundStyle(style == .guide ? Theme.textSecondary : titleColor)
                .lineSpacing(style == .advice ? 4 : 0)
                .opacity(style == .prefill ? 0.5 : 1)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary).lineLimit(1).layoutPriority(-1)
            }
            if let grade { GradeBadge(grade: grade).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 } }
            if let tag { TagLabel(tag).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 } }
        }
    }
}

extension LedgerRow where Lead == EmptyView, Trailing == EmptyView {
    init(title: String, titleColor: Color = .primary, detail: String? = nil, grade: Grade? = nil, tag: String? = nil, sub: String? = nil,
         subAttributed: AttributedString? = nil, value: String? = nil, valueWarn: Bool = false, chevron: Bool = false, style: RowStyle = .normal) {
        self.init(title: title, titleColor: titleColor, detail: detail, grade: grade, tag: tag, sub: sub, subAttributed: subAttributed,
                  value: value, valueWarn: valueWarn, chevron: chevron, style: style, lead: { EmptyView() }, trailing: { EmptyView() })
    }
}

extension LedgerRow where Trailing == EmptyView {
    init(title: String, titleColor: Color = .primary, detail: String? = nil, grade: Grade? = nil, tag: String? = nil, sub: String? = nil,
         subAttributed: AttributedString? = nil, value: String? = nil, valueWarn: Bool = false, chevron: Bool = false, style: RowStyle = .normal,
         @ViewBuilder lead: () -> Lead) {
        self.init(title: title, titleColor: titleColor, detail: detail, grade: grade, tag: tag, sub: sub, subAttributed: subAttributed,
                  value: value, valueWarn: valueWarn, chevron: chevron, style: style, lead: lead, trailing: { EmptyView() })
    }
}

/// 按下即反馈：整行变灰。
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Theme.fill : Color.clear)
    }
}

/// 可点的行。
struct RowButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) { label }.buttonStyle(RowButtonStyle())
    }
}

// MARK: 控件

/// 胶囊形分段控件。
struct PillSegmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var label: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                let on = o.0 == selection
                Button { selection = o.0 } label: {
                    Text(o.1)
                        .font(.footnote.weight(on ? .semibold : .medium))
                        .foregroundStyle(on ? Color.primary : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background {
                            if on {
                                Capsule().fill(Color(light: 0xFFFFFF, dark: 0x636366))
                                    .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.fill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

enum ButtonTone {
    case primary, secondary, warn
}

/// 胶囊形主按钮。
struct PillButtonStyle: ButtonStyle {
    var tone: ButtonTone = .primary
    var danger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .background(background, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .primary: Theme.accentFg
        case .secondary: danger ? Theme.warnText : Theme.accent
        case .warn: Theme.warnFg
        }
    }

    private var background: Color {
        switch tone {
        case .primary: Theme.accent
        case .secondary: Theme.fill
        case .warn: Theme.warnText
        }
    }
}

/// 一行按钮，左右留白与分组一致。
struct ButtonRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) { content }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 16)
    }
}

/// 说明文字（面板里的一段话）。
struct SheetNote: View {
    let text: String
    var strong = false

    init(_ text: String, strong: Bool = false) {
        self.text = text
        self.strong = strong
    }

    var body: some View {
        Text(text)
            .font(strong ? .body : .subheadline)
            .foregroundStyle(strong ? Color.primary : Theme.textSecondary)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.gutter + Theme.cellX)
            .padding(.top, 6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 胶囊形搜索框。
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 48)
        .background(Theme.fill, in: Capsule())
    }
}

/// 示例数据必须明确标注：提示卡样式。
struct DemoBanner: View {
    @Environment(AppStore.self) private var store
    @State private var confirm = false

    var body: some View {
        if store.settings.demo {
            VStack(spacing: 0) {
                HStack {
                    Text("示例数据").foregroundStyle(Theme.textMuted)
                    Spacer()
                    Button("清空，开始记录") { confirm = true }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("demo-clear")
                }
                .font(.footnote)
                .padding(.horizontal, Theme.cellX)
                .frame(minHeight: 36)
                Rectangle().fill(Theme.border).frame(height: 1 / 3)
                HStack(spacing: 14) {
                    Image(systemName: "text.bubble.fill").font(.system(size: 26)).foregroundStyle(Color(red: 0xF5 / 255, green: 0xC5 / 255, blue: 0x42 / 255))
                        .accessibilityHidden(true)
                    Text("这里的饮食记录和化验值是演示生成的，不是真实数据。")
                        .font(.body.weight(.semibold))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.cellX)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("demo-banner")
            .clearDemoAlert(isPresented: $confirm)
        }
    }
}

extension View {
    /// 清空示例数据前的确认。
    func clearDemoAlert(isPresented: Binding<Bool>) -> some View {
        modifier(ClearDemoAlert(isPresented: isPresented))
    }
}

private struct ClearDemoAlert: ViewModifier {
    @Environment(AppStore.self) private var store
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert("清空示例数据", isPresented: $isPresented) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                store.reset(.blank)
                ToastCenter.shared.show("已清空，可以开始记录了")
            }
        } message: {
            Text("会删除全部饮食记录、化验结果、离群日标记和 One Touch（包括你在示例里添加的），限额恢复为 4 条默认值。之后从空白开始记录。")
        }
    }
}

/// 自动换行的横排布局。
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let w = rows.map { $0.width }.max() ?? 0
        let h = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let add = rows[rows.count - 1].items.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + add > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let extra = rows[rows.count - 1].items.isEmpty ? size.width : size.width + spacing
            rows[rows.count - 1].items.append(i)
            rows[rows.count - 1].width += extra
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

/// 页面骨架：滚动内容 + 背景色。
struct Page<Content: View>: View {
    var bottomInset: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, bottomInset)
        }
        .background(Theme.bg)
        .scrollDismissesKeyboard(.interactively)
    }
}
