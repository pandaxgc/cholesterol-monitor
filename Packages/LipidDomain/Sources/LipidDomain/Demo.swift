// 示例数据生成器：按日期确定性生成，所有条目带 demo 标记。
import Foundation

public enum Demo {
    public static let days = 90

    public enum Mode: Sendable {
        /// 全天
        case full
        /// 只有早餐与午餐（当天晚间待补记）
        case partial
        /// 只补晚餐与加餐
        case rest
    }

    typealias Item = (food: String, serving: String, multiplier: Double)

    /// 以字符串为种子的确定性随机数（FNV-1a 取种，mulberry32 生成）。
    struct RNG {
        private var a: UInt32

        init(seed: String) {
            var h: UInt32 = 2_166_136_261
            for u in seed.utf16 {
                h ^= UInt32(u)
                h = h &* 16_777_619
            }
            a = h
        }

        mutating func next() -> Double {
            a = a &+ 0x6d2b_79f5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }

        mutating func pick<T>(_ options: [(Double, T)]) -> T {
            var x = next() * options.reduce(0) { $0 + $1.0 }
            for o in options {
                x -= o.0
                if x <= 0 { return o.1 }
            }
            return options[options.count - 1].1
        }
    }

    private static func i(_ food: String, _ serving: String, _ multiplier: Double = 1) -> Item { (food, serving, multiplier) }

    private static let lunch: [(Double, [Item])] = [
        (12, [i("rice", "中碗"), i("braised_pork", "中碗"), i("stir_fried_greens", "小碗")]),
        (20, [i("rice_bowl", "一份")]),
        (18, [i("rice", "中碗"), i("kung_pao_chicken", "小碗"), i("stir_fried_greens", "小碗")]),
        (12, [i("beef_noodle", "碗")]),
        (15, [i("rice", "中碗"), i("tomato_egg", "小碗"), i("broccoli", "小碗")]),
        (10, [i("dumplings", "一盘")]),
        (8, [i("rice", "中碗"), i("yuxiang_pork", "小碗")]),
        (5, [i("burger", "个"), i("french_fries", "中份")]),
    ]
    private static let dinnerMain: [(Double, Item)] = [
        (20, i("steamed_fish", "手掌大小")), (18, i("pepper_pork", "小碗")), (15, i("mapo_tofu", "中碗")),
        (12, i("spare_ribs", "小碗")), (10, i("chicken_breast", "手掌大小")), (10, i("pork_belly", "小碗")),
        (8, i("sour_fish", "小碗")), (4, i("pork_liver", "小碗")), (3, i("shrimp", "小碗")),
    ]
    private static let dinnerVeg: [(Double, Item?)] = [
        (50, i("stir_fried_greens", "小碗")), (25, i("broccoli", "小碗")), (15, i("cucumber_salad", "小碗")), (10, nil),
    ]
    private static let outing: [(Double, Item)] = [(45, i("hotpot_tallow", "正常")), (35, i("bbq", "正常")), (20, i("banquet", "正常"))]

