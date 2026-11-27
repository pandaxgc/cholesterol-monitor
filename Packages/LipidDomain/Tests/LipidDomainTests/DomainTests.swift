// web-prototype/test/domain.test.js 的 15 个测试，逐条移植；另加一条与 JS 生成器逐日对照的示例数据测试。
import Foundation
import Testing
@testable import LipidDomain

private let foods = FoodLibrary.foodMap()
private let categories = FoodLibrary.categoryById

private final class Seq: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
}

private let seq = Seq()

private func E(_ day: String, _ meal: Meal, _ foodId: String, _ servingLabel: String, _ multiplier: Double = 1) -> Entry {
    let n = seq.next()
    let grams = foods[foodId]!.serving(servingLabel)!.grams * multiplier
    return Entry(id: "e\(n)", day: day, meal: meal, foodId: foodId, servingLabel: servingLabel, multiplier: multiplier, grams: grams,
                 source: .search, createdAt: Date(timeIntervalSince1970: Double(n)))
}

private func adviseDay(_ entries: [Entry], weekly: [WeeklyCount] = [], isOutlier: Bool = false, recentKeys: Set<String> = []) -> Advice? {
    Advisor.advise(spend: Ledger.dailySpend(entries, foods: foods), mode: .standard, weekly: weekly, isOutlier: isOutlier,
                   recentKeys: recentKeys, foods: foods, categories: categories, boosters: FoodLibrary.fiberBoosters)
}

private func totals(_ sat: Double) -> Totals { Totals(sat: sat) }

@Test("显示精度：取整与口语化") func displayPrecision() {
    #expect(Fmt.sat(12.4) == "约 12 g")
    #expect(Fmt.chol(86) == "约 90 mg")
    #expect(Fmt.fiber(2.6) == "约 3 g")
    #expect(Fmt.transLabel(0) == "不含反式脂肪")
    #expect(Fmt.transLabel(0.2) == "含反式脂肪")
    #expect(Fmt.roundPct5(0.37) == 35)
    #expect(Fmt.shareWords(0.52) == "一半")
    #expect(Fmt.shareWords(0.31) == "三成")
    #expect(Fmt.shareWords(0.97) == "几乎全部")
    #expect(Fmt.diffWords(14, base: 20) == "比你平时少三成")
    #expect(Fmt.diffWords(20.5, base: 20) == "和你平时差不多")
    #expect(Fmt.diffWords(10, base: 0) == nil)
}

@Test("食物分级") func grading() {
    #expect(Nutrition(satFatG: 1.9, transFatG: 0, cholesterolMg: 50).grade == .a)
    #expect(Nutrition(satFatG: 2, transFatG: 0, cholesterolMg: 50).grade == .b)
    #expect(Nutrition(satFatG: 5, transFatG: 0, cholesterolMg: 0).grade == .c)
    #expect(Nutrition(satFatG: 0.5, transFatG: 0.2, cholesterolMg: 0).grade == .c)
    #expect(Nutrition(satFatG: 0.5, transFatG: 0, cholesterolMg: 100).grade == .c)
}

@Test("日期：04:00 前归属前一天；自然周从周一开始") func dates() {
    let cal = Calendar.current
    let before = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 3, minute: 59))!
    let after = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 4, minute: 0))!
    #expect(Days.logicalDay(before) == "2026-11-13")
    #expect(Days.logicalDay(after) == "2026-11-14")
    #expect(Days.weekStart("2026-11-13") == "2026-11-09")
    #expect(Days.weekStart("2026-11-15") == "2026-11-09")
    #expect(Days.add("2026-03-01", -1) == "2026-02-28")
    #expect(Days.label("2026-11-03") == "11月3日")
}

@Test("DailySpend 与 Balance（PRD §5.1 的示意日）") func dailySpendAndBalance() {
    let day = "2026-11-13"
    let s = Ledger.dailySpend([E(day, .breakfast, "boiled_egg", "个"), E(day, .breakfast, "oat_porridge", "中碗"),
                               E(day, .lunch, "braised_pork", "中碗"), E(day, .lunch, "rice", "中碗")], foods: foods)
    #expect(Fmt.round(s.total.sat) == 15)
    #expect(Fmt.sat(s.meal(.lunch).sat) == "约 13 g")
    #expect(Fmt.sat(Ledger.balance(.standard, sat: s.total.sat)) == "约 7 g")
    #expect(Ledger.balance(.strict, sat: s.total.sat) < 0)
}

@Test("Baseline：排除离群日，不足 5 天不给相对语言") func baseline() {
    var t: [String: Totals] = [:]
    for i in 1...4 { t[Days.add("2026-11-13", -i)] = totals(20) }
    #expect(Ledger.baseline(t, outliers: [], beforeDay: "2026-11-13") == nil)
    t["2026-11-08"] = totals(20)
    t["2026-11-07"] = totals(80)
    #expect(Ledger.baseline(t, outliers: ["2026-11-07"], beforeDay: "2026-11-13")?.sat == 20)
    #expect(Ledger.baseline(t, outliers: [], beforeDay: "2026-11-13")?.sat == 30)
    t["2026-11-13"] = totals(99)
    #expect(Ledger.baseline(t, outliers: ["2026-11-07"], beforeDay: "2026-11-13")?.sat == 20, "当天不计入")
}

