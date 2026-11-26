// 日期：以 `yyyy-MM-dd` 字符串表示一天，按公历日运算，不受时区与夏令时影响。
import Foundation

public enum Days {
    static func epochDay(_ day: String) -> Int {
        let p = day.split(separator: "-").map { Int($0) ?? 0 }
        guard p.count == 3 else { return 0 }
        let y = p[1] <= 2 ? p[0] - 1 : p[0]
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (p[1] + (p[1] > 2 ? -3 : 9)) + 2) / 5 + p[2] - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func day(fromEpochDay n: Int) -> String {
        let z = n + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return format(y, m, d)
    }

    private static func format(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// 04:00 之前的记录归属前一天。
    public static func logicalDay(_ date: Date = Date(), cutoffHour: Int = 4, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date.addingTimeInterval(-Double(cutoffHour) * 3600))
        return format(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    public static func add(_ day: String, _ n: Int) -> String { self.day(fromEpochDay: epochDay(day) + n) }
    public static func diff(_ a: String, _ b: String) -> Int { epochDay(a) - epochDay(b) }

    /// 0 为周日，6 为周六。
    public static func weekday(_ day: String) -> Int { ((epochDay(day) + 4) % 7 + 7) % 7 }

    /// 自然周从周一开始。
    public static func weekStart(_ day: String) -> String { add(day, -((weekday(day) + 6) % 7)) }

    public static func label(_ day: String) -> String {
        let p = day.split(separator: "-").map { Int($0) ?? 0 }
        return p.count == 3 ? "\(p[1])月\(p[2])日" : day
    }

    /// 以 `end` 结尾的连续 `count` 天。
    public static func range(end: String, count: Int) -> [String] {
        (0..<max(0, count)).map { add(end, $0 - count + 1) }
    }

    public static func date(_ day: String, calendar: Calendar = .current) -> Date {
        let p = day.split(separator: "-").map { Int($0) ?? 0 }
        guard p.count == 3 else { return Date() }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date()
    }

    public static func day(of date: Date, calendar: Calendar = .current) -> String {
        logicalDay(date, cutoffHour: 0, calendar: calendar)
    }
}
