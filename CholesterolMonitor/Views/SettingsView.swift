// 设置、知识库、免责声明（PRD §5.5、§11）
import LipidDomain
import SwiftUI
import UniformTypeIdentifiers

let disclaimerText = "本应用用于饮食记录与营养教育，不提供医疗诊断或治疗建议，不能替代医生的专业判断。血脂水平受遗传、体重、运动、药物、疾病等多种因素影响，饮食只是其中之一。请遵医嘱复查与治疗。"

nonisolated struct CSVFile: Transferable {
    var data: Data
    var name: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { f in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(f.name)
            try f.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

nonisolated struct JSONFile: Transferable {
    var data: Data
    var name: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { f in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(f.name)
            try f.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @State private var addingLimit = false
    @State private var confirmDemo = false
    @State private var confirmBlank = false
    @State private var notificationsDenied = false

    var body: some View {
        @Bindable var prefs = prefs
        let st = store.settings
        SheetNav(title: "设置") {
            Page {
                CardGroup(title: "预算模式") {
                    PillSegmented(options: [(BudgetMode.standard, "标准 22 g"), (.strict, "严格 11 g")],
                                  selection: Binding(get: { st.budgetMode }, set: { m in store.updateSettings { $0.budgetMode = m } }), label: "预算模式")
                        .padding(.horizontal, Theme.cellX).padding(.vertical, 8)
                }
                .padding(.top, -22)
                limitsGroup
                oneTouchGroup
                reminderGroup
                CardGroup(title: "显示与反馈") {
                    labeled("外观") { PillSegmented(options: [(Appearance.system, "跟随系统"), (.light, "浅色"), (.dark, "深色")], selection: $prefs.appearance, label: "外观") }
                    LedgerRow(title: "20:00 后自动深色", lead: { EmptyView() }, trailing: { Toggle("20:00 后自动深色", isOn: $prefs.autoDark20).labelsHidden().tint(Theme.accent) })
                    labeled("食物 Emoji 大小") { PillSegmented(options: [(24, "小"), (28, "中"), (34, "大")], selection: $prefs.emojiSize, label: "食物 Emoji 大小") }
                    labeled("惯用手（浮动按钮与键盘主按钮的位置）") { PillSegmented(options: [(Hand.left, "左手"), (.right, "右手")], selection: $prefs.hand, label: "惯用手") }
                    LedgerRow(title: "触感反馈", lead: { EmptyView() }, trailing: { Toggle("触感反馈", isOn: $prefs.haptics).labelsHidden().tint(Theme.accent) })
                }
                dataGroup
                CardGroup(title: "说明", separatorInset: Theme.cellX + 42) {
                    NavigationLink { KnowledgeView() } label: {
                        LedgerRow(title: "知识库", chevron: true) { IconTile(symbol: "book.closed.fill", tone: .orange) }
                    }
                    .buttonStyle(RowButtonStyle())
                    NavigationLink { DisclaimerContent(firstRun: false) } label: {
                        LedgerRow(title: "免责声明", chevron: true) { IconTile(symbol: "shield.fill", tone: .dark) }
                    }
                    .buttonStyle(RowButtonStyle())
                }
                CardGroup(title: "关于") {
                    LedgerRow(title: "血脂账本", sub: "cholesterol-monitor · PRD v0.2 · 版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")") { EmojiIcon("📒") }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $addingLimit) { AddLimitSheet().environment(store).environment(prefs).presentationBackground(Theme.bg) }
        .alert("载入示例数据", isPresented: $confirmDemo) {
            Button("取消", role: .cancel) {}
            Button("载入示例", role: .destructive) {
                store.reset(.demo)
                ToastCenter.shared.show("已载入示例数据")
            }
            .accessibilityIdentifier("confirm-load-demo")
        } message: {
            Text("会删除现有的全部记录和化验结果，换成 90 天的演示数据。示例数据会明确标注“示例”。")
        }
        .clearDemoAlert(isPresented: $confirmBlank)
        .task { notificationsDenied = await Reminders.isDenied() }
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.gSmall).foregroundStyle(Theme.textMuted)
            content()
        }
        .padding(.horizontal, Theme.cellX)
        .padding(.vertical, 8)
    }

    private var limitsGroup: some View {
        CardGroup(title: "每周限额", separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
            ForEach(store.limits) { l in
                let cat = store.categories[l.category]
                LedgerRow(title: cat?.name ?? l.category, sub: "每周 \(l.maxCount) 次", lead: { EmojiIcon(cat?.emoji ?? "") }, trailing: {
                    HStack(spacing: 4) {
                        stepButton("minus", "\(cat?.name ?? "")减少一次", disabled: l.maxCount <= 0) { store.setLimit(l.id, maxCount: l.maxCount - 1) }
                        Text("\(l.maxCount)").font(.gBody.weight(.medium).monospacedDigit()).frame(minWidth: 24)
                        stepButton("plus", "\(cat?.name ?? "")增加一次", disabled: l.maxCount >= 14) { store.setLimit(l.id, maxCount: l.maxCount + 1) }
                        Button { store.removeLimit(l.id) } label: {
                            Icon("trash").foregroundStyle(Theme.warnText).frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除\(cat?.name ?? "")限额")
                    }
                })
            }
            RowButton { addingLimit = true } label: {
                LedgerRow(title: "添加限额", titleColor: Theme.accent) { RowIcon(symbol: "plus") }
            }
        }
    }

    private func stepButton(_ symbol: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(symbol).foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34).background(Theme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private var oneTouchGroup: some View {
        CardGroup(title: "One Touch 管理（\(store.oneTouch.count) / \(maxOneTouch)）", separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
            if store.oneTouch.isEmpty { LedgerRow(title: "还没有 One Touch", style: .guide) }
            ForEach(Array(store.oneTouch.enumerated()), id: \.element.id) { i, o in
                if let food = store.foods[o.foodId] {
                    LedgerRow(title: food.name, sub: "\(Fmt.servingText(o)) · \(o.meal.label)", lead: { EmojiIcon(food.emoji) }, trailing: {
                        HStack(spacing: 4) {
                            stepButton("arrow.up", "\(food.name)上移", disabled: i == 0) { store.moveOneTouchUp(o.id) }
                            Button { store.removeOneTouch(o.id) } label: {
                                Icon("trash").foregroundStyle(Theme.warnText).frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除 One Touch \(food.name)")
                        }
                    })
                }
            }
        }
    }

    private var reminderGroup: some View {
        let st = store.settings
        let cal = Calendar.current
        let base = Days.date(store.today)
        let lo = cal.date(bySettingHour: 18, minute: 0, second: 0, of: base)!
        let hi = cal.date(bySettingHour: 23, minute: 30, second: 0, of: base)!
        let hm = st.reminderTime.split(separator: ":").compactMap { Int($0) }
        let current = cal.date(bySettingHour: hm.first ?? 21, minute: hm.last ?? 30, second: 0, of: base) ?? lo
        return CardGroup(title: "提醒", footer: notificationsDenied && st.reminderEnabled
                         ? "通知权限已关闭，提醒不会出现。可以在系统设置的“通知”里为血脂账本打开。"
                         : "每天最多 1 条本地通知：“今天的账记一下？”。默认 21:30，可在 18:00–23:30 调整。当天已记满三餐不提醒；连续 3 天没打开改为每 3 天 1 条，再 7 天没打开就停止。") {
            LedgerRow(title: "晚间提醒", lead: { EmptyView() }, trailing: {
                Toggle("晚间提醒", isOn: Binding(get: { st.reminderEnabled }, set: { on in
                    store.updateSettings { $0.reminderEnabled = on }
                    if on {
                        Task {
                            let granted = await Reminders.requestAuthorization()
                            notificationsDenied = !granted
                        }
                    }
                }))
                .labelsHidden()
                .tint(Theme.accent)
                .accessibilityIdentifier("reminder-toggle")
            })
            if st.reminderEnabled {
                LedgerRow(title: "提醒时间", lead: { EmptyView() }, trailing: {
                    DatePicker("提醒时间", selection: Binding(get: { current }, set: { d in
                        let c = cal.dateComponents([.hour, .minute], from: d)
                        store.updateSettings { $0.reminderTime = String(format: "%02d:%02d", c.hour ?? 21, c.minute ?? 30) }
                    }), in: lo...hi, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                })
            }
        }
    }

    private var dataGroup: some View {
        let st = store.settings
        return CardGroup(title: "数据", separatorInset: Theme.cellX + 42) {
            ShareLink(item: CSVFile(data: store.exportCSV(), name: "血脂账本-饮食记录-\(store.today).csv"), preview: SharePreview("饮食记录 CSV")) {
                LedgerRow(title: "导出 CSV") { IconTile(symbol: "arrow.down.doc", tone: .blue) }
            }
            .buttonStyle(RowButtonStyle())
            ShareLink(item: JSONFile(data: store.exportJSON(), name: "血脂账本-完整备份-\(store.today).json"), preview: SharePreview("完整备份 JSON")) {
                LedgerRow(title: "导出 JSON") { IconTile(symbol: "arrow.down.doc", tone: .purple) }
            }
            .buttonStyle(RowButtonStyle())
            if st.demo {
                RowButton { confirmBlank = true } label: {
                    LedgerRow(title: "清空示例数据，开始记录", titleColor: Theme.warnText) { IconTile(symbol: "trash", tone: .red) }
                }
            } else {
                RowButton { confirmDemo = true } label: {
                    LedgerRow(title: "载入示例数据") { IconTile(symbol: "doc.text", tone: .gray) }
                }
                .accessibilityIdentifier("load-demo")
            }
        }
    }
}

private struct AddLimitSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let used = Set(store.limits.map(\.category))
        SheetNav(title: "添加限额", doneLabel: "取消") {
            Page {
                CardGroup(separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
                    ForEach(FoodLibrary.categories.filter { !used.contains($0.id) }) { c in
                        RowButton { store.addLimit(category: c.id); dismiss() } label: {
                            LedgerRow(title: c.name) { EmojiIcon(c.emoji) }
                        }
                    }
                }
                .padding(.top, -22)
            }
        }
        .presentationDetents([.large])
    }
}

struct KnowledgeView: View {
    var body: some View {
        Page {
            CardGroup(title: "“预算”和“余额”是什么") {
                CellText("这是记录用的比喻：把饱和脂肪当作每天有预算的货币，每一口是一笔支出。它帮你看清哪一笔最大，不代表身体里真的有一个余额。")
                CellText("和记账不同的地方：营养量是估算的，误差可达三四成，所以界面不显示小数；纤维不能抵消饱和脂肪，所以两者分开显示，不算“净值”；血脂只在化验时更新，日常只看支出。")
            }
            .padding(.top, -12)
            CardGroup(title: "四项指标", footer: "以上阈值尚待逐条对照指南原文核实，特别是可溶性纤维 10 g 与严格模式 11 g。") {
                LedgerRow(title: "饱和脂肪", sub: "主预算 · 标准 22 g（约 10% 能量，按 2000 kcal），严格 11 g", value: "支出")
                LedgerRow(title: "反式脂肪", sub: "零预算 · 尽量为 0，上限 2 g", value: "支出")
                LedgerRow(title: "膳食胆固醇", sub: "副预算 · 300 mg", value: "支出")
                LedgerRow(title: "可溶性膳食纤维", sub: "储蓄目标 · 至少 10 g，不与支出相抵", value: "储蓄")
            }
            CardGroup(title: "食物分级（每 100 g 可食部）") {
                LedgerRow(title: "友好", sub: "饱和脂肪 < 2 g") { GradeBadge(grade: .a) }
                LedgerRow(title: "适量", sub: "饱和脂肪 2–5 g") { GradeBadge(grade: .b) }
                LedgerRow(title: "留意", sub: "饱和脂肪 ≥ 5 g，或反式脂肪 > 0.1 g，或胆固醇 ≥ 100 mg") { GradeBadge(grade: .c) }
            }
            CardGroup(title: "个人基线与离群日") {
                CellText("“日常水位”是你最近 14 个非离群日的均值，不足 5 天时不显示。聚餐、节日可以标记为离群日：照常记录和显示，但不计入水位，也不触发当日建议。")
            }
            CardGroup(title: "每周次数限额") { CellText("克数难估，次数好记。默认 4 条限额是产品建议值，不是指南原文，可以在设置中增删改。") }
            CardGroup(title: "依据来源") {
                LedgerRow(title: "《中国血脂管理指南（2023 年）》")
                LedgerRow(title: "《中国居民膳食指南（2022）》")
                LedgerRow(title: "2018 AHA/ACC Guideline on the Management of Blood Cholesterol")
                LedgerRow(title: "《中国食物成分表》（第 6 版）", sub: "本版的食物库是估算值，尚未使用该表数据")
            }
        }
        .navigationTitle("知识库")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DisclaimerContent: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    let firstRun: Bool

    var body: some View {
        Page {
            SheetNote(disclaimerText, strong: true)
            if firstRun {
                SheetNote("食物营养数值是估算值（未核实），各项预算阈值尚未对照指南原文核实。全部数据只存在这台设备上，一开始是空的；想先看看效果，可以在设置里载入示例数据。")
                ButtonRow {
                    Button("我已阅读并了解") {
                        prefs.ack = true
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityIdentifier("ack-disclaimer")
                }
            }
        }
        .navigationTitle("免责声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DisclaimerSheet: View {
    let firstRun: Bool

    var body: some View {
        NavigationStack { DisclaimerContent(firstRun: firstRun) }
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(firstRun)
    }
}
