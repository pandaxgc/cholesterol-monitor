// 分析：热力图、趋势、支出来源、限额执行（PRD §5.3）
import Charts
import LipidDomain
import SwiftUI

struct AnalysisView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @State private var picked: String?

    var body: some View {
        @Bindable var prefs = prefs
        let out = store.outliers, excl = prefs.excludeOutliers, range = prefs.range
        let budget = Budget.sat(store.settings.budgetMode)
        let days = Days.range(end: store.today, count: range)
        let inRange = store.entries.filter { $0.day >= days[0] && $0.day <= store.today }
        let counted = inRange.filter { !(excl && out.contains($0.day)) }
        let totals = Ledger.totalsByDay(inRange, foods: store.foods)
        let allTotals = Ledger.totalsByDay(store.entries, foods: store.foods)
        let thresholds = Ledger.heatThresholds(allTotals.filter { !(excl && out.contains($0.key)) }.map(\.value.sat))
        let label = range == 7 ? "过去 7 天" : range == 30 ? "过去 30 天" : "过去 90 天"
        NavigationStack {
            Page(bottomInset: 40) {
                DemoBanner()
                PillSegmented(options: [(7, "周"), (30, "月"), (90, "90 天")], selection: Binding(get: { prefs.range }, set: { picked = nil; prefs.range = $0 }), label: "时间范围")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 12)
                    .accessibilityIdentifier("analysis-range")
                CardGroup {
                    LedgerRow(title: "排除离群日", lead: { EmptyView() }, trailing: {
                        Toggle("排除离群日", isOn: $prefs.excludeOutliers).labelsHidden().tint(Theme.accent)
                    })
                }
                .padding(.top, -16)
                if inRange.isEmpty {
                    SheetNote("\(label)没有记录。记几天后，这里会出现你的热力图和趋势。").padding(.top, 16)
                } else {
                    content(days: days, counted: counted, totals: totals, allTotals: allTotals, thresholds: thresholds, budget: budget, label: label)
                }
            }
            .navigationTitle("分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func content(days: [String], counted: [Entry], totals: [String: Totals], allTotals: [String: Totals], thresholds: [Double], budget: Double, label: String) -> some View {
        let ranking = Ledger.sourceRanking(counted, foods: store.foods)
        let recDays = Ledger.totalsByDay(counted, foods: store.foods)
        let mean = recDays.values.reduce(0) { $0 + $1.sat } / Double(max(1, recDays.count))
        let overDays = recDays.values.filter { $0.sat > budget }.count
        let names = ranking.prefix(2).compactMap { store.categories[$0.category]?.name }
        let share2 = ranking.prefix(2).reduce(0) { $0 + $1.share }
        CardGroup(title: "小结", headline: true) {
            CellText(ranking.first.map { $0.sat > 0 } == true
                     ? "\(label)，你的饱和脂肪约\(Fmt.shareWords(share2))来自\(names.joined(separator: "与"))。有记录的 \(recDays.count) 天里，日均\(Fmt.sat(mean))，\(overDays) 天超出预算。"
                     : "\(label)的记录里几乎没有饱和脂肪。")
                .accessibilityIdentifier("analysis-summary")
        }
        CardGroup(title: "热力图", tag: store.settings.demo ? "示例" : nil, headline: true) {
            HeatmapCard(days: days, totals: totals, outliers: store.outliers, thresholds: thresholds, picked: $picked)
        }
        CardGroup(title: "趋势", headline: true) {
            TrendChart(days: days, totals: totals, allTotals: allTotals, outliers: store.outliers, exclude: prefs.excludeOutliers, budget: budget)
        }
        CardGroup(title: "支出来源", headline: true, separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
            ForEach(ranking.prefix(5).filter { $0.sat > 0 }) { r in
                let cat = store.categories[r.category]
                LedgerRow(title: cat?.name ?? r.category, value: "约 \(Fmt.roundPct5(r.share))%", lead: { EmojiIcon(cat?.emoji ?? "") }, trailing: { EmptyView() })
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { g in
                            Capsule().fill(Theme.fill).overlay(alignment: .leading) {
                                Capsule().fill(Theme.accent).frame(width: max(4, g.size.width * r.share))
                            }
                        }
                        .frame(height: 6)
                        .padding(.leading, Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12)
                        .padding(.trailing, Theme.cellX + 70)
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)
                    }
                    .padding(.bottom, 8)
            }
        }
        LimitExecution(days: days)
    }
}

