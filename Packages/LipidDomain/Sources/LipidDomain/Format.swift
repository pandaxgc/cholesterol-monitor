// 显示精度规则（PRD §3.5）：界面显示一律取整，避免假精确。
import Foundation

public enum Fmt {
    /// 四舍五入，.5 向正无穷取整。
    public static func round(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    public static func sat(_ g: Double) -> String { "约 \(round(g)) g" }
    public static func chol(_ mg: Double) -> String { "约 \(round(mg / 10) * 10) mg" }
    public static func fiber(_ g: Double) -> String { "约 \(round(g)) g" }
    public static func transLabel(_ g: Double) -> String { g > 0 ? "含反式脂肪" : "不含反式脂肪" }
    public static func roundPct5(_ ratio: Double) -> Int { round(ratio * 20) * 5 }

    private static let cn = ["零", "一", "两", "三", "四", "五", "六", "七", "八", "九"]

    public static func shareWords(_ ratio: Double) -> String {
        if ratio >= 0.95 { return "几乎全部" }
        let t = round(ratio * 10)
        if t <= 0 { return "不到一成" }
        if t == 5 { return "一半" }
        return "\(cn[min(t, 9)])成"
    }

    /// 相对语言：与个人基线比较。基线不大于 0 时返回 nil。
    public static func diffWords(_ value: Double, base: Double) -> String? {
        guard base > 0 else { return nil }
        let r = (value - base) / base
        let a = abs(r)
        if a < 0.05 { return "和你平时差不多" }
        if r >= 0.95 { return "约为你平时的 \(round(value / base)) 倍" }
        if r <= -0.95 { return "比你平时少九成以上" }
        return "比你平时\(r > 0 ? "多" : "少")\(shareWords(a))"
    }

    /// 数字的最短写法：整数不带小数点。
    public static func number(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : "\(v)"
    }

    public static func servingText(label: String, multiplier m: Double) -> String {
        let ms = m == m.rounded() ? number(m) : m == 0.5 ? "½" : number(Double(round(m * 100)) / 100)
        if label.count == 1 { return m == 0.5 ? "半\(label)" : "\(ms) \(label)" }
        return m == 1 ? label : "\(label) ×\(ms)"
    }

    public static func servingText(_ e: Entry) -> String { servingText(label: e.servingLabel, multiplier: e.multiplier) }
    public static func servingText(_ o: OneTouch) -> String { servingText(label: o.servingLabel, multiplier: o.multiplier) }
    public static func servingText(_ p: Prefill) -> String { servingText(label: p.servingLabel, multiplier: p.multiplier) }
    public static func servingText(_ s: OneTouchSuggestion) -> String { servingText(label: s.servingLabel, multiplier: s.multiplier) }
}
