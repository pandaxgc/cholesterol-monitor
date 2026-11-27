// 晚间批量补记：添加面板、份量键盘、One Touch（PRD §6、§3.6）
import LipidDomain
import SwiftUI

let mealOptions: [(Meal, String)] = Meal.allCases.map { ($0, $0.label) }

/// 食物行：等级 + 默认量具的饱和脂肪。
struct FoodRow: View {
    let food: Food
    var chevron = false

    var body: some View {
        let sv = food.defaultServingValue
        let sat = food.nutritionPer100g.satFatG * sv.grams / 100
        LedgerRow(title: food.name, grade: food.grade, value: "\(sv.label) \(Fmt.sat(sat))", chevron: chevron) { EmojiIcon(food.emoji) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(food.name)，\(food.grade.label)，\(sv.label)饱和脂肪约 \(Fmt.round(sat)) 克")
    }
}

// MARK: 添加面板：提交一条后不关闭，停在当前餐次继续添加

struct AddPanelView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @State private var meal: Meal = .breakfast
    @State private var query = ""
    @State private var category: String?
    @State private var keypad: KeypadRequest?
    @FocusState private var searchFocused: Bool
    let initialMeal: Meal?
    let focusSearch: Bool

    init(initialMeal: Meal?, focusSearch: Bool) {
        self.initialMeal = initialMeal
        self.focusSearch = focusSearch
    }

    var body: some View {
        SheetNav(title: "补记 · \(Days.label(store.day))") {
            Page {
                PillSegmented(options: mealOptions, selection: $meal, label: "餐次")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .accessibilityIdentifier("add-meal")
                SearchField(placeholder: "搜索食物，例如 红烧肉", text: $query, focused: $searchFocused)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 12)
                    .accessibilityIdentifier("add-search")
                let logged = store.entries(on: store.day).filter { $0.meal == meal }.compactMap { store.foods[$0.foodId]?.name }
                Text(logged.isEmpty ? "\(meal.label)还没有记录" : "\(meal.label)已记：\(logged.joined(separator: "、"))")
                    .font(.gSmall)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, Theme.gutter + Theme.cellX)
                    .padding(.top, 12)
                    .accessibilityIdentifier("add-status")
                results
            }
        }
        .presentationDetents([.large])
        .sheet(item: $keypad) { k in
            KeypadView(request: k) { meal = $0 }
                .environment(store)
                .environment(prefs)
        }
        .onAppear {
            meal = initialMeal ?? defaultMeal(store)
            if focusSearch {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    searchFocused = true
                }
            }
        }
    }

    private var emojiInset: CGFloat { Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12 }

    private func pick(_ food: Food) {
        searchFocused = false
        keypad = KeypadRequest(food: food, meal: meal)
    }

    @ViewBuilder private var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let hits = store.matchFoods(q)
            if hits.isEmpty {
                SheetNote("没有找到“\(q)”。外食不知道具体食材时，可以先按类型归档，例如“外卖盖饭”“中式宴席”。")
            } else {
                CardGroup(title: "找到 \(hits.count) 种", separatorInset: emojiInset) {
                    ForEach(hits) { f in RowButton { pick(f) } label: { FoodRow(food: f) }.accessibilityIdentifier("food-\(f.id)") }
                }
            }
        } else {
            let usual = Ledger.frequentFoods(store.entries, sinceDay: Days.add(store.today, -30), meal: meal).prefix(5).compactMap { store.foods[$0.foodId] }
            if !usual.isEmpty {
                CardGroup(title: "\(meal.label)常吃", separatorInset: emojiInset) {
                    ForEach(usual) { f in RowButton { pick(f) } label: { FoodRow(food: f) }.accessibilityIdentifier("food-\(f.id)") }
                }
            }
            let cats = store.categoriesByUse
            let current = category ?? cats.first?.id ?? ""
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cats) { c in
                        let on = c.id == current
                        Button { category = c.id } label: {
                            HStack(spacing: 4) {
                                Text(c.emoji).font(.system(size: 16)).accessibilityHidden(true)
                                Text(c.name)
                            }
                            .font(.gSmall.weight(on ? .semibold : .medium))
                            .foregroundStyle(on ? Theme.accentFg : Theme.text)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(on ? Theme.accent : Theme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .padding(.top, 16)
            CardGroup(separatorInset: emojiInset) {
                ForEach(store.foods(in: current)) { f in RowButton { pick(f) } label: { FoodRow(food: f) }.accessibilityIdentifier("food-\(f.id)") }
            }
            .padding(.top, -16)
        }
    }
}

// MARK: 份量键盘

