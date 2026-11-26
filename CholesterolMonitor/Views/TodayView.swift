// 今日：预算余额 + 今日流水（PRD §5.1）
import LipidDomain
import SwiftUI

let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

func dayTitle(_ day: String) -> String { "\(Days.label(day)) \(weekdays[Days.weekday(day)])" }

func entryAccessibilityLabel(food: Food, serving: String, sat: Double) -> String {
    "\(food.name)，\(serving)，饱和脂肪约 \(Fmt.round(sat)) 克，\(food.grade.label)。"
}

/// 今天还没记的第一个正餐，都记了则为加餐。
@MainActor func defaultMeal(_ store: AppStore) -> Meal {
    let have = Set(store.entries(on: store.day).map(\.meal))
    return Meal.main.first { !have.contains($0) } ?? .snack
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Prefs.self) private var prefs

    var body: some View {
        let c = store.dayContext(store.day)
        let isToday = store.day == store.today
        let meals = Meal.main + (c.dayEntries.contains { $0.meal == .snack } ? [.snack] : [])
        NavigationStack {
            Page(bottomInset: 150) {
                if isToday, Calendar.current.component(.hour, from: store.now) < 4 {
                    Text("现在是凌晨，记在 \(Days.label(store.day))")
                        .font(.footnote).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity).padding(.top, 4)
                }
                DemoBanner()
                BalanceBlock(c: c)
                SummaryStats(c: c)
                LimitsCard(c: c)
                ForEach(meals) { MealGroup(c: c, meal: $0) }
                if c.complete { DoneLine(day: c.day) }
                AdviceGroup(c: c)
            }
            .overlay(alignment: prefs.hand == .left ? .bottomLeading : .bottomTrailing) { FabGroup() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.sheet = .settings } label: { Image(systemName: "person") }
                        .accessibilityLabel("设置")
                        .accessibilityIdentifier("open-settings")
                }
                ToolbarItem(placement: .principal) {
                    Button { router.sheet = .dayMenu } label: {
                        HStack(spacing: 6) {
                            Text(isToday ? "今日" : dayTitle(store.day)).font(.body.weight(.semibold)).monospacedDigit()
                            if c.isOutlier { TagLabel("离群日") }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Theme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(Theme.fillStrong, in: Circle())
                        }
                        .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel("\(isToday ? "今日，" : "")\(dayTitle(store.day))\(c.isOutlier ? "，离群日" : "")。日期与离群日")
                    .accessibilityIdentifier("day-menu")
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { store.setDay(Days.add(store.day, -1)) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("前一天")
                        .accessibilityIdentifier("prev-day")
                    Button { store.setDay(Days.add(store.day, 1)) } label: { Image(systemName: "chevron.right") }
                        .disabled(isToday)
                        .accessibilityLabel("后一天")
                        .accessibilityIdentifier("next-day")
                }
            }
        }
        .task(id: "\(store.day)|\(store.today)|\(c.advice?.key ?? "-")") {
            if store.day == store.today { store.saveAdvice(day: store.day, key: c.advice?.key) }
        }
    }
}

// MARK: 余额

private struct BalanceBlock: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let c: DayContext

    var body: some View {
        let used = Fmt.round(c.spend.total.sat)
        let budget = Int(c.budget)
        let bal = budget - used
        let over = bal < 0
        Button { router.sheet = .sources } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("饱和脂肪余额" + (c.mode == .strict ? " · 严格模式" : ""))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(over ? "已超出约" : "约").font(.title3.weight(.semibold))
                    Text("\(abs(bal))")
                        .font(Theme.display)
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(bal)))
                        .accessibilityIdentifier("balance-number")
                    Text("g").font(.title2.weight(.semibold))
                }
                .foregroundStyle(over ? Theme.warn : Theme.accent)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.45), value: bal)
                HStack(spacing: 12) {
                    ProgressBar(ratio: c.budget > 0 ? Double(used) / c.budget : 0, over: over)
                    Amount("\(used) / \(budget) g", font: .subheadline)
                }
                Text(relativeLine)
                    .font(.footnote)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("饱和脂肪余额，\(over ? "已超出约 \(-bal) 克" : "约 \(bal) 克")。已用约 \(used) 克，预算 \(budget) 克。\(relativeLine)")
        .accessibilityHint("点按查看来源明细")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("balance")
    }

    private var relativeLine: String {
        if c.isOutlier { return "今天是离群日，不计入日常水位" }
        guard let base = c.base else { return "记满 5 个非离群日后，会和你的日常水位比较" }
        if c.complete, let w = Fmt.diffWords(c.spend.total.sat, base: base.sat) { return "今天的饱和脂肪\(w)" }
        return "三餐记完后，会和你的日常水位比较"
    }
}

