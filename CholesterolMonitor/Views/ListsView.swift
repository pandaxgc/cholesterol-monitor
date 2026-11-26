// 清单：智能列表、我的常吃、食物库（PRD §5.2）
import LipidDomain
import SwiftUI

private func relDay(_ n: Int) -> String? { n == 0 ? "今天" : n == 1 ? "昨天" : n <= 7 ? "\(n) 天前" : nil }

struct ListsView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Prefs.self) private var prefs
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        let entries = store.entries.filter { store.foods[$0.foodId] != nil }
        let today = store.today
        let ws = Days.weekStart(today), d7 = Days.add(today, -6), d30 = Days.add(today, -29)
        let week = entries.filter { $0.day >= ws && $0.day <= today }
        let limitCats = Set(store.limits.map(\.category))
        let smart: [(String, String, [Entry], String)] = [
            ("eye", "本周留意级食物", week.filter { store.foods[$0.foodId]!.grade == .c }, "这周还没有留意级的食物。"),
            ("gauge.with.needle", "本周限额类别", week.filter { limitCats.contains(store.foods[$0.foodId]!.category) }, "这周还没有限额类别的记录。"),
            ("fork.knife", "最近 7 天外食", entries.filter { $0.day >= d7 && store.foods[$0.foodId]!.category == "dining_out" }, "最近 7 天没有外食记录。"),
            ("exclamationmark.triangle", "含反式脂肪的记录", entries.filter { $0.day >= d30 && store.foods[$0.foodId]!.nutritionPer100g.transFatG > 0 }, "最近 30 天没有含反式脂肪的记录。"),
        ]
        let usual = Ledger.frequentFoods(entries, sinceDay: d30).prefix(8)
        let emojiInset = Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12
        NavigationStack {
            Page(bottomInset: 40) {
                DemoBanner()
                CardGroup(title: "智能列表", headline: true, separatorInset: Theme.cellX + 40) {
                    ForEach(smart, id: \.1) { s in
                        RowButton { router.sheet = .entryList(EntryListRequest(title: s.1, entries: s.2, emptyText: s.3)) } label: {
                            LedgerRow(title: s.1, value: "\(s.2.count)", chevron: true) { RowIcon(symbol: s.0) }
                        }
                    }
                }
                CardGroup(title: "我的常吃", footer: usual.isEmpty ? nil : "按最近 30 天的使用频率排序。点 ⚡ 转为 One Touch。", headline: true, separatorInset: emojiInset) {
                    if usual.isEmpty {
                        LedgerRow(title: "记录几天后，这里会列出你最常吃的食物", style: .guide)
                    }
                    ForEach(Array(usual)) { u in
                        let food = store.foods[u.foodId]!
                        let last = entries.filter { $0.foodId == u.foodId }.max { $0.createdAt < $1.createdAt }!
                        HStack(spacing: 0) {
                            RowButton { router.sheet = .foodDetail(food.id) } label: {
                                LedgerRow(title: food.name, sub: "\(u.count) 次 · 常用 \(Fmt.servingText(last))") { EmojiIcon(food.emoji) }
                            }
                            Button {
                                ToastCenter.shared.show(store.addOneTouch(foodId: last.foodId, servingLabel: last.servingLabel, multiplier: last.multiplier, meal: last.meal).text)
                            } label: {
                                Image(systemName: "bolt").font(.system(size: 17)).foregroundStyle(Theme.accent).frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel("把\(food.name)存为 One Touch")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("食物库").font(Theme.groupTitle).padding(.horizontal, 8).padding(.bottom, 10).accessibilityAddTraits(.isHeader)
                    SearchField(placeholder: "搜索食物库", text: $query, focused: $searchFocused).accessibilityIdentifier("library-search")
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 28)
                library(emojiInset: emojiInset).padding(.top, -16)
            }
            .navigationTitle("清单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func library(emojiInset: CGFloat) -> some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let hits = store.matchFoods(q)
            if hits.isEmpty {
                SheetNote("没有找到“\(q)”。").padding(.top, 22)
            } else {
                CardGroup(separatorInset: emojiInset) {
                    ForEach(hits) { f in RowButton { router.sheet = .foodDetail(f.id) } label: { FoodRow(food: f, chevron: true) } }
                }
            }
        } else {
            CardGroup(footer: "共 \(store.foods.count) 种食物，类别按你的使用量排序。营养数值为估算值，尚未对照《中国食物成分表》核实。", separatorInset: emojiInset) {
                ForEach(store.categoriesByUse) { c in
                    RowButton { router.sheet = .category(c.id) } label: {
                        LedgerRow(title: c.name, value: "\(store.foods(in: c.id).count) 种", chevron: true) { EmojiIcon(c.emoji) }
                    }
                    .accessibilityIdentifier("category-\(c.id)")
                }
            }
        }
    }
}

struct EntryListSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    let request: EntryListRequest

    var body: some View {
        SheetNav(title: request.title) {
            Page {
                if request.entries.isEmpty {
                    SheetNote(request.emptyText)
                } else {
                    CardGroup(separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
                        ForEach(request.entries.sorted { ($0.day, $0.createdAt) > ($1.day, $1.createdAt) }) { e in
                            if let food = store.foods[e.foodId] {
                                NavigationLink(value: food.id) {
                                    LedgerRow(title: food.name, grade: food.grade, sub: "\(Days.label(e.day)) · \(e.meal.label) · \(Fmt.servingText(e))",
                                              value: Fmt.sat(Ledger.nutrition(of: e, food: food).sat)) { EmojiIcon(food.emoji) }
                                }
                                .buttonStyle(RowButtonStyle())
                            }
                        }
                    }
                    .padding(.top, -22)
                }
            }
            .navigationDestination(for: String.self) { FoodDetailView(foodId: $0) }
        }
        .presentationDetents([.large])
    }
}

struct CategorySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    let categoryId: String

    var body: some View {
        SheetNav(title: store.categories[categoryId]?.name) {
            Page {
                CardGroup(separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
                    ForEach(store.foods(in: categoryId)) { f in
                        NavigationLink(value: f.id) { FoodRow(food: f, chevron: true) }
                            .buttonStyle(RowButtonStyle())
                            .accessibilityIdentifier("food-\(f.id)")
                    }
                }
                .padding(.top, -22)
            }
            .navigationDestination(for: String.self) { FoodDetailView(foodId: $0) }
        }
        .presentationDetents([.large])
    }
}

