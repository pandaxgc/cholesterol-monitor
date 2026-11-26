// 应用状态：SwiftData 中数据的内存快照、派生量，以及所有写操作。
import Foundation
import LipidDomain
import Observation
import SwiftData

enum AppTab: Hashable {
    case today, lists, analysis, labs
}

struct DayContext {
    var day: String
    var dayEntries: [Entry]
    var spend: DailySpend
    var mode: BudgetMode
    var budget: Double
    var weekly: [WeeklyCount]
    var base: Baseline?
    var isOutlier: Bool
    var advice: Advice?
    /// 三餐都记了
    var complete: Bool
}

struct AddResult {
    var merged: Bool
    var entry: Entry
    var undo: @MainActor () -> Void
}

enum OneTouchResult {
    case ok, exists, full

    var text: String {
        switch self {
        case .ok: "已存为 One Touch"
        case .exists: "已经有相同的 One Touch"
        case .full: "One Touch 已满 \(maxOneTouch) 个，先在设置里删掉一个"
        }
    }
}

enum ResetMode {
    case blank, demo
}

@MainActor @Observable final class AppStore {
    private(set) var entries: [Entry] = []
    private(set) var oneTouch: [OneTouch] = []
    private(set) var limits: [CountLimit] = []
    private(set) var outliers: Set<String> = []
    private(set) var labs: [LabResult] = []
    private(set) var adviceLog: [AdviceLog] = []
    private(set) var settings = AppSettings()
    private(set) var foods: [String: Food] = FoodLibrary.foodMap()
    /// 写入失败时给界面的提示
    var lastError: String?

    private(set) var today = Days.logicalDay()
    private(set) var now = Date()
    /// 今日页正在看的那一天
    var day = Days.logicalDay()
    var tab: AppTab = .today

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let entryTable: Table<EntryRecord>
    @ObservationIgnored private let oneTouchTable: Table<OneTouchRecord>
    @ObservationIgnored private let limitTable: Table<LimitRecord>
    @ObservationIgnored private let dayMetaTable: Table<DayMetaRecord>
    @ObservationIgnored private let labTable: Table<LabRecord>
    @ObservationIgnored private let adviceTable: Table<AdviceLogRecord>
    @ObservationIgnored private let settingsTable: Table<SettingsRecord>

    let categories = FoodLibrary.categoryById

    init(container: ModelContainer) {
        context = container.mainContext
        entryTable = Table(context)
        oneTouchTable = Table(context)
        limitTable = Table(context)
        dayMetaTable = Table(context)
        labTable = Table(context)
        adviceTable = Table(context)
        settingsTable = Table(context)
        if settingsTable.get(SettingsRecord.mainKey) == nil {
            // 首次启动：空白数据 + 4 条默认限额
            settingsTable.put(AppSettings())
            for (i, l) in FoodLibrary.defaultLimits.enumerated() { limitTable.put(StoredLimit(limit: l, sortOrder: i)) }
        }
        commit()
        syncDemo()
    }

    // MARK: 快照

    private func commit() {
        do { try context.save() } catch { lastError = "保存失败：\(error.localizedDescription)" }
        entries = entryTable.values.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        oneTouch = oneTouchTable.values.sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
        limits = limitTable.values.sorted { $0.sortOrder < $1.sortOrder }.map(\.limit)
        outliers = Set(dayMetaTable.values.filter(\.isOutlier).map(\.day))
        labs = labTable.values.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
        adviceLog = adviceTable.values
        let s = settingsTable.get(SettingsRecord.mainKey) ?? AppSettings()
        if s.servingOverrides != settings.servingOverrides { foods = FoodLibrary.foodMap(overrides: s.servingOverrides) }
        settings = s
    }