struct KeypadView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal
    @State private var servingLabel: String
    @State private var multiplier: Double
    @State private var height: CGFloat = 520
    let request: KeypadRequest
    var onLogged: ((Meal) -> Void)?

    private static let mults: [Double] = [0.5, 1, 1.5, 2]

    @MainActor init(request: KeypadRequest, onLogged: ((Meal) -> Void)? = nil) {
        self.request = request
        self.onLogged = onLogged
        let food = request.food
        _meal = State(initialValue: request.meal)
        _servingLabel = State(initialValue: food.defaultServingValue.label)
        _multiplier = State(initialValue: 1)
    }

    var body: some View {
        let food = store.foods[request.food.id] ?? request.food
        let grams = (food.serving(servingLabel)?.grams ?? food.defaultServingValue.grams) * multiplier
        let n = Ledger.nutrition(grams: grams, food: food)
        VStack(spacing: 0) {
            ZStack {
                Text(request.entry == nil ? "份量" : "编辑份量").font(.gBody.weight(.semibold))
                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("keypad-cancel")
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 表单卡片：食物与数值
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    EmojiIcon(food.emoji)
                    HStack(spacing: 8) {
                        Text(food.name).font(.gBody.weight(.semibold))
                        GradeBadge(grade: food.grade)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("约").font(.gSmall.weight(.semibold))
                        Text("\(Fmt.round(n.sat))").font(.custom("Geist", fixedSize: 28).weight(.bold)).monospacedDigit()
                            .contentTransition(.numericText(value: n.sat))
                            .animation(.snappy, value: Fmt.round(n.sat))
                        Text("g").font(.gSmall.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("饱和脂肪约 \(Fmt.round(n.sat)) 克")
                    .accessibilityIdentifier("keypad-sat")
                }
                Rectangle().fill(Theme.border).frame(height: 1 / 3).padding(.vertical, 8)
                Text("约 \(Fmt.round(grams)) g · 胆固醇\(Fmt.chol(n.chol)) · 纤维\(Fmt.fiber(n.fiber)) · \(Fmt.transLabel(n.trans))")
                    .font(.gSmall.monospacedDigit())
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.cellX)
            .padding(.vertical, 16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, Theme.gutter)

            PillSegmented(options: mealOptions, selection: $meal, label: "餐次")
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)

            keyboard(food: food)
                .padding(.top, 16)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .presentationDetents([.height(height)])
        .presentationBackground(Theme.bg)
        .presentationCornerRadius(32)
        .onAppear {
            // 默认选中该食物上次使用的量具与倍数
            let last = request.entry.map { ServingChoice(servingLabel: $0.servingLabel, multiplier: $0.multiplier) }
                ?? Ledger.lastServing(store.entries, foodId: food.id)
            if let last, food.serving(last.servingLabel) != nil {
                servingLabel = last.servingLabel
                multiplier = last.multiplier
            }
        }
    }

    private func keyboard(food: Food) -> some View {
        let mults = Array(Set(Self.mults + [multiplier])).sorted()
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        let main = VStack(alignment: .leading, spacing: 0) {
            cap("量具")
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(food.servings, id: \.label) { s in
                    key(s.label, small: "\(Fmt.number(s.grams)) g", on: s.label == servingLabel) { servingLabel = s.label }
                        .accessibilityIdentifier("serving-\(s.label)")
                }
            }
            cap("倍数").padding(.top, 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(mults, id: \.self) { m in
                    key(m == 0.5 ? "½" : "×\(Fmt.number(m))", on: m == multiplier) { multiplier = m }
                        .accessibilityLabel(m == 0.5 ? "半份" : "\(Fmt.number(m)) 倍")
                        .accessibilityIdentifier("mult-\(Fmt.number(m))")
                }
            }
        }
        let side = VStack(spacing: 8) {
            Button {
                ToastCenter.shared.show(store.addOneTouch(foodId: food.id, servingLabel: servingLabel, multiplier: multiplier, meal: meal).text)
            } label: {
                VStack(spacing: 4) {
                    Icon("bolt")
                    Text("One Touch").font(.gSmall)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.kbFn, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 0, y: 1)
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityLabel("存为 One Touch")
            .accessibilityIdentifier("keypad-onetouch")
            Button { submit(food: food) } label: {
                Text(request.entry == nil ? "记一笔" : "保存")
                    .font(.gBody.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 4)
                    .foregroundStyle(Theme.accentFg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityIdentifier("keypad-submit")
        }
        .padding(.top, 24)
        return HStack(alignment: .top, spacing: 8) {
            if prefs.hand == .left { side.containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: 8) }
            main.frame(maxWidth: .infinity)
            if prefs.hand == .right { side.containerRelativeFrame(.horizontal, count: 4, span: 1, spacing: 8) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.kb, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .foregroundStyle(Theme.text)
    }

    private func cap(_ text: String) -> some View {
        Text(text).font(.gSmall.weight(.medium)).foregroundStyle(Theme.textMuted).padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 4)
    }

    private func key(_ label: String, small: String? = nil, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label).font(.gBody.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                if let small { Text(small).font(.gSmall.monospacedDigit()).foregroundStyle(on ? Theme.accentFg.opacity(0.85) : Theme.textMuted) }
            }
            .foregroundStyle(on ? Theme.accentFg : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(on ? Theme.accent : Theme.key, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 0, y: 1)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func submit(food: Food) {
        Haptics.light()
        if let entry = request.entry {
            store.updateEntry(entry, meal: meal, servingLabel: servingLabel, multiplier: multiplier, food: food)
            ToastCenter.shared.show("已更新\(food.name)")
        } else {
            let r = store.addEntry(day: store.day, meal: meal, food: food, servingLabel: servingLabel, multiplier: multiplier, source: .search)
            ToastCenter.shared.show(r.merged ? "\(meal.label)里已有\(food.name)，已合并为 \(Fmt.servingText(r.entry))" : "已记入\(meal.label)：\(food.name)", undo: r.undo)
        }
        onLogged?(meal)
        dismiss()
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: One Touch

struct OneTouchView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(Prefs.self) private var prefs
    @State private var justLogged: String?

    var body: some View {
        let list = store.oneTouch.filter { store.foods[$0.foodId] != nil }
        let sugg = list.count < maxOneTouch
            ? Ledger.oneTouchSuggestions(store.entries, existing: list, sinceDay: Days.add(store.today, -30)).filter { store.foods[$0.foodId] != nil }
            : []
        SheetNav(title: "One Touch") {
            Page {
                if list.isEmpty {
                    SheetNote("还没有 One Touch")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(list) { o in tile(o) }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 12)
                }
                if !sugg.isEmpty {
                    CardGroup(title: "你的高频食物", separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
                        ForEach(sugg) { s in
                            let food = store.foods[s.foodId]!
                            LedgerRow(title: food.name, sub: "\(Fmt.servingText(s)) · \(s.meal.label) · \(s.count) 次", lead: { EmojiIcon(food.emoji) }, trailing: {
                                Button("添加") {
                                    ToastCenter.shared.show(store.addOneTouch(foodId: s.foodId, servingLabel: s.servingLabel, multiplier: s.multiplier, meal: s.meal).text)
                                }
                                .font(.gSmall.weight(.medium))
                                .foregroundStyle(Theme.accent)
                                .buttonStyle(.plain)
                                .accessibilityLabel("把\(food.name)添加为 One Touch")
                            })
                        }
                    }
                }
                HStack {
                    Text("\(list.count) / \(maxOneTouch)").font(.gBody.monospacedDigit()).foregroundStyle(Theme.textMuted)
                    Spacer()
                    Button("管理") { router.replace(with: .settings) }.foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, Theme.gutter + 4)
                .padding(.top, 16)
            }
        }
        .presentationDetents([.large])
    }

    private func tile(_ o: OneTouch) -> some View {
        let food = store.foods[o.foodId]!
        let sat = Ledger.nutrition(grams: (food.serving(o.servingLabel)?.grams ?? 0) * o.multiplier, food: food).sat
        let logged = justLogged == o.id
        return Button {
            let r = store.addEntry(day: store.day, meal: o.meal, food: food, servingLabel: o.servingLabel, multiplier: o.multiplier, source: .oneTouch)
            Haptics.success()
            justLogged = o.id
            ToastCenter.shared.show(r.merged ? "已合并到\(o.meal.label)的\(food.name)" : "已记入\(o.meal.label)：\(food.name)", undo: r.undo)
        } label: {
            VStack(spacing: 4) {
                EmojiIcon(food.emoji)
                Text(food.name).font(.gSmall.weight(.semibold)).padding(.top, 4).lineLimit(1)
                Text("\(Fmt.servingText(o)) · \(o.meal.label)").font(.gSmall).foregroundStyle(Theme.textMuted).lineLimit(1)
                Text(logged ? "已记" : Fmt.sat(sat)).font(.gSmall.monospacedDigit().weight(logged ? .semibold : .regular))
                    .foregroundStyle(logged ? Theme.accent : Theme.textMuted)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.horizontal, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(logged ? Theme.accent : .clear, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("\(food.name)，\(Fmt.servingText(o))，\(o.meal.label)，饱和脂肪约 \(Fmt.round(sat)) 克。点按入账")
        .accessibilityIdentifier("ot-\(o.foodId)-\(o.meal.rawValue)")
    }
}