private struct LimitExecution: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    let days: [String]

    var body: some View {
        let range = prefs.range
        var weeks: [String] = []
        var w = Days.weekStart(days[0])
        while w <= store.today { weeks.append(w); w = Days.add(w, 7) }
        return CardGroup(title: "限额执行",
                         headline: true, separatorInset: Theme.cellX + CGFloat(prefs.emojiSize) * 1.25 + 12) {
            if store.limits.isEmpty { LedgerRow(title: "还没有设置限额", style: .guide) }
            ForEach(store.limits) { limit in
                let cat = store.categories[limit.category]
                let counts = weeks.map { Ledger.weeklyCounts(store.entries, foods: store.foods, limits: [limit], day: $0)[0].count }
                let ok = counts.filter { $0 <= limit.maxCount }.count
                HStack(alignment: .center, spacing: 12) {
                    EmojiIcon(cat?.emoji ?? "")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cat?.name ?? limit.category).font(.gBody.weight(.semibold))
                            Spacer()
                            Amount(range == 7 ? "本周 \(counts.last ?? 0) / \(limit.maxCount) 次" : "\(ok) / \(weeks.count) 周在限额内")
                        }
                        if range == 7 {
                            Text("上限每周 \(limit.maxCount) 次").font(.gSmall).foregroundStyle(Theme.textMuted)
                        } else {
                            FlowLayout(spacing: 4, lineSpacing: 3) {
                                ForEach(Array(counts.enumerated()), id: \.offset) { _, c in
                                    let over = c > limit.maxCount
                                    Text(over ? "\(c)!" : "\(c)")
                                        .font(.gSmall.monospacedDigit().weight(over ? .bold : .regular))
                                        .foregroundStyle(over ? Theme.warnText : Theme.text)
                                        .frame(minWidth: 22)
                                        .padding(.vertical, 4)
                                        .background {
                                            RoundedRectangle(cornerRadius: 4).fill(over ? Color.clear : Theme.fill)
                                            if over { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.warn, lineWidth: 1.5) }
                                        }
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("各周次数：\(counts.map(String.init).joined(separator: "、"))")
                        }
                    }
                }
                .padding(.horizontal, Theme.cellX)
                .padding(.vertical, Theme.cellY)
            }
        }
    }
}

// MARK: 热力图

private struct HeatmapCard: View {
    @Environment(AppStore.self) private var store
    let days: [String]
    let totals: [String: Totals]
    let outliers: Set<String>
    let thresholds: [Double]
    @Binding var picked: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grid
            legend.padding(.top, 12)
            caption.padding(.top, 12)
        }
        .padding(.horizontal, Theme.cellX)
        .padding(.vertical, 16)
    }

    @ViewBuilder private var grid: some View {
        if days.count <= 7 {
            HStack(spacing: 8) { ForEach(days, id: \.self) { cell($0).frame(maxWidth: 44) } }
        } else {
            let start = Days.weekStart(days[0])
            let end = Days.add(Days.weekStart(days[days.count - 1]), 6)
            let cols = (Days.diff(end, start) + 1) / 7
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) {
                    ForEach(Array(["一", "", "三", "", "五", "", "日"].enumerated()), id: \.offset) { _, t in
                        Text(t).font(.gSmall).foregroundStyle(Theme.textMuted).frame(maxHeight: .infinity)
                    }
                }
                .accessibilityHidden(true)
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { c in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { r in
                                let d = Days.add(start, c * 7 + r)
                                if d < days[0] || d > days[days.count - 1] {
                                    Color.clear.aspectRatio(1, contentMode: .fit)
                                } else {
                                    cell(d)
                                }
                            }
                        }
                        .frame(maxWidth: cols <= 6 ? 38 : 26)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cell(_ d: String) -> some View {
        let v = totals[d]?.sat
        let isOut = outliers.contains(d)
        let level = v == nil ? 0 : max(1, Ledger.heatLevel(v ?? 0, thresholds: thresholds))
        return Button { picked = d } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.heat(level))
                .overlay { if isOut { Stripes().clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous)) } }
                .overlay { if picked == d { RoundedRectangle(cornerRadius: 5).stroke(Theme.text, lineWidth: 2).padding(-1.5) } }
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Days.label(d))，\(v.map { "饱和脂肪\(Fmt.sat($0))" } ?? "没有记录")\(isOut ? "，离群日" : "")")
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("少")
            ForEach(1...5, id: \.self) { RoundedRectangle(cornerRadius: 3).fill(Theme.heat($0)).frame(width: 12, height: 12) }
            Text("多")
            RoundedRectangle(cornerRadius: 3).fill(Theme.heat(2)).overlay { Stripes().clipShape(RoundedRectangle(cornerRadius: 3)) }
                .frame(width: 12, height: 12).padding(.leading, 8)
            Text("离群日")
        }
        .font(.gSmall)
        .foregroundStyle(Theme.textMuted)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var caption: some View {
        if let p = picked, days.contains(p) {
            HStack(spacing: 8) {
                Text("\(Days.label(p))：\(totals[p].map { "饱和脂肪\(Fmt.sat($0.sat))" } ?? "没有记录")\(outliers.contains(p) ? " · 离群日" : "")")
                Button("查看这天") {
                    store.setDay(p)
                    store.tab = .today
                }
                .font(.gSmall.weight(.medium))
                .foregroundStyle(Theme.accent)
            }
            .font(.gSmall)
            .foregroundStyle(Theme.textMuted)
            .frame(minHeight: 36, alignment: .leading)
        } else {
            Text("颜色深浅按你自己的分布分成五档，不用固定阈值。点一格查看当天。")
                .font(.gSmall)
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(2)
                .frame(minHeight: 36, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 离群日的斜纹。
private struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 4.5
            }
            ctx.stroke(p, with: .color(Theme.text), lineWidth: 1.4)
        }
        .allowsHitTesting(false)
    }
}

