// 化验：血脂四项录入与对照（PRD §5.4）
import Charts
import LipidDomain
import SwiftUI

let labNote = "血脂受遗传、药物、体重等多种因素影响，本页仅作记录对照，不构成因果结论。"

private let fields: [(WritableKeyPath<LabResult, Double?>, String, String)] = [
    (\.tc, "TC", "总胆固醇"), (\.ldlC, "LDL-C", "低密度脂蛋白胆固醇"), (\.hdlC, "HDL-C", "高密度脂蛋白胆固醇"), (\.tg, "TG", "甘油三酯"),
]

private func fmt(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "—" }

struct LabsView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let labs = store.labs
        let last = labs.last, prev = labs.count > 1 ? labs[labs.count - 2] : nil
        NavigationStack {
            Page(bottomInset: 40) {
                DemoBanner()
                Text(labNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, Theme.gutter + Theme.cellX)
                    .padding(.top, 14)
                    .fixedSize(horizontal: false, vertical: true)
                ButtonRow {
                    Button("录入化验结果") { router.sheet = .labForm(nil) }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("lab-add")
                }
                if let last {
                    CardGroup(title: "历次结果", right: "mmol/L",
                              footer: labs.count > 1 ? "折线为 \(labs.count) 次结果的走势，右侧是最近一次与上一次的数值。" : "再录入一次后，这里会画出走势。", headline: true) {
                        ForEach(fields, id: \.1) { f in
                            LedgerRow(title: f.1, sub: f.2, lead: { EmptyView() }, trailing: {
                                HStack(spacing: 10) {
                                    Spark(values: labs.map { $0[keyPath: f.0] })
                                    Amount(prev.map { "\(fmt($0[keyPath: f.0])) → \(fmt(last[keyPath: f.0]))" } ?? fmt(last[keyPath: f.0]))
                                        .frame(minWidth: 76, alignment: .trailing)
                                }
                            })
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(f.2)：\(labs.map { "\(Days.label($0.date)) \(fmt($0[keyPath: f.0]))" }.joined(separator: "，"))")
                        }
                    }
                    IntervalGroup(title: "\(Days.label(last.date)) 至今", from: last.date, to: Days.add(store.today, 1))
                    ForEach(Array(stride(from: labs.count - 1, through: 1, by: -1)), id: \.self) { i in
                        IntervalGroup(title: "\(Days.label(labs[i - 1].date)) 至 \(Days.label(labs[i].date))", from: labs[i - 1].date, to: labs[i].date)
                    }
                    CardGroup(title: "记录", headline: true) {
                        ForEach(labs.reversed()) { l in
                            RowButton { router.sheet = .labForm(l) } label: {
                                LedgerRow(title: l.date, tag: l.demo ? "示例" : nil,
                                          sub: fields.map { "\($0.1) \(fmt(l[keyPath: $0.0]))" }.joined(separator: " · ") + (!l.note.isEmpty && !l.demo ? " · \(l.note)" : ""),
                                          chevron: true)
                            }
                            .accessibilityIdentifier("lab-\(l.date)")
                        }
                    }
                } else {
                    SheetNote("还没有化验结果。拿到化验单后录入血脂四项，这里会并列显示同期的饮食均值。").padding(.top, 8)
                }
            }
            .navigationTitle("化验")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct Spark: View {
    let values: [Double?]

    var body: some View {
        let pts = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        let lo = pts.map(\.1).min() ?? 0, hi = pts.map(\.1).max() ?? 1
        Chart {
            ForEach(pts, id: \.0) { p in
                LineMark(x: .value("次", p.0), y: .value("值", p.1)).foregroundStyle(Theme.accent).lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("次", p.0), y: .value("值", p.1)).foregroundStyle(Theme.accent).symbolSize(20)
            }
        }
        .chartXScale(domain: -0.15...(Double(max(1, values.count - 1)) + 0.15))
        .chartYScale(domain: (lo == hi ? lo - 1 : lo - (hi - lo) * 0.15)...(lo == hi ? hi + 1 : hi + (hi - lo) * 0.15))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 90, height: 34)
        .accessibilityHidden(true)
    }
}

private struct IntervalGroup: View {
    @Environment(AppStore.self) private var store
    let title: String
    let from: String
    let to: String