@Test("WeeklyCount：同一餐同一类别计 1 次，跨周不计") func weeklyCount() {
    let entries = [
        E("2026-11-10", .lunch, "braised_pork", "中碗"), E("2026-11-10", .lunch, "chinese_sausage", "片"),
        E("2026-11-10", .dinner, "bacon", "片"), E("2026-11-08", .lunch, "braised_pork", "中碗"),
    ]
    let w = Ledger.weeklyCounts(entries, foods: foods, limits: FoodLibrary.defaultLimits, day: "2026-11-13")
    let meat = w.first { $0.limit.category == "fatty_processed_meat" }!
    #expect(meat.count == 2)
    #expect(meat.reached == true)
    #expect(meat.over == false)
    #expect(w.first { $0.limit.category == "fried" }?.count == 0)
}

@Test("SourceRanking 与 HeatLevel") func sourceRankingAndHeat() {
    let r = Ledger.sourceRanking([E("2026-11-10", .lunch, "braised_pork", "中碗"), E("2026-11-10", .lunch, "rice", "中碗")], foods: foods)
    #expect(r[0].category == "fatty_processed_meat")
    #expect(r[0].share > 0.95)
    let th = Ledger.heatThresholds([1, 2, 3, 4, 5])
    #expect([0, 1, 2, 3, 4, 5, 50].map { Ledger.heatLevel($0, thresholds: th) } == [0, 1, 2, 3, 4, 5, 5])
    #expect(Ledger.heatLevel(3, thresholds: []) == 0)
}

@Test("重复添加合并份量") func merge() {
    let a = E("2026-11-13", .lunch, "rice", "中碗")
    let m = Ledger.mergeEntry([a], E("2026-11-13", .lunch, "rice", "小碗"))
    #expect(m.merged == true)
    #expect(m.entry.id == a.id)
    #expect(m.entry.grams == 250)
    #expect(m.entry.multiplier == 1.67)
    #expect(Ledger.mergeEntry([a], E("2026-11-13", .dinner, "rice", "小碗")).merged == false)
}

@Test("按习惯预填与 One Touch 推荐") func prefillAndSuggestions() {
    var entries: [Entry] = []
    for i in 1...6 {
        let d = Days.add("2026-11-13", -i)
        entries.append(E(d, .breakfast, "boiled_egg", "个"))
        if i % 3 == 0 { entries.append(E(d, .breakfast, "youtiao", "根")) }
    }
    #expect(Ledger.prefill(entries, day: "2026-11-13", meal: .breakfast).map(\.foodId) == ["boiled_egg"])
    #expect(Ledger.prefill(entries, day: "2026-11-13", meal: .dinner).isEmpty)
    #expect(Ledger.oneTouchSuggestions(entries, existing: []).first?.foodId == "boiled_egg")
    let have = [OneTouch(id: "x", foodId: "boiled_egg", servingLabel: "个", multiplier: 1, meal: .breakfast, sortOrder: 0)]
    #expect(Ledger.oneTouchSuggestions(entries, existing: have).isEmpty)
}

@Test("建议引擎：优先级自上而下") func advisePriorities() {
    let d = "2026-11-13"
    #expect(adviseDay([]) == nil)
    #expect(adviseDay([E(d, .lunch, "youtiao", "根")], isOutlier: true) == nil)

    let p0 = adviseDay([E(d, .breakfast, "youtiao", "根"), E(d, .lunch, "braised_pork", "大碗", 2)])
    #expect(p0?.key == "P0:youtiao")
    #expect(p0?.text.contains("含反式脂肪") == true)
    #expect(p0?.text.contains("换成馒头") == true)

    let p1 = adviseDay([E(d, .lunch, "braised_pork", "大碗", 1.5), E(d, .dinner, "rice", "中碗")])
    #expect(p1?.key == "P1:braised_pork")
    #expect(p1?.text == "红烧肉约占今天饱和脂肪的几乎全部（约 28 g）。换成清蒸鱼，预计可省约 26 g。")

    let weekly = [WeeklyCount(limit: CountLimit(id: "l", category: "offal", maxCount: 1), count: 1)]
    let fiberOk = [E(d, .breakfast, "oats", "一份", 4)]
    #expect(adviseDay(fiberOk, weekly: weekly)?.key == "P2:offal")

    #expect(adviseDay([E(d, .lunch, "rice", "中碗")])?.key == "P3:oat_porridge")

    let p4 = adviseDay(fiberOk + [E(d, .breakfast, "boiled_egg", "个", 2)])
    #expect(p4?.key == "P4:boiled_egg")
    #expect(p4?.text == "今天胆固醇约 370 mg，主要来自水煮蛋，明天减半就在预算内。")

    #expect(adviseDay(fiberOk)?.key == "P5")
}

