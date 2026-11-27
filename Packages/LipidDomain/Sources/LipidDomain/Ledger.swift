// 聚合与派生（PRD §7.3）：全部为纯函数，不落库。
import Foundation

public enum Ledger {
    // MARK: 聚合

    public static func nutrition(grams: Double, food: Food) -> Totals {
        let k = grams / 100, n = food.nutritionPer100g
        return Totals(sat: n.satFatG * k, trans: n.transFatG * k, chol: n.cholesterolMg * k, fiber: n.solubleFiberG * k)
    }

    public static func nutrition(of entry: Entry, food: Food) -> Totals { nutrition(grams: entry.grams, food: food) }

    /// DailySpend：某日四项合计、各餐小计。
    public static func dailySpend(_ dayEntries: [Entry], foods: [String: Food]) -> DailySpend {
        var s = DailySpend()
        for m in Meal.allCases { s.meals[m] = Totals() }
        for entry in dayEntries {
            guard let food = foods[entry.foodId] else { continue }
            let n = nutrition(of: entry, food: food)
            s.total += n
            s.meals[entry.meal, default: Totals()] += n
            s.items.append(SpendItem(entry: entry, food: food, n: n))
        }
        return s
    }

    public static func balance(_ mode: BudgetMode, sat: Double) -> Double { Budget.sat(mode) - sat }

    public static func totalsByDay(_ entries: [Entry], foods: [String: Food]) -> [String: Totals] {
        var m: [String: Totals] = [:]
        for e in entries {
            guard let food = foods[e.foodId] else { continue }
            m[e.day, default: Totals()] += nutrition(of: e, food: food)
        }
        return m
    }

    /// Baseline：`beforeDay` 之前最近 14 个非离群记录日的均值；不足 5 天返回 nil。
    public static func baseline(_ totals: [String: Totals], outliers: Set<String>, beforeDay: String,
                                window: Int = 14, minDays: Int = 5) -> Baseline? {
        let days = totals.keys.filter { $0 < beforeDay && !outliers.contains($0) }.sorted().suffix(window)
        guard days.count >= minDays else { return nil }
        var sum = Totals()
        for d in days { sum += totals[d] ?? Totals() }
        let n = Double(days.count)
        return Baseline(sat: sum.sat / n, trans: sum.trans / n, chol: sum.chol / n, fiber: sum.fiber / n, days: days.count)
    }

    /// WeeklyCount：自然周（周一至周日）内各限额类别次数，同一餐同一类别计 1 次。
    public static func weeklyCounts(_ entries: [Entry], foods: [String: Food], limits: [CountLimit], day: String) -> [WeeklyCount] {
        let ws = Days.weekStart(day), we = Days.add(ws, 6)
        return limits.map { limit in
            var seen = Set<String>()
            for e in entries where e.day >= ws && e.day <= we && foods[e.foodId]?.category == limit.category {
                seen.insert("\(e.day)|\(e.meal.rawValue)")
            }
            return WeeklyCount(limit: limit, count: seen.count)
        }
    }

    /// SourceRanking：按类别累计饱和脂肪排序。
    public static func sourceRanking(_ entries: [Entry], foods: [String: Food]) -> [SourceShare] {
        var order: [String] = [], by: [String: Double] = [:], total = 0.0
        for e in entries {
            guard let food = foods[e.foodId] else { continue }
            let sat = nutrition(of: e, food: food).sat
            if by[food.category] == nil { order.append(food.category) }
            by[food.category, default: 0] += sat
            total += sat
        }
        return order.map { SourceShare(category: $0, sat: by[$0] ?? 0, share: total != 0 ? (by[$0] ?? 0) / total : 0) }
            .stableSorted { $0.sat > $1.sat }
    }

    /// HeatLevel：按用户自身分布的五分位分档（1–5），无记录为 0。
    public static func heatThresholds(_ values: [Double]) -> [Double] {
        let v = values.filter { $0 > 0 }.sorted()
        guard !v.isEmpty else { return [] }
        return [0.2, 0.4, 0.6, 0.8].map { v[min(v.count - 1, Int(($0 * Double(v.count)).rounded(.down)))] }
    }

    public static func heatLevel(_ value: Double, thresholds: [Double]) -> Int {
        guard value > 0, !thresholds.isEmpty else { return 0 }
        return min(1 + thresholds.filter { value >= $0 }.count, 5)
    }

    // MARK: 记录

    /// 同餐次同食物再次添加时合并份量。
    public static func mergeEntry(_ entries: [Entry], _ e: Entry) -> MergeResult {
        guard let hit = entries.first(where: { $0.day == e.day && $0.meal == e.meal && $0.foodId == e.foodId }) else {
            return MergeResult(merged: false, entry: e, previous: nil)
        }
        let unit = hit.grams / hit.multiplier
        let grams = hit.grams + e.grams
        var merged = hit
        merged.grams = grams
        merged.multiplier = Double(Fmt.round(grams / unit * 100)) / 100
        return MergeResult(merged: true, entry: merged, previous: hit)
    }

    public static func lastServing(_ entries: [Entry], foodId: String) -> ServingChoice? {
        var last: Entry?
        for e in entries where e.foodId == foodId {
            if let l = last, e.createdAt <= l.createdAt { continue }
            last = e
        }
        return last.map { ServingChoice(servingLabel: $0.servingLabel, multiplier: $0.multiplier) }
    }

