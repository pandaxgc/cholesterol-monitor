// 今日页弹出的面板：来源明细、本周限额、为什么、日期与离群日、记录操作。
import LipidDomain
import SwiftUI

struct SourcesSheet: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let c = store.dayContext(store.day)
        SheetNav(title: "今日饱和脂肪来源") {
            Page {
                if c.spend.items.isEmpty {
                    SheetNote("这一天还没有记录。")
                } else {
                    let items = c.spend.items.sorted { $0.n.sat > $1.n.sat }
                    CardGroup(separatorInset: Theme.cellX + 47) {
                        ForEach(items) { i in
                            LedgerRow(title: i.food.name, sub: "\(i.entry.meal.label) · \(Fmt.servingText(i.entry))",
                                      value: "\(Fmt.sat(i.n.sat)) · 约 \(Fmt.roundPct5(c.spend.total.sat > 0 ? i.n.sat / c.spend.total.sat : 0))%") { EmojiIcon(i.food.emoji) }
                        }
                    }
                    .padding(.top, -22)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct LimitsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let c = store.dayContext(store.day)
        SheetNav(title: "本周限额") {
            Page {
                CardGroup(separatorInset: Theme.cellX + 47) {
                    ForEach(c.weekly) { w in
                        let cat = store.categories[w.limit.category]
                        let left = w.limit.maxCount - w.count
                        LedgerRow(title: cat?.name ?? w.limit.category, sub: left > 0 ? "还可 \(left) 次" : left == 0 ? "已到上限" : "超出 \(-left) 次",
                                  value: "\(w.count) / \(w.limit.maxCount) 次", valueWarn: left < 0) { EmojiIcon(cat?.emoji ?? "") }
                    }
                }
                .padding(.top, -22)
                ButtonRow {
                    Button("在设置中修改限额") { router.replace(with: .settings) }.buttonStyle(PillButtonStyle(tone: .secondary))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct WhySheet: View {
    let advice: Advice

    var body: some View {
        SheetNav(title: "为什么") {
            Page {
                SheetNote(advice.text, strong: true)
                if !advice.why.records.isEmpty {
                    CardGroup(title: "涉及的记录") {
                        ForEach(Array(advice.why.records.enumerated()), id: \.offset) { _, r in
                            LedgerRow(title: r.name, sub: "\(r.meal) · \(r.serving)", value: r.sat)
                        }
                    }
                }
                CardGroup(title: "计算过程") { CellText(advice.why.calc) }
                CardGroup(title: "依据") { CellText(advice.why.source) }
            }
        }
        .presentationDetents([.large])
    }
}

struct DayMenuSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    var body: some View {
        let isToday = store.day == store.today
        let isOutlier = store.outliers.contains(store.day)
        SheetNav(title: dayTitle(store.day)) {
            Page {
                                CardGroup(separatorInset: Theme.cellX + 40) {
                    RowButton { withAnimation { picking.toggle() } } label: {
                        LedgerRow(title: "选择日期") { RowIcon(symbol: "calendar") }
                    }
                    if picking {
                        DatePicker("日期", selection: Binding(get: { Days.date(store.day) }, set: { store.setDay(Days.day(of: $0)); dismiss() }),
                                   in: ...Days.date(store.today), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .padding(.horizontal, 8)
                    }
                    if !isToday {
                        RowButton { store.setDay(store.today); dismiss() } label: {
                            LedgerRow(title: "回到今天") { RowIcon(symbol: "doc.text") }
                        }
                    }
                    RowButton {
                        let on = store.toggleOutlier(store.day)
                        ToastCenter.shared.show(on ? "已标记为离群日" : "已取消离群日标记")
                        dismiss()
                    } label: {
                        LedgerRow(title: isOutlier ? "取消离群日标记" : "标记为离群日") { RowIcon(symbol: isOutlier ? "xmark" : "checkmark") }
                    }
                    .accessibilityIdentifier("toggle-outlier")
                }
                .padding(.top, -12)
            }
        }
        .presentationDetents(picking ? [.large] : [.medium, .large])
    }
}

struct EntryMenuSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let entry: Entry

    var body: some View {
        if let food = store.foods[entry.foodId] {
            SheetNav(title: "\(food.name) · \(Fmt.servingText(entry))") {
                Page {
                    CardGroup(separatorInset: Theme.cellX + 40) {
                        RowButton { router.replace(with: .keypad(KeypadRequest(food: food, meal: entry.meal, entry: entry))) } label: {
                            LedgerRow(title: "编辑份量") { RowIcon(symbol: "pencil") }
                        }
                        .accessibilityIdentifier("entry-edit")
                        LedgerRow(title: "复制到", lead: { RowIcon(symbol: "doc.on.doc") }, trailing: {
                            HStack(spacing: 8) {
                                ForEach(Meal.allCases.filter { $0 != entry.meal }) { m in
                                    Button(m.label) {
                                        let r = store.addEntry(day: entry.day, meal: m, food: food, servingLabel: entry.servingLabel, multiplier: entry.multiplier, grams: entry.grams, source: .search)
                                        dismiss()
                                        ToastCenter.shared.show("已复制到\(m.label)", undo: r.undo)
                                    }
                                    .font(.gSmall.weight(.medium))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 34)
                                    .background(Theme.fill, in: Capsule())
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("复制到\(m.label)")
                                }
                            }
                        })
                        RowButton {
                            ToastCenter.shared.show(store.addOneTouch(foodId: entry.foodId, servingLabel: entry.servingLabel, multiplier: entry.multiplier, meal: entry.meal).text)
                            dismiss()
                        } label: {
                            LedgerRow(title: "存为 One Touch") { RowIcon(symbol: "bolt") }
                        }
                        RowButton {
                            let undo = store.deleteEntry(entry)
                            dismiss()
                            ToastCenter.shared.show("已删除\(food.name)", undo: undo)
                        } label: {
                            LedgerRow(title: "删除", titleColor: Theme.warnText) { RowIcon(symbol: "trash", danger: true) }
                        }
                        .accessibilityIdentifier("entry-delete")
                    }
                    .padding(.top, -12)
                }
            }
            .presentationDetents([.medium])
        }
    }
}