struct FoodDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @State private var keypad: KeypadRequest?
    let foodId: String

    var body: some View {
        if let food = store.foods[foodId] {
            let n = food.nutritionPer100g
            let recent = Array(store.entries.filter { $0.foodId == food.id }.map(\.day).uniqued().sorted(by: >).prefix(5))
            Page {
                HStack(spacing: 14) {
                    Text(food.emoji).font(.system(size: 48)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.name).font(.title3.weight(.bold))
                        GradeBadge(grade: food.grade)
                        if !food.aliases.isEmpty {
                            Text("也叫：\(food.aliases.joined(separator: "、"))").font(.footnote).foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter + 4)
                .padding(.top, 4)
                ButtonRow {
                    Button("记一笔到 \(Days.label(store.day))") { keypad = KeypadRequest(food: food, meal: defaultMeal(store)) }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("food-log")
                }
                CardGroup(title: "每 100 g 可食部", footer: "类别：\(store.categories[food.category]?.name ?? "")。显示值已按规则取整。") {
                    LedgerRow(title: "饱和脂肪", value: Fmt.sat(n.satFatG))
                    LedgerRow(title: "反式脂肪", value: n.transFatG > 0 ? "含" : "不含")
                    LedgerRow(title: "膳食胆固醇", value: Fmt.chol(n.cholesterolMg))
                    LedgerRow(title: "可溶性纤维", value: Fmt.fiber(n.solubleFiberG))
                }
                CardGroup(title: "份量校准", footer: "每个量具绑定一个默认克数。你家的碗大一些或小一些，可以在这里改；留空恢复默认。") {
                    ForEach(food.servings, id: \.label) { sv in
                        let base = store.baseServingGrams(foodId: food.id, label: sv.label) ?? sv.grams
                        LedgerRow(title: sv.label, sub: "默认 \(Fmt.number(base)) g", lead: { EmptyView() }, trailing: {
                            GramsField(label: sv.label, grams: sv.grams) { v in
                                store.setServingOverride(foodId: food.id, label: sv.label, grams: v > 0 && v <= 2000 && v != base ? v : 0)
                            }
                        })
                    }
                }
                CardGroup(title: "数据来源") { LedgerRow(title: food.source, sub: "数据版本 \(food.dataVersion)") }
                CardGroup(title: "最近吃过") {
                    if recent.isEmpty { LedgerRow(title: "还没有记录", style: .guide) }
                    ForEach(recent, id: \.self) { d in LedgerRow(title: Days.label(d), value: relDay(Days.diff(store.today, d))) }
                }
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $keypad) { k in
                KeypadView(request: k).environment(store).environment(prefs)
            }
        }
    }
}

/// 克数输入：失去焦点时提交。
private struct GramsField: View {
    let label: String
    let grams: Double
    let commit: (Double) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focused)
                .padding(.horizontal, 8)
                .frame(width: 72, height: 34)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("\(label)的克数")
            Text("g").foregroundStyle(Theme.textMuted)
        }
        .onAppear { text = Fmt.number(grams) }
        .onChange(of: grams) { if !focused { text = Fmt.number(grams) } }
        .onChange(of: focused) {
            guard !focused else { return }
            guard let raw = Double(text), raw.isFinite else { text = Fmt.number(grams); return }
            commit(Double(Fmt.round(raw)))
        }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focused = false }
                }
            }
        }
    }
}