    /// 按习惯预填：最近 14 个记过该餐的日子里，出现率不低于一半的食物（最多 3 个）。
    public static func prefill(_ entries: [Entry], day: String, meal: Meal, window: Int = 14, minDays: Int = 3, max: Int = 3) -> [Prefill] {
        var byDay: [String: [Entry]] = [:]
        for e in entries where e.meal == meal && e.day < day { byDay[e.day, default: []].append(e) }
        let days = byDay.keys.sorted().suffix(window)
        guard days.count >= minDays else { return [] }
        var order: [String] = [], stat: [String: (count: Int, last: Entry)] = [:]
        for d in days {
            for e in byDay[d] ?? [] {
                if let s = stat[e.foodId] { stat[e.foodId] = (s.count + 1, e) } else { order.append(e.foodId); stat[e.foodId] = (1, e) }
            }
        }
        return order.compactMap { id in stat[id].map { (id, $0) } }
            .filter { Double($0.1.count) / Double(days.count) >= 0.5 }
            .stableSorted { $0.1.count > $1.1.count }
            .prefix(max)
            .map { Prefill(foodId: $0.0, meal: meal, servingLabel: $0.1.last.servingLabel, multiplier: $0.1.last.multiplier, grams: $0.1.last.grams) }
    }

    public static func frequentFoods(_ entries: [Entry], sinceDay: String = "", meal: Meal? = nil) -> [FoodCount] {
        var order: [String] = [], c: [String: Int] = [:]
        for e in entries {
            if e.day < sinceDay { continue }
            if let meal, e.meal != meal { continue }
            if c[e.foodId] == nil { order.append(e.foodId) }
            c[e.foodId, default: 0] += 1
        }
        return order.map { FoodCount(foodId: $0, count: c[$0] ?? 0) }.stableSorted { $0.count > $1.count }
    }

    /// One Touch 推荐：高频的（食物 + 份量 + 餐次）组合。
    public static func oneTouchSuggestions(_ entries: [Entry], existing: [OneTouch], sinceDay: String = "",
                                           minCount: Int = 3, max: Int = 4) -> [OneTouchSuggestion] {
        func key(_ foodId: String, _ label: String, _ mult: Double, _ meal: Meal) -> String { "\(foodId)|\(label)|\(mult)|\(meal.rawValue)" }
        let have = Set(existing.map { key($0.foodId, $0.servingLabel, $0.multiplier, $0.meal) })
        var order: [String] = [], c: [String: OneTouchSuggestion] = [:]
        for e in entries {
            if e.day < sinceDay { continue }
            let k = key(e.foodId, e.servingLabel, e.multiplier, e.meal)
            if have.contains(k) { continue }
            if c[k] == nil {
                order.append(k)
                c[k] = OneTouchSuggestion(foodId: e.foodId, servingLabel: e.servingLabel, multiplier: e.multiplier, meal: e.meal, count: 0)
            }
            c[k]?.count += 1
        }
        return Array(order.compactMap { c[$0] }.filter { $0.count >= minCount }.stableSorted { $0.count > $1.count }.prefix(max))
    }

    // MARK: 化验区间小结

    public static func intervalSummary(_ entries: [Entry], foods: [String: Food], limits: [CountLimit], outliers: Set<String>,
                                       from fromDay: String, to toDay: String) -> IntervalSummary? {
        let inRange = entries.filter { $0.day >= fromDay && $0.day < toDay }
        let totals = totalsByDay(inRange, foods: foods)
        let days = totals.keys.filter { !outliers.contains($0) }
        guard !days.isEmpty else { return nil }
        let satMean = days.reduce(0) { $0 + (totals[$1]?.sat ?? 0) } / Double(days.count)
        let fiberDays = days.filter { (totals[$0]?.fiber ?? 0) >= Budget.fiberG }.count
        var weeks = 0, okWeeks = 0
        var ws = Days.weekStart(fromDay)
        while ws < toDay {
            weeks += 1
            if weeklyCounts(inRange, foods: foods, limits: limits, day: ws).allSatisfy({ !$0.over }) { okWeeks += 1 }
            ws = Days.add(ws, 7)
        }
        return IntervalSummary(recordedDays: days.count, satMean: satMean, fiberShare: Double(fiberDays) / Double(days.count), weeks: weeks, okWeeks: okWeeks)
    }

    // MARK: 导出

    public static func csv(_ entries: [Entry], foods: [String: Food]) -> String {
        func q(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        let head = ["日期", "餐次", "食物", "份量", "倍数", "克数", "饱和脂肪(g,估算)", "反式脂肪(g,估算)", "胆固醇(mg,估算)", "可溶性纤维(g,估算)", "录入方式", "示例数据"]
        let rows = entries.stableSorted { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }.map { e -> String in
            let f = foods[e.foodId]
            let n = f.map { nutrition(of: e, food: $0) } ?? Totals()
            return [e.day, e.meal.label, f?.name ?? e.foodId, e.servingLabel, Fmt.number(e.multiplier), Fmt.number(e.grams),
                    String(format: "%.1f", n.sat), String(format: "%.1f", n.trans), String(Fmt.round(n.chol)), String(format: "%.1f", n.fiber),
                    e.source.rawValue, e.demo ? "是" : "否"].map(q).joined(separator: ",")
        }
        return "\u{feff}" + ([head.map(q).joined(separator: ",")] + rows).joined(separator: "\r\n")
    }
}
