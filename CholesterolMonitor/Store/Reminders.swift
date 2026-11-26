// 晚间提醒（PRD §10）：本地通知，每日最多 1 条。
import Foundation
import LipidDomain
import UserNotifications

enum Reminders {
    static let body = "今天的账记一下？"
    private static let prefix = "reminder."
    /// 以最近一次打开为第 0 天：前 3 天每天 1 条；连续 3 天未打开后改为每 3 天 1 条；再 7 天未打开则停止。
    private static let offsets = [0, 1, 2, 3, 6, 9]

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// 每次打开或记录变化后重排。`skipToday`：当天已记满三餐则不提醒。
    static func reschedule(enabled: Bool, time: String, skipToday: Bool, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: offsets.map { "\(prefix)\($0)" })
        guard enabled else { return }
        let hm = time.split(separator: ":").compactMap { Int($0) }
        guard hm.count == 2 else { return }
        let cal = Days.gregorian
        let start = Days.date(Days.logicalDay(now))
        for offset in offsets where !(offset == 0 && skipToday) {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            var c = cal.dateComponents([.calendar, .timeZone, .year, .month, .day], from: day)
            c.hour = hm[0]
            c.minute = hm[1]
            guard let fire = cal.date(from: c), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "血脂账本"
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "\(prefix)\(offset)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
    }
}
