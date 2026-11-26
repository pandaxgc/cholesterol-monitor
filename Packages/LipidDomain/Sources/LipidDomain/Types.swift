// 领域类型：全部为值类型，不依赖 UI 与存储（PRD §7.2）。
import Foundation

public enum Meal: String, CaseIterable, Codable, Sendable, Identifiable {
    case breakfast, lunch, dinner, snack

    public static let main: [Meal] = [.breakfast, .lunch, .dinner]
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        }
    }
}

public enum BudgetMode: String, Codable, Sendable {
    case standard, strict
}

public enum Budget {
    public static let satStandard = 22.0
    public static let satStrict = 11.0
    public static let cholMg = 300.0
    public static let fiberG = 10.0
    public static let transMaxG = 2.0

    public static func sat(_ mode: BudgetMode) -> Double {
        mode == .strict ? satStrict : satStandard
    }
}

public let maxOneTouch = 12

public enum Grade: String, Sendable {
    case a = "A", b = "B", c = "C"

    public var label: String {
        switch self {
        case .a: "友好"
        case .b: "适量"
        case .c: "留意"
        }
    }
}

public struct Nutrition: Equatable, Sendable {
    public var satFatG: Double
    public var transFatG: Double
    public var cholesterolMg: Double
    public var solubleFiberG: Double

    public init(satFatG: Double, transFatG: Double, cholesterolMg: Double, solubleFiberG: Double = 0) {
        self.satFatG = satFatG
        self.transFatG = transFatG
        self.cholesterolMg = cholesterolMg
        self.solubleFiberG = solubleFiberG
    }

    public var grade: Grade {
        if satFatG >= 5 || transFatG > 0.1 || cholesterolMg >= 100 { return .c }
        if satFatG >= 2 { return .b }
        return .a
    }
}

public struct Serving: Equatable, Sendable {
    public var label: String
    public var grams: Double

    public init(label: String, grams: Double) {
        self.label = label
        self.grams = grams
    }
}

/// 替代食物：沿用类别的映射、明确没有、或指定某个食物。
public enum Swap: Equatable, Sendable {
    case inherit
    case none
    case food(String)
}

public struct Food: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    public var category: String
    public var aliases: [String]
    public var nutritionPer100g: Nutrition
    public var servings: [Serving]
    public var defaultServing: Int
    public var swap: Swap
    public var source: String
    public var dataVersion: String

    public var grade: Grade { nutritionPer100g.grade }
    public var defaultServingValue: Serving { servings[defaultServing] }

    public func serving(_ label: String) -> Serving? {
        servings.first { $0.label == label }
    }
}

public struct FoodCategory: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var short: String
    public var emoji: String
    public var swap: String?
}

public enum EntrySource: String, Codable, Sendable {
    case prefill, oneTouch, photo, search
}

/// 一条记录一个食物，相当于一笔交易。`day` 为 `yyyy-MM-dd`。
public struct Entry: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var day: String
    public var meal: Meal
    public var foodId: String
    public var servingLabel: String
    public var multiplier: Double
    public var grams: Double
    public var photoRef: String?
    public var source: EntrySource
    public var createdAt: Date
    public var demo: Bool

    public init(id: String, day: String, meal: Meal, foodId: String, servingLabel: String, multiplier: Double, grams: Double,
                photoRef: String? = nil, source: EntrySource, createdAt: Date, demo: Bool = false) {
        self.id = id
        self.day = day
        self.meal = meal
        self.foodId = foodId
        self.servingLabel = servingLabel
        self.multiplier = multiplier
        self.grams = grams
        self.photoRef = photoRef
        self.source = source
        self.createdAt = createdAt
        self.demo = demo
    }
}

public struct OneTouch: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var foodId: String
    public var servingLabel: String
    public var multiplier: Double
    public var meal: Meal
    public var sortOrder: Int

    public init(id: String, foodId: String, servingLabel: String, multiplier: Double, meal: Meal, sortOrder: Int) {
        self.id = id
        self.foodId = foodId
        self.servingLabel = servingLabel
        self.multiplier = multiplier
        self.meal = meal
        self.sortOrder = sortOrder
    }
}

public struct CountLimit: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var category: String
    public var period: String
    public var maxCount: Int

    public init(id: String, category: String, period: String = "week", maxCount: Int) {
        self.id = id
        self.category = category
        self.period = period
        self.maxCount = maxCount
    }
}

