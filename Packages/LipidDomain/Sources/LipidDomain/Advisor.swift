// 建议引擎（PRD §8）：固定规则，自上而下，命中即停；同样的记录总会得到同样的建议。
import Foundation

public enum Advisor {
    static let srcDiet = "《中国居民膳食指南（2022）》"
    static let srcLipid = "《中国血脂管理指南（2023 年）》"
    static let srcAHA = "2018 AHA/ACC Guideline on the Management of Blood Cholesterol"

    public struct Booster: Equatable, Sendable {
        public var foodId: String
        public var servingLabel: String

        public init(foodId: String, servingLabel: String) {
            self.foodId = foodId
            self.servingLabel = servingLabel
        }
    }

    /// 替代食物：只接受友好级。
    public static func swap(for food: Food, foods: [String: Food], categories: [String: FoodCategory]) -> Food? {
        let id: String?
        switch food.swap {
        case .inherit: id = categories[food.category]?.swap
        case .none: id = nil
        case .food(let f): id = f
        }
        guard let id, id != food.id, let s = foods[id], s.grade == .a else { return nil }
        return s
    }

    /// 离群日或无记录返回 nil。`recentKeys` 是近 7 天已给出的建议。
    public static func advise(spend: DailySpend, mode: BudgetMode, weekly: [WeeklyCount] = [], isOutlier: Bool = false,
                              recentKeys: Set<String> = [], foods: [String: Food], categories: [String: FoodCategory],
                              boosters: [Booster] = []) -> Advice? {
        guard !isOutlier, !spend.items.isEmpty else { return nil }
        let budget = Budget.sat(mode), budgetText = Fmt.number(budget)
        func rec(_ i: SpendItem) -> Advice.Record {
            Advice.Record(name: i.food.name, meal: i.entry.meal.label, serving: Fmt.servingText(i.entry), sat: Fmt.sat(i.n.sat))
        }
        var out: [Advice] = []

        // P0 反式脂肪
        var seen = Set<String>()
        for i in spend.items.filter({ $0.food.nutritionPer100g.transFatG > 0 }).stableSorted(by: { $0.n.trans > $1.n.trans }) {
            guard seen.insert(i.food.id).inserted else { continue }
            let s = swap(for: i.food, foods: foods, categories: categories)
            out.append(Advice(
                key: "P0:\(i.food.id)", priority: 0,
                text: "今天的\(i.food.name)含反式脂肪，这类成分对血脂影响最大，\(s.map { "下次可以换成\($0.name)。" } ?? "下次可以换一种不含反式脂肪的做法。")",
                why: .init(records: [rec(i)], calc: "食物库中\(i.food.name)的反式脂肪含量大于 0。反式脂肪是零预算项，尽量为 0，上限 \(Fmt.number(Budget.transMaxG)) g。", source: srcDiet)))
        }

        // P1 饱和脂肪超出主预算：按预计可省克数排序
        if spend.total.sat > budget {
            let all = spend.items.map { i -> (i: SpendItem, s: Food?, saving: Double) in
                let s = swap(for: i.food, foods: foods, categories: categories)
                let saving = s.map { i.n.sat - $0.nutritionPer100g.satFatG * i.entry.grams / 100 } ?? i.n.sat / 2
                return (i, s, saving)
            }.filter { Fmt.round($0.saving) >= 1 }.stableSorted { $0.saving > $1.saving }
            // 可行性：优先动非友好级的食物；全是友好级时才退而求其次
            let notFriendly = all.filter { $0.i.food.grade != .a }
            for (i, s, saving) in (notFriendly.isEmpty ? all : notFriendly).prefix(3) {
                let share = i.n.sat / spend.total.sat
                let swapCalc = s.map { "同样份量的\($0.name)\(Fmt.sat($0.nutritionPer100g.satFatG * i.entry.grams / 100))" } ?? "份量减半后约为原来的一半"
                out.append(Advice(
                    key: "P1:\(i.food.id)", priority: 1,
                    text: "\(i.food.name)约占今天饱和脂肪的\(Fmt.shareWords(share))（\(Fmt.sat(i.n.sat))）。\(s.map { "换成\($0.name)" } ?? "份量减半")，预计可省\(Fmt.sat(saving))。",
                    why: .init(
                        records: [rec(i)],
                        calc: "今天饱和脂肪合计\(Fmt.sat(spend.total.sat))，超出主预算 \(budgetText) g。\(i.food.name)\(Fmt.sat(i.n.sat))，占\(Fmt.shareWords(share))。\(swapCalc)，差值\(Fmt.sat(saving))。",
                        source: "\(srcDiet)、\(srcAHA)")))
            }
        }

        // P2 限额类别本周已达上限
        for w in weekly where w.reached {
            let cat = categories[w.limit.category]
            let name = cat?.name ?? w.limit.category
            let s = cat?.swap.flatMap { foods[$0] }
            out.append(Advice(
                key: "P2:\(w.limit.category)", priority: 2,
                text: "这周\(name)已经 \(w.count) 次，\(w.over ? "超过上限了" : "到上限了")。\(s.map { "接下来几天可以用\($0.name)顶上。" } ?? "接下来几天可以先换别的。")",
                why: .init(records: [], calc: "本周（周一至周日）\(name)记了 \(w.count) 次，上限每周 \(w.limit.maxCount) 次。同一餐同一类别只计 1 次。", source: "每周次数限额是产品建议值，不是指南原文")))
        }

        // P3 可溶性纤维不足目标的 60%
        if spend.total.fiber < Budget.fiberG * 0.6 {
            for b in boosters {
                guard let f = foods[b.foodId], let grams = f.serving(b.servingLabel)?.grams, grams > 0 else { continue }
                let m = f.nutritionPer100g.solubleFiberG * grams / 100
                out.append(Advice(
                    key: "P3:\(f.id)", priority: 3,
                    text: "今天纤维\(Fmt.fiber(spend.total.fiber))。明天加一份\(f.name)，大约能补 \(max(1, Fmt.round(m))) g。",
                    why: .init(records: [], calc: "今天可溶性纤维合计\(Fmt.fiber(spend.total.fiber))，不足目标 \(Fmt.number(Budget.fiberG)) g 的六成。纤维是独立的储蓄目标，不与饱和脂肪相抵。", source: srcLipid)))
            }
        }

        // P4 膳食胆固醇超出预算
        if spend.total.chol > Budget.cholMg, let top = spend.items.stableSorted(by: { $0.n.chol > $1.n.chol }).first {
            let fits = spend.total.chol - top.n.chol / 2 <= Budget.cholMg
            out.append(Advice(
                key: "P4:\(top.food.id)", priority: 4,
                text: "今天胆固醇\(Fmt.chol(spend.total.chol))，主要来自\(top.food.name)，\(fits ? "明天减半就在预算内。" : "明天这一样减半，会更接近预算。")",
                why: .init(records: [rec(top)], calc: "今天膳食胆固醇合计\(Fmt.chol(spend.total.chol))，副预算 \(Fmt.number(Budget.cholMg)) mg。\(top.food.name)\(Fmt.chol(top.n.chol))，是最大的一项。", source: srcDiet)))
        }

        // 同一条建议 7 天内不重复；命中的规则若会重复，则顺延
        if let fresh = out.first(where: { !recentKeys.contains($0.key) }) { return fresh }
        // 全部命中项都在 7 天内给过：仍给出最高优先级的一条，而不是谎称“都在预算内”
        if let first = out.first { return first }
        return Advice(
            key: "P5", priority: 5,
            text: "今天各项都在预算内，照这个结构吃就行。",
            why: .init(records: [], calc: "饱和脂肪\(Fmt.sat(spend.total.sat))（预算 \(budgetText) g），胆固醇\(Fmt.chol(spend.total.chol))（预算 \(Fmt.number(Budget.cholMg)) mg），今天的记录\(spend.total.trans > 0 ? "含" : "不含")反式脂肪。", source: "\(srcDiet)、\(srcLipid)"))
    }
}