struct ProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var ratio: Double
    var over = false
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fill)
                Capsule().fill(over ? Theme.warn : Theme.accent)
                    .frame(width: g.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: ratio)
        .accessibilityHidden(true)
    }
}

// MARK: 统计格

private struct SummaryStats: View {
    let c: DayContext

    var body: some View {
        let t = c.spend.total
        let transFoods = c.spend.items.filter { $0.food.nutritionPer100g.transFatG > 0 }.map(\.food.name).uniqued()
        let cholOver = t.chol > Budget.cholMg
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 12) {
            Stat(label: "膳食胆固醇", value: "\(Fmt.chol(t.chol).replacingOccurrences(of: " mg", with: "")) / \(Int(Budget.cholMg)) mg", warn: cholOver, note: cholOver ? "超出" : nil)
            Stat(label: "可溶性纤维", value: "\(Fmt.fiber(t.fiber).replacingOccurrences(of: " g", with: "")) / \(Int(Budget.fiberG)) g")
            Stat(label: "反式脂肪", value: transFoods.isEmpty ? "不含" : "含", warn: !transFoods.isEmpty, note: transFoods.isEmpty ? nil : transFoods.joined(separator: "、"))
            Stat(label: "你的日常水位", value: c.base.map { "每天\(Fmt.sat($0.sat))" } ?? "—", note: c.base == nil ? "记满 5 天后显示" : nil)
        }
        .padding(.horizontal, Theme.gutter + 2)
        .padding(.top, 16)
    }
}

private struct Stat: View {
    var label: String
    var value: String
    var warn = false
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.footnote).foregroundStyle(Theme.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(amountText(value, font: .title3, number: warn ? Theme.warnText : .primary, weight: .bold, unitFont: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let note {
                    Text(note).font(.footnote).foregroundStyle(warn ? Theme.warnText : Theme.textMuted).lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: 本周限额

private struct LimitsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let c: DayContext

    var body: some View {
        let overCount = c.weekly.filter(\.over).count
        CardGroup(separatorInset: Theme.cellX + 42) {
            RowButton { router.sheet = .limits } label: {
                LedgerRow(title: "本周限额", subAttributed: c.weekly.isEmpty ? nil : limitList,
                          value: c.weekly.isEmpty ? "未设置" : overCount > 0 ? "\(overCount) 项超出" : nil,
                          valueWarn: overCount > 0, chevron: true) { IconTile(symbol: "gauge.with.needle") }
            }
            .accessibilityIdentifier("weekly-limits")
        }
    }

    private var limitList: AttributedString {
        var out = AttributedString()
        for (i, w) in c.weekly.enumerated() {
            let name = store.categories[w.limit.category]?.short ?? w.limit.category
            var a = AttributedString((i > 0 ? "   " : "") + "\(name)\u{00A0}\(w.count)/\(w.limit.maxCount)")
            a.foregroundColor = w.over ? Theme.warnText : Theme.textMuted
            a.font = .footnote.monospacedDigit()
            out += a
        }
        return out
    }
}

// MARK: 餐次

struct EntryRowView: View {
    @Environment(Prefs.self) private var prefs
    let item: SpendItem

    var body: some View {
        LedgerRow(title: item.food.name, detail: Fmt.servingText(item.entry), grade: item.food.grade == .a ? nil : item.food.grade,
                  value: Fmt.sat(item.n.sat)) { EmojiIcon(item.food.emoji) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entryAccessibilityLabel(food: item.food, serving: Fmt.servingText(item.entry), sat: item.n.sat))
    }
}

private struct MealGroup: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Prefs.self) private var prefs
    let c: DayContext
    let meal: Meal

    var body: some View {
        let items = c.spend.items.filter { $0.entry.meal == meal }
        // 预填条目在该餐只有预填确认的记录时继续显示，方便逐条确认
        let canPrefill = c.day == store.today && !c.isOutlier && items.allSatisfy { $0.entry.source == .prefill }
        let have = Set(items.map(\.food.id))
        let pre = canPrefill ? Ledger.prefill(store.entries, day: c.day, meal: meal).filter { !have.contains($0.foodId) && store.foods[$0.foodId] != nil } : []
        CardGroup(title: meal.label, right: items.isEmpty ? nil : Fmt.sat(c.spend.meal(meal).sat), headline: true,
                  separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
            ForEach(items) { item in
                RowButton { router.sheet = .entryMenu(item.entry) } label: { EntryRowView(item: item) }
                    .contextMenu { EntryContextMenu(item: item) }
                    .accessibilityIdentifier("entry-\(meal.rawValue)-\(item.food.id)")
            }
            ForEach(pre) { p in
                let food = store.foods[p.foodId]!
                RowButton {
                    let r = store.addEntry(day: c.day, meal: meal, food: food, servingLabel: p.servingLabel, multiplier: p.multiplier, source: .prefill)
                    Haptics.light()
                    ToastCenter.shared.show("已记入\(meal.label)：\(food.name)", undo: r.undo)
                } label: {
                    LedgerRow(title: food.name, detail: Fmt.servingText(p), sub: "按习惯预填 · 点一下确认",
                              value: Fmt.sat(Ledger.nutrition(grams: (food.serving(p.servingLabel) ?? food.defaultServingValue).grams * p.multiplier, food: food).sat), style: .prefill) { EmojiIcon(food.emoji) }
                }
                .accessibilityLabel("按习惯预填：\(food.name)，\(Fmt.servingText(p))。点按确认入账")
                .accessibilityIdentifier("prefill-\(meal.rawValue)-\(food.id)")
            }
            if items.isEmpty {
                RowButton { router.sheet = .add(meal: meal, focusSearch: false) } label: {
                    LedgerRow(title: pre.isEmpty ? "还没记，点这里补上" : "记别的", chevron: true, style: .guide)
                }
                .accessibilityIdentifier("guide-\(meal.rawValue)")
            }
        }
    }
}

private struct EntryContextMenu: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    let item: SpendItem

    var body: some View {
        Button { router.sheet = .keypad(KeypadRequest(food: item.food, meal: item.entry.meal, entry: item.entry)) } label: { Label("编辑份量", systemImage: "pencil") }
        Button {
            let e = item.entry
            ToastCenter.shared.show(store.addOneTouch(foodId: e.foodId, servingLabel: e.servingLabel, multiplier: e.multiplier, meal: e.meal).text)
        } label: { Label("存为 One Touch", systemImage: "bolt") }
        Button(role: .destructive) {
            let undo = store.deleteEntry(item.entry)
            ToastCenter.shared.show("已删除\(item.food.name)", undo: undo)
        } label: { Label("删除", systemImage: "trash") }
    }
}