// MARK: 趋势

private struct TrendChart: View {
    let days: [String]
    let totals: [String: Totals]
    let allTotals: [String: Totals]
    let outliers: Set<String>
    let exclude: Bool
    let budget: Double

    private struct Point: Identifiable {
        var date: Date
        var value: Double
        var id: Date { date }
    }

    var body: some View {
        let pts = days.compactMap { d -> Point? in
            guard let v = totals[d]?.sat, !(exclude && outliers.contains(d)) else { return nil }
            return Point(date: Days.date(d), value: v)
        }
        let base = days.compactMap { d in
            Ledger.baseline(allTotals, outliers: outliers, beforeDay: Days.add(d, 1)).map { Point(date: Days.date(d), value: $0.sat) }
        }
        VStack(alignment: .leading, spacing: 8) {
            if pts.count < 2 {
                Text("记录满两天后，这里会画出日支出折线。").font(.gSmall).foregroundStyle(Theme.textMuted)
            } else {
                let mean = pts.reduce(0) { $0 + $1.value } / Double(pts.count)
                let maxV = max(budget, pts.map(\.value).max() ?? 0, base.map(\.value).max() ?? 0) * 1.08
                Chart {
                    RuleMark(y: .value("预算", budget))
                        .foregroundStyle(Theme.warn)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 4) {
                            Text("预算 \(Fmt.number(budget)) g").font(.gSmall.weight(.medium)).foregroundStyle(Theme.warnText)
                        }
                    if base.count > 1 {
                        ForEach(base) { p in
                            LineMark(x: .value("日期", p.date), y: .value("水位", p.value), series: .value("系列", "水位"))
                                .foregroundStyle(Theme.textMuted)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4]))
                        }
                    }
                    ForEach(pts) { p in
                        LineMark(x: .value("日期", p.date), y: .value("饱和脂肪", p.value), series: .value("系列", "日支出"))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        if days.count <= 31 {
                            PointMark(x: .value("日期", p.date), y: .value("饱和脂肪", p.value))
                                .foregroundStyle(Theme.accent)
                                .symbolSize(18)
                        }
                    }
                }
                .chartYScale(domain: 0...maxV)
                .chartXScale(domain: Days.date(days[0])...Days.date(days[days.count - 1]))
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: [Days.date(days[0]), Days.date(days[days.count - 1])]) { v in
                        AxisValueLabel(anchor: v.index == 0 ? .topLeading : .topTrailing) {
                            if let d = v.as(Date.self) { Text(Days.label(Days.day(of: d))).font(.gSmall) }
                        }
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("饱和脂肪日支出折线。\(pts.count) 个记录日，日均\(Fmt.sat(mean))，预算 \(Fmt.number(budget)) g。")
                HStack(spacing: 16) {
                    legend("日支出", Theme.accent, dash: [])
                    legend("14 天水位", Theme.textMuted, dash: [2, 4])
                    legend("预算", Theme.warn, dash: [6, 4])
                }
                .font(.gSmall)
                .foregroundStyle(Theme.textMuted)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.cellX)
        .padding(.vertical, 16)
    }

    private func legend(_ text: String, _ color: Color, dash: [CGFloat]) -> some View {
        HStack(spacing: 8) {
            Path { p in p.move(to: CGPoint(x: 0, y: 4)); p.addLine(to: CGPoint(x: 22, y: 4)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dash))
                .frame(width: 22, height: 8)
            Text(text)
        }
    }
}