@Test("建议引擎：7 天内不重复，顺延；全部重复时不谎报") func adviseNoRepeat() {
    let d = "2026-11-13"
    let lowFiber = [E(d, .lunch, "rice", "中碗")]
    #expect(adviseDay(lowFiber, recentKeys: ["P3:oat_porridge"])?.key == "P3:red_beans")
    #expect(adviseDay(lowFiber, recentKeys: ["P3:oat_porridge", "P3:red_beans", "P3:apple"])?.key == "P3:oat_porridge")
    let over = [E(d, .lunch, "braised_pork", "大碗", 1.5), E(d, .breakfast, "oats", "一份", 4)]
    #expect(adviseDay(over, recentKeys: ["P1:braised_pork"])?.key == "P1:braised_pork")
}

@Test("建议措辞不含命令或指责") func adviseWording() {
    let d = "2026-11-13"
    for f in FoodLibrary.foods {
        let a = adviseDay([E(d, .lunch, f.id, f.servings[0].label, 3)])
        #expect(a != nil)
        for word in ["你应该", "你违反", "必须", "不许"] { #expect(a?.text.contains(word) == false) }
    }
}

@Test("化验区间小结") func intervalSummary() {
    let entries = [E("2026-11-02", .lunch, "braised_pork", "中碗"), E("2026-11-03", .lunch, "rice", "中碗"), E("2026-11-03", .dinner, "oats", "一份", 7)]
    let s = Ledger.intervalSummary(entries, foods: foods, limits: FoodLibrary.defaultLimits, outliers: [], from: "2026-11-02", to: "2026-11-09")
    #expect(s?.recordedDays == 2)
    #expect(s?.fiberShare == 0.5)
    #expect(s?.weeks == 1)
    #expect(s?.okWeeks == 1)
    #expect(Ledger.intervalSummary([], foods: foods, limits: FoodLibrary.defaultLimits, outliers: [], from: "2026-11-02", to: "2026-11-09") == nil)
}

@Test("CSV 导出") func csvExport() {
    let csv = Ledger.csv([E("2026-11-13", .lunch, "braised_pork", "中碗")], foods: foods)
    let lines = csv.replacingOccurrences(of: "\u{feff}", with: "").components(separatedBy: "\r\n")
    #expect(lines.count == 2)
    #expect(lines[1].hasPrefix("\"2026-11-13\",\"午餐\",\"红烧肉\",\"中碗\",\"1\",\"100\",\"12.4\""))
}

@Test("示例数据：确定性、带 demo 标记、当天只有早午餐") func demoData() {
    let a = Demo.day("2026-10-01", foods: foods), b = Demo.day("2026-10-01", foods: foods)
    #expect(a.entries == b.entries)
    #expect(a.outlier == b.outlier)
    #expect(a.entries.allSatisfy { $0.demo && foods[$0.foodId] != nil })
    let today = Demo.day("2026-11-13", foods: foods, mode: .partial)
    #expect(Set(today.entries.map(\.meal)) == [.breakfast, .lunch])
    #expect(today.outlier == false)
    let rest = Demo.day("2026-11-13", foods: foods, mode: .rest)
    #expect(rest.entries.allSatisfy { $0.meal == .dinner || $0.meal == .snack })
}

@Test("食物库：106 条，量具与替代映射完整") func foodLibrary() {
    #expect(FoodLibrary.foods.count == 106)
    #expect(Set(FoodLibrary.foods.map(\.id)).count == 106)
    for f in FoodLibrary.foods {
        #expect(categories[f.category] != nil)
        #expect(f.servings.indices.contains(f.defaultServing))
        #expect(f.source == "估算值（未核实）")
        if case .food(let id) = f.swap { #expect(foods[id] != nil) }
    }
    for c in FoodLibrary.categories { if let s = c.swap { #expect(foods[s] != nil) } }
}

@Test("示例数据与网页原型的生成器逐日一致（120 天）") func demoMatchesWebPrototype() throws {
    let url = try #require(Bundle.module.url(forResource: "demo-golden", withExtension: "txt", subdirectory: "Fixtures"))
    let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    #expect(lines.count == 120)
    for line in lines {
        let p = line.split(separator: "|", omittingEmptySubsequences: false)
        let r = Demo.day(String(p[0]), foods: foods)
        let got = r.entries.map { "\($0.meal.rawValue):\($0.foodId):\($0.servingLabel):\(Fmt.number($0.multiplier)):\(Fmt.number($0.grams))" }.joined(separator: ",")
        #expect(got == String(p[2]), "\(p[0])")
        #expect(r.outlier == (p[1] == "1"), "\(p[0])")
    }
}