    var body: some View {
        if let s = Ledger.intervalSummary(store.entries, foods: store.foods, limits: store.limits, outliers: store.outliers, from: from, to: to) {
            CardGroup(title: title, footer: "\(s.recordedDays) 个记录日（不含离群日）的同期饮食均值。") {
                LedgerRow(title: "饱和脂肪日均", value: Fmt.sat(s.satMean))
                LedgerRow(title: "纤维达标天数", value: "约 \(Fmt.roundPct5(s.fiberShare))%")
                LedgerRow(title: "限额执行", value: "\(s.okWeeks) / \(s.weeks) 周在限额内")
            }
        } else {
            CardGroup(title: title) { LedgerRow(title: "这段时间没有饮食记录", style: .guide) }
        }
    }
}

struct LabFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var values: [String] = ["", "", "", ""]
    @State private var note = ""
    @State private var error: String?
    @State private var confirmDelete = false
    let lab: LabResult?

    var body: some View {
        SheetNav(title: lab == nil ? "录入化验结果" : "编辑化验结果", doneLabel: "取消") {
            Page {
                CardGroup(footer: "单位 mmol/L。化验单上没有的项目可以留空。") {
                    HStack {
                        Text("检测日期").font(.body.weight(.semibold))
                        Spacer()
                        DatePicker("检测日期", selection: $date, in: ...Days.date(store.today), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    .padding(.horizontal, Theme.cellX)
                    .frame(minHeight: 52)
                    ForEach(fields.indices, id: \.self) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(fields[i].1).font(.body.weight(.semibold))
                                Text(fields[i].2).font(.footnote).foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            TextField("mmol/L", text: $values[i])
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .padding(.horizontal, 10)
                                .frame(width: 130, height: 36)
                                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityLabel(fields[i].2)
                                .accessibilityIdentifier("lab-field-\(fields[i].1)")
                        }
                        .padding(.horizontal, Theme.cellX)
                        .padding(.vertical, 8)
                    }
                    HStack {
                        Text("备注").font(.body.weight(.semibold))
                        Spacer()
                        TextField("例如 体检中心", text: $note)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 10)
                            .frame(width: 170, height: 36)
                            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onChange(of: note) { if note.count > 40 { note = String(note.prefix(40)) } }
                    }
                    .padding(.horizontal, Theme.cellX)
                    .frame(minHeight: 52)
                }
                .padding(.top, -22)
                if let error {
                    Text(error).font(.subheadline).foregroundStyle(Theme.warnText)
                        .padding(.horizontal, Theme.gutter + Theme.cellX).padding(.top, 10)
                        .accessibilityIdentifier("lab-error")
                }
                ButtonRow {
                    if lab != nil {
                        Button("删除") { confirmDelete = true }.buttonStyle(PillButtonStyle(tone: .secondary, danger: true))
                    }
                    Button("保存", action: save).buttonStyle(PillButtonStyle()).accessibilityIdentifier("lab-save")
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .onAppear {
            guard let lab else { date = Days.date(store.today); return }
            date = Days.date(lab.date)
            values = fields.map { lab[keyPath: $0.0].map { Fmt.number($0) } ?? "" }
            note = lab.demo ? "" : lab.note
        }
        .alert("删除这次化验结果", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let lab { store.removeLab(lab.id) }
                dismiss()
                ToastCenter.shared.show("已删除")
            }
        } message: {
            Text("\(Days.label(lab?.date ?? store.today))的化验结果会被删除。")
        }
    }

    private func save() {
        let day = Days.day(of: date)
        if day > store.today { error = "请选择检测日期，不能晚于今天。"; return }
        var parsed: [Double?] = []
        for v in values {
            let t = v.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            if t.isEmpty { parsed.append(nil); continue }
            guard let d = Double(t) else { error = "化验值应在 0 到 30 mmol/L 之间，请核对。"; return }
            parsed.append(d)
        }
        let filled = parsed.compactMap { $0 }
        if filled.isEmpty { error = "至少填写一项化验值。"; return }
        if filled.contains(where: { !($0 > 0 && $0 <= 30) }) { error = "化验值应在 0 到 30 mmol/L 之间，请核对。"; return }
        var l = lab ?? LabResult(id: "", date: day)
        l.date = day
        for (i, f) in fields.enumerated() { l[keyPath: f.0] = parsed[i] }
        l.note = note.trimmingCharacters(in: .whitespaces)
        store.saveLab(l)
        dismiss()
        ToastCenter.shared.show("已保存化验结果")
    }
}