public struct LabResult: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var date: String
    public var tc: Double?
    public var ldlC: Double?
    public var hdlC: Double?
    public var tg: Double?
    public var unit: String
    public var note: String
    public var demo: Bool

    public init(id: String, date: String, tc: Double? = nil, ldlC: Double? = nil, hdlC: Double? = nil, tg: Double? = nil,
                unit: String = "mmol/L", note: String = "", demo: Bool = false) {
        self.id = id
        self.date = date
        self.tc = tc
        self.ldlC = ldlC
        self.hdlC = hdlC
        self.tg = tg
        self.unit = unit
        self.note = note
        self.demo = demo
    }
}

/// 四项指标的合计（克、克、毫克、克）。
public struct Totals: Equatable, Sendable {
    public var sat = 0.0
    public var trans = 0.0
    public var chol = 0.0
    public var fiber = 0.0

    public init(sat: Double = 0, trans: Double = 0, chol: Double = 0, fiber: Double = 0) {
        self.sat = sat
        self.trans = trans
        self.chol = chol
        self.fiber = fiber
    }

    public static func += (a: inout Totals, b: Totals) {
        a.sat += b.sat
        a.trans += b.trans
        a.chol += b.chol
        a.fiber += b.fiber
    }
}

public struct SpendItem: Identifiable, Equatable, Sendable {
    public var entry: Entry
    public var food: Food
    public var n: Totals
    public var id: String { entry.id }
}

public struct DailySpend: Equatable, Sendable {
    public var total = Totals()
    public var meals: [Meal: Totals] = [:]
    public var items: [SpendItem] = []

    public func meal(_ m: Meal) -> Totals { meals[m] ?? Totals() }
}

public struct Baseline: Equatable, Sendable {
    public var sat: Double
    public var trans: Double
    public var chol: Double
    public var fiber: Double
    public var days: Int
}

public struct WeeklyCount: Identifiable, Equatable, Sendable {
    public var limit: CountLimit
    public var count: Int
    public var reached: Bool
    public var over: Bool
    public var id: String { limit.id }

    public init(limit: CountLimit, count: Int) {
        self.limit = limit
        self.count = count
        reached = count >= limit.maxCount
        over = count > limit.maxCount
    }
}

public struct SourceShare: Identifiable, Equatable, Sendable {
    public var category: String
    public var sat: Double
    public var share: Double
    public var id: String { category }
}

public struct MergeResult: Equatable, Sendable {
    public var merged: Bool
    public var entry: Entry
    public var previous: Entry?
}

public struct ServingChoice: Equatable, Sendable {
    public var servingLabel: String
    public var multiplier: Double

    public init(servingLabel: String, multiplier: Double) {
        self.servingLabel = servingLabel
        self.multiplier = multiplier
    }
}

public struct Prefill: Identifiable, Equatable, Sendable {
    public var foodId: String
    public var meal: Meal
    public var servingLabel: String
    public var multiplier: Double
    public var grams: Double
    public var id: String { "\(meal.rawValue)|\(foodId)" }
}

public struct FoodCount: Identifiable, Equatable, Sendable {
    public var foodId: String
    public var count: Int
    public var id: String { foodId }
}

public struct OneTouchSuggestion: Identifiable, Equatable, Sendable {
    public var foodId: String
    public var servingLabel: String
    public var multiplier: Double
    public var meal: Meal
    public var count: Int
    public var id: String { "\(foodId)|\(servingLabel)|\(multiplier)|\(meal.rawValue)" }
}

public struct Advice: Equatable, Sendable {
    public struct Record: Equatable, Sendable {
        public var name: String
        public var meal: String
        public var serving: String
        public var sat: String
    }

    public struct Why: Equatable, Sendable {
        public var records: [Record]
        public var calc: String
        public var source: String
    }

    public var key: String
    public var priority: Int
    public var text: String
    public var why: Why
}

public struct IntervalSummary: Equatable, Sendable {
    public var recordedDays: Int
    public var satMean: Double
    public var fiberShare: Double
    public var weeks: Int
    public var okWeeks: Int
}

extension Sequence {
    /// 稳定排序：相等的元素保持原有顺序。
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated().sorted { a, b in
            if areInIncreasingOrder(a.element, b.element) { return true }
            if areInIncreasingOrder(b.element, a.element) { return false }
            return a.offset < b.offset
        }.map(\.element)
    }
}
