// SwiftData 持久化模型。每个模型对应领域层的一个值类型，全部数据只存在本机。
import Foundation
import LipidDomain
import SwiftData

/// 与领域值类型一一对应的持久化记录。
nonisolated protocol ValueRecord: PersistentModel {
    associatedtype Value
    static func key(of value: Value) -> String
    init(_ value: Value)
    func apply(_ value: Value)
    var value: Value { get }
}

@Model nonisolated final class EntryRecord: ValueRecord {
    @Attribute(.unique) var id: String
    var day: String
    var meal: String
    var foodId: String
    var servingLabel: String
    var multiplier: Double
    var grams: Double
    var photoRef: String?
    var source: String
    var createdAt: Date
    var demo: Bool

    static func key(of value: Entry) -> String { value.id }

    init(_ e: Entry) {
        id = e.id
        day = e.day
        meal = e.meal.rawValue
        foodId = e.foodId
        servingLabel = e.servingLabel
        multiplier = e.multiplier
        grams = e.grams
        photoRef = e.photoRef
        source = e.source.rawValue
        createdAt = e.createdAt
        demo = e.demo
    }

    func apply(_ e: Entry) {
        day = e.day
        meal = e.meal.rawValue
        foodId = e.foodId
        servingLabel = e.servingLabel
        multiplier = e.multiplier
        grams = e.grams
        photoRef = e.photoRef
        source = e.source.rawValue
        createdAt = e.createdAt
        demo = e.demo
    }

    var value: Entry {
        Entry(id: id, day: day, meal: Meal(rawValue: meal) ?? .snack, foodId: foodId, servingLabel: servingLabel, multiplier: multiplier,
              grams: grams, photoRef: photoRef, source: EntrySource(rawValue: source) ?? .search, createdAt: createdAt, demo: demo)
    }
}

@Model nonisolated final class OneTouchRecord: ValueRecord {
    @Attribute(.unique) var id: String
    var foodId: String
    var servingLabel: String
    var multiplier: Double
    var meal: String
    var sortOrder: Int

    static func key(of value: OneTouch) -> String { value.id }

    init(_ o: OneTouch) {
        id = o.id
        foodId = o.foodId
        servingLabel = o.servingLabel
        multiplier = o.multiplier
        meal = o.meal.rawValue
        sortOrder = o.sortOrder
    }

    func apply(_ o: OneTouch) {
        foodId = o.foodId
        servingLabel = o.servingLabel
        multiplier = o.multiplier
        meal = o.meal.rawValue
        sortOrder = o.sortOrder
    }

    var value: OneTouch {
        OneTouch(id: id, foodId: foodId, servingLabel: servingLabel, multiplier: multiplier, meal: Meal(rawValue: meal) ?? .snack, sortOrder: sortOrder)
    }
}

/// 限额带一个排序序号，保持添加顺序。
nonisolated struct StoredLimit {
    var limit: CountLimit
    var sortOrder: Int
}

@Model nonisolated final class LimitRecord: ValueRecord {
    @Attribute(.unique) var id: String
    var category: String
    var period: String
    var maxCount: Int
    var sortOrder: Int

    static func key(of value: StoredLimit) -> String { value.limit.id }

    init(_ v: StoredLimit) {
        id = v.limit.id
        category = v.limit.category
        period = v.limit.period
        maxCount = v.limit.maxCount
        sortOrder = v.sortOrder
    }

    func apply(_ v: StoredLimit) {
        category = v.limit.category
        period = v.limit.period
        maxCount = v.limit.maxCount
        sortOrder = v.sortOrder
    }

    var value: StoredLimit {
        StoredLimit(limit: CountLimit(id: id, category: category, period: period, maxCount: maxCount), sortOrder: sortOrder)
    }
}

nonisolated struct DayMeta: Codable {
    var day: String
    var isOutlier: Bool
    var demo = false
}