private struct DoneLine: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var pulse = false
    let day: String

    var body: some View {
        Label(day == store.today ? "今日已记完" : "这一天三餐都记了", systemImage: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .scaleEffect(pulse ? 0.96 : 1)
            .opacity(pulse ? 0 : 1)
            .onAppear {
                // 三餐记完：一次完成反馈，不做庆祝动画
                guard day == store.today, !router.celebrated.contains(day) else { return }
                router.celebrated.insert(day)
                Haptics.success()
                pulse = true
                withAnimation(.easeOut(duration: 0.3)) { pulse = false }
            }
            .accessibilityIdentifier("done-line")
    }
}

private struct AdviceGroup: View {
    @Environment(Router.self) private var router
    let c: DayContext

    var body: some View {
        if c.isOutlier {
            CardGroup(title: "今日建议", headline: true) {
                LedgerRow(title: "今天不计入日常水位", sub: "离群日不生成建议。")
            }
            .accessibilityIdentifier("advice-outlier")
        } else if let a = c.advice {
            CardGroup(title: "今日建议", footer: c.complete ? nil : "三餐还没记完，建议会随记录更新。", headline: true) {
                RowButton { router.sheet = .why(a) } label: { LedgerRow(title: a.text, chevron: true, style: .advice) }
                    .accessibilityHint("点按查看为什么")
                    .accessibilityIdentifier("advice")
            }
        } else {
            CardGroup(title: "今日建议", headline: true) {
                LedgerRow(title: "记下第一笔后，这里会给出一条建议", style: .guide)
            }
        }
    }
}

// MARK: 浮动按钮组

private struct FabGroup: View {
    @Environment(Router.self) private var router

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                fab("magnifyingglass", "搜索食物", "fab-search") { router.sheet = .add(meal: nil, focusSearch: true) }
                Rectangle().fill(Theme.border).frame(width: 36, height: 1 / 3)
                fab("bolt", "One Touch 一触即记", "fab-onetouch") { router.sheet = .oneTouch }
                Rectangle().fill(Theme.border).frame(width: 36, height: 1 / 3)
                fab("plus", "添加记录", "fab-add") { router.sheet = .add(meal: nil, focusSearch: false) }
            }
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 14)
    }

    private func fab(_ symbol: String, _ label: String, _ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