    public static func day(_ day: String, foods: [String: Food], mode: Mode = .full) -> (entries: [Entry], outlier: Bool) {
        var r = RNG(seed: "demo:\(day)")
        let wd = Days.weekday(day)
        let weekend = wd == 0 || wd == 6
        var plan: [Meal: [Item]] = [:]
        let src: [Meal: EntrySource] = [.breakfast: .prefill, .lunch: .search, .dinner: .search, .snack: .oneTouch]

        let b = r.next()
        if b < 0.72 { plan[.breakfast] = [i("boiled_egg", "个"), i("oat_porridge", "中碗")] }
        else if b < 0.82 { plan[.breakfast] = [i("pork_bun", "个", 2), i("soy_milk", "杯")] }
        else if b < 0.9 { plan[.breakfast] = [i("youtiao", "根"), i("soy_milk", "杯")] }
        else if b < 0.96 { plan[.breakfast] = [i("whole_wheat_bread", "片", 2), i("whole_milk", "杯")] }

        plan[.lunch] = r.pick(lunch)

        let isOuting = weekend && r.next() < 0.22
        var dinner: [Item] = []
        if isOuting {
            dinner.append(r.pick(outing))
        } else {
            if r.next() < 0.85 { dinner.append(i("rice", r.next() < 0.5 ? "小碗" : "中碗")) }
            dinner.append(r.pick(dinnerMain))
            if let veg = r.pick(dinnerVeg) { dinner.append(veg) }
        }
        plan[.dinner] = dinner

        let s = r.next()
        if s < 0.3 { plan[.snack] = [i("apple", "个")] }
        else if s < 0.42 { plan[.snack] = [i("yogurt", "小盒")] }
        else if s < 0.5 { plan[.snack] = [i("walnut", "一小把")] }
        else if s < 0.6 { plan[.snack] = [i("bubble_tea", "中杯")] }
        else if s < 0.66 { plan[.snack] = [i("biscuit", "小包")] }
        else if s < 0.69 { plan[.snack] = [i("cream_cake", "块")] }

        switch mode {
        case .full: break
        case .partial:
            plan = [.breakfast: [i("boiled_egg", "个"), i("oat_porridge", "中碗")], .lunch: [i("braised_pork", "中碗"), i("rice", "中碗")]]
        case .rest:
            plan[.breakfast] = []
            plan[.lunch] = []
        }

        // 记录时间固定为当天 21:40 起（东八区），与日期一样是确定的
        let base = Double(Days.epochDay(day)) * 86400 + (21 - 8) * 3600
        var entries: [Entry] = []
        var n = 0
        for meal in Meal.allCases {
            for item in plan[meal] ?? [] {
                guard let serving = foods[item.food]?.serving(item.serving) else {
                    preconditionFailure("demo: 未知量具 \(item.food)/\(item.serving)")
                }
                entries.append(Entry(
                    id: "demo_\(day)_\(meal.rawValue)_\(n)", day: day, meal: meal, foodId: item.food, servingLabel: item.serving,
                    multiplier: item.multiplier, grams: serving.grams * item.multiplier, source: src[meal] ?? .search,
                    createdAt: Date(timeIntervalSince1970: base + Double(40 + n % 15) * 60), demo: true))
                n += 1
            }
        }
        return (entries, mode != .partial && isOuting)
    }

    public static func labs(today: String) -> [LabResult] {
        [
            LabResult(id: "lab_demo_1", date: Days.add(today, -88), tc: 6.1, ldlC: 4.1, hdlC: 1.1, tg: 1.9, note: "示例", demo: true),
            LabResult(id: "lab_demo_2", date: Days.add(today, -5), tc: 5.6, ldlC: 3.6, hdlC: 1.2, tg: 1.6, note: "示例", demo: true),
        ]
    }

    public static let oneTouch: [OneTouch] = [
        OneTouch(id: "ot_demo_1", foodId: "boiled_egg", servingLabel: "个", multiplier: 1, meal: .breakfast, sortOrder: 0),
        OneTouch(id: "ot_demo_2", foodId: "oat_porridge", servingLabel: "中碗", multiplier: 1, meal: .breakfast, sortOrder: 1),
        OneTouch(id: "ot_demo_3", foodId: "rice", servingLabel: "中碗", multiplier: 1, meal: .lunch, sortOrder: 2),
        OneTouch(id: "ot_demo_4", foodId: "rice", servingLabel: "小碗", multiplier: 1, meal: .dinner, sortOrder: 3),
        OneTouch(id: "ot_demo_5", foodId: "apple", servingLabel: "个", multiplier: 1, meal: .snack, sortOrder: 4),
        OneTouch(id: "ot_demo_6", foodId: "soy_milk", servingLabel: "杯", multiplier: 1, meal: .breakfast, sortOrder: 5),
    ]
}