@Model nonisolated final class DayMetaRecord: ValueRecord {
    @Attribute(.unique) var day: String
    var isOutlier: Bool
    var demo: Bool

    static func key(of value: DayMeta) -> String { value.day }

    init(_ m: DayMeta) {
        day = m.day
        isOutlier = m.isOutlier
        demo = m.demo
    }

    func apply(_ m: DayMeta) {
        isOutlier = m.isOutlier
        demo = m.demo
    }

    var value: DayMeta { DayMeta(day: day, isOutlier: isOutlier, demo: demo) }
}

@Model nonisolated final class LabRecord: ValueRecord {
    @Attribute(.unique) var id: String
    var date: String
    var tc: Double?
    var ldlC: Double?
    var hdlC: Double?
    var tg: Double?
    var unit: String
    var note: String
    var demo: Bool

    static func key(of value: LabResult) -> String { value.id }

    init(_ l: LabResult) {
        id = l.id
        date = l.date
        tc = l.tc
        ldlC = l.ldlC
        hdlC = l.hdlC
        tg = l.tg
        unit = l.unit
        note = l.note
        demo = l.demo
    }

    func apply(_ l: LabResult) {
        date = l.date
        tc = l.tc
        ldlC = l.ldlC
        hdlC = l.hdlC
        tg = l.tg
        unit = l.unit
        note = l.note
        demo = l.demo
    }

    var value: LabResult {
        LabResult(id: id, date: date, tc: tc, ldlC: ldlC, hdlC: hdlC, tg: tg, unit: unit, note: note, demo: demo)
    }
}

/// 某天给出的建议，用于“同一条建议 7 天内不重复”。
nonisolated struct AdviceLog: Codable {
    var day: String
    var key: String
}

@Model nonisolated final class AdviceLogRecord: ValueRecord {
    @Attribute(.unique) var day: String
    var key: String

    static func key(of value: AdviceLog) -> String { value.day }

    init(_ a: AdviceLog) {
        day = a.day
        key = a.key
    }

    func apply(_ a: AdviceLog) { key = a.key }

    var value: AdviceLog { AdviceLog(day: day, key: key) }
}

nonisolated struct AppSettings: Codable, Equatable {
    var budgetMode: BudgetMode = .standard
    var reminderEnabled = false
    var reminderTime = "21:30"
    /// 当前是否为示例数据
    var demo = false
    /// 示例数据已生成到哪一天
    var demoAnchor: String?
    /// 份量校准：食物 id → 量具 → 克数
    var servingOverrides: [String: [String: Double]] = [:]
}

@Model nonisolated final class SettingsRecord: ValueRecord {
    @Attribute(.unique) var id: String
    var json: Data

    static let mainKey = "main"
    static func key(of value: AppSettings) -> String { mainKey }

    init(_ s: AppSettings) {
        id = Self.mainKey
        json = (try? JSONEncoder().encode(s)) ?? Data()
    }

    func apply(_ s: AppSettings) { json = (try? JSONEncoder().encode(s)) ?? Data() }

    var value: AppSettings { (try? JSONDecoder().decode(AppSettings.self, from: json)) ?? AppSettings() }
}

enum Persistence {
    static let schema = Schema([EntryRecord.self, OneTouchRecord.self, LimitRecord.self, DayMetaRecord.self, LabRecord.self, AdviceLogRecord.self, SettingsRecord.self])

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)])
    }
}

/// 一张表在内存里的索引：按主键找记录，写入时新增或更新。
@MainActor final class Table<R: ValueRecord> {
    private let context: ModelContext
    private var records: [String: R] = [:]

    init(_ context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        records = [:]
        for r in (try? context.fetch(FetchDescriptor<R>())) ?? [] { records[R.key(of: r.value)] = r }
    }

    var values: [R.Value] { records.values.map(\.value) }
    func get(_ key: String) -> R.Value? { records[key]?.value }

    func put(_ value: R.Value) {
        let key = R.key(of: value)
        if let r = records[key] { r.apply(value) } else {
            let r = R(value)
            context.insert(r)
            records[key] = r
        }
    }

    func delete(_ key: String) {
        if let r = records.removeValue(forKey: key) { context.delete(r) }
    }

    func clear() {
        for r in records.values { context.delete(r) }
        records = [:]
    }
}