    private func uid(_ prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(14).lowercased())"
    }

    /// 回到前台或每分钟调用：跨过 04:00 时更新“今天”，示例数据补齐到今天。
    func tick() {
        now = Date()
        let was = today
        let t = Days.logicalDay(now)
        guard t != was else { return }
        today = t
        if day == was || day > t { day = t }
        syncDemo()
    }

    func setDay(_ d: String) { day = d > today ? today : d }

    // MARK: 派生

    func entries(on day: String) -> [Entry] { entries.filter { $0.day == day } }

    func dayContext(_ day: String) -> DayContext {
        let dayEntries = entries(on: day)
        let spend = Ledger.dailySpend(dayEntries, foods: foods)
        let mode = settings.budgetMode
        let weekly = Ledger.weeklyCounts(entries, foods: foods, limits: limits, day: day)
        let base = Ledger.baseline(Ledger.totalsByDay(entries, foods: foods), outliers: outliers, beforeDay: day)
        let from = Days.add(day, -7)
        let recentKeys = Set(adviceLog.filter { $0.day < day && $0.day >= from }.map(\.key))
        let isOutlier = outliers.contains(day)
        let advice = Advisor.advise(spend: spend, mode: mode, weekly: weekly, isOutlier: isOutlier, recentKeys: recentKeys,
                                    foods: foods, categories: categories, boosters: FoodLibrary.fiberBoosters)
        let complete = Meal.main.allSatisfy { m in dayEntries.contains { $0.meal == m } }
        return DayContext(day: day, dayEntries: dayEntries, spend: spend, mode: mode, budget: Budget.sat(mode), weekly: weekly,
                          base: base, isOutlier: isOutlier, advice: advice, complete: complete)
    }

    /// 类别按使用量排序。
    var categoriesByUse: [FoodCategory] {
        var use: [String: Int] = [:]
        for e in entries { if let c = foods[e.foodId]?.category { use[c, default: 0] += 1 } }
        return FoodLibrary.categories.enumerated().sorted { a, b in
            let ua = use[a.element.id] ?? 0, ub = use[b.element.id] ?? 0
            return ua != ub ? ua > ub : a.offset < b.offset
        }.map(\.element)
    }

    func foods(in category: String) -> [Food] { FoodLibrary.foods.compactMap { $0.category == category ? foods[$0.id] : nil } }

    func matchFoods(_ query: String) -> [Food] {
        let k = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return [] }
        return FoodLibrary.foods.compactMap { foods[$0.id] }
            .filter { f in f.name.lowercased().contains(k) || f.aliases.contains { $0.lowercased().contains(k) } }
    }

    // MARK: 记录

    @discardableResult
    func addEntry(day: String, meal: Meal, food: Food, servingLabel: String, multiplier: Double, source: EntrySource) -> AddResult {
        let serving = food.serving(servingLabel) ?? food.defaultServingValue
        let e = Entry(id: uid("entry"), day: day, meal: meal, foodId: food.id, servingLabel: serving.label, multiplier: multiplier,
                      grams: serving.grams * multiplier, source: source, createdAt: Date())
        let m = Ledger.mergeEntry(entries, e)
        entryTable.put(m.entry)
        commit()
        return AddResult(merged: m.merged, entry: m.entry) { [weak self] in
            guard let self else { return }
            if let previous = m.previous { entryTable.put(previous) } else { entryTable.delete(e.id) }
            commit()
        }
    }

    func updateEntry(_ entry: Entry, meal: Meal, servingLabel: String, multiplier: Double, food: Food) {
        let serving = food.serving(servingLabel) ?? food.defaultServingValue
        var next = entry
        next.meal = meal
        next.servingLabel = serving.label
        next.multiplier = multiplier
        next.grams = serving.grams * multiplier
        let m = Ledger.mergeEntry(entries.filter { $0.id != entry.id }, next)
        if m.merged { entryTable.delete(entry.id) }
        entryTable.put(m.entry)
        commit()
    }

    /// 返回撤销操作。
    func deleteEntry(_ entry: Entry) -> @MainActor () -> Void {
        entryTable.delete(entry.id)
        commit()
        return { [weak self] in
            self?.entryTable.put(entry)
            self?.commit()
        }
    }

    @discardableResult
    func toggleOutlier(_ day: String) -> Bool {
        let on = !outliers.contains(day)
        dayMetaTable.put(DayMeta(day: day, isOutlier: on))
        commit()
        return on
    }

    func saveAdvice(day: String, key: String?) {
        if adviceTable.get(day)?.key == key { return }
        if let key { adviceTable.put(AdviceLog(day: day, key: key)) } else { adviceTable.delete(day) }
        commit()
    }

    // MARK: One Touch

    @discardableResult
    func addOneTouch(foodId: String, servingLabel: String, multiplier: Double, meal: Meal) -> OneTouchResult {
        if oneTouch.contains(where: { $0.foodId == foodId && $0.servingLabel == servingLabel && $0.multiplier == multiplier && $0.meal == meal }) { return .exists }
        if oneTouch.count >= maxOneTouch { return .full }
        let order = (oneTouch.map(\.sortOrder).max() ?? -1) + 1
        oneTouchTable.put(OneTouch(id: uid("ot"), foodId: foodId, servingLabel: servingLabel, multiplier: multiplier, meal: meal, sortOrder: order))
        commit()
        return .ok
    }

    func removeOneTouch(_ id: String) {
        oneTouchTable.delete(id)
        commit()
    }

    func moveOneTouchUp(_ id: String) {
        guard let i = oneTouch.firstIndex(where: { $0.id == id }), i > 0 else { return }
        var a = oneTouch[i - 1], b = oneTouch[i]
        swap(&a.sortOrder, &b.sortOrder)
        oneTouchTable.put(a)
        oneTouchTable.put(b)
        commit()
    }

    // MARK: 限额、化验、设置

    func addLimit(category: String) {
        let order = (limitTable.values.map(\.sortOrder).max() ?? -1) + 1
        limitTable.put(StoredLimit(limit: CountLimit(id: uid("limit"), category: category, maxCount: 1), sortOrder: order))
        commit()
    }

    func setLimit(_ id: String, maxCount: Int) {
        guard var l = limitTable.get(id) else { return }
        l.limit.maxCount = max(0, min(14, maxCount))
        limitTable.put(l)
        commit()
    }

    func removeLimit(_ id: String) {
        limitTable.delete(id)
        commit()
    }

    func saveLab(_ lab: LabResult) {
        var l = lab
        if l.id.isEmpty { l.id = uid("lab") }
        l.demo = false
        labTable.put(l)
        commit()
    }

    func removeLab(_ id: String) {
        labTable.delete(id)
        commit()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        settingsTable.put(s)
        commit()
    }

    /// 克数为 0 表示恢复默认。
    func setServingOverride(foodId: String, label: String, grams: Double) {
        updateSettings { s in
            var one = s.servingOverrides[foodId] ?? [:]
            if grams > 0 { one[label] = grams } else { one[label] = nil }
            s.servingOverrides[foodId] = one.isEmpty ? nil : one
        }
    }

    func baseServingGrams(foodId: String, label: String) -> Double? {
        FoodLibrary.foods.first { $0.id == foodId }?.serving(label)?.grams
    }

    // MARK: 示例数据

    func reset(_ mode: ResetMode) {
        entryTable.clear()
        oneTouchTable.clear()
        dayMetaTable.clear()
        labTable.clear()
        adviceTable.clear()
        limitTable.clear()
        for (i, l) in FoodLibrary.defaultLimits.enumerated() { limitTable.put(StoredLimit(limit: l, sortOrder: i)) }
        var s = settings
        s.demo = mode == .demo
        s.demoAnchor = nil
        s.servingOverrides = [:]
        settingsTable.put(s)
        commit()
        day = today
        syncDemo()
    }

    /// 示例数据：首次生成 90 天；之后每次打开把缺的日子补齐，已有记录的日子不动。
    private func syncDemo() {
        guard settings.demo, settings.demoAnchor != today else { return }
        let base = FoodLibrary.foodMap()
        var have: [String: Set<Meal>] = [:]
        for e in entries { have[e.day, default: []].insert(e.meal) }
        func write(_ day: String, _ mode: Demo.Mode) {
            let r = Demo.day(day, foods: base, mode: mode)
            r.entries.forEach(entryTable.put)
            if r.outlier { dayMetaTable.put(DayMeta(day: day, isOutlier: true, demo: true)) }
        }
        if let anchor = settings.demoAnchor {
            if anchor < today {
                var d = max(Days.add(today, -Demo.days), anchor)
                while d < today {
                    if let meals = have[d] {
                        if d == anchor, !meals.contains(.dinner) { write(d, .rest) }
                    } else {
                        write(d, .full)
                    }
                    d = Days.add(d, 1)
                }
            }
        } else {
            for i in stride(from: Demo.days, through: 1, by: -1) { write(Days.add(today, -i), .full) }
            Demo.labs(today: today).forEach(labTable.put)
            Demo.oneTouch.forEach(oneTouchTable.put)
        }
        if have[today] == nil { write(today, .partial) }
        var s = settings
        s.demoAnchor = today
        settingsTable.put(s)
        commit()
    }

    // MARK: 导出

    func exportCSV() -> Data { Data(Ledger.csv(entries, foods: foods).utf8) }

    func exportJSON() -> Data {
        struct Backup: Encodable {
            var exportedAt: Date
            var note: String
            var entries: [Entry]
            var oneTouch: [OneTouch]
            var limits: [CountLimit]
            var dayMeta: [DayMeta]
            var labs: [LabResult]
            var adviceLog: [AdviceLog]
            var settings: AppSettings
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let backup = Backup(exportedAt: Date(), note: "营养数值为估算值", entries: entries, oneTouch: oneTouch, limits: limits,
                            dayMeta: dayMetaTable.values.sorted { $0.day < $1.day }, labs: labs,
                            adviceLog: adviceLog.sorted { $0.day < $1.day }, settings: settings)
        return (try? enc.encode(backup)) ?? Data()
    }
}
