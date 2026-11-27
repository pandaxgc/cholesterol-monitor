// 显示与反馈偏好：只存在这台设备上（UserDefaults）。
import Foundation
import Observation
import SwiftUI

enum Appearance: String, CaseIterable {
    case system, light, dark
}

enum Hand: String {
    case left, right
}

@MainActor @Observable final class Prefs {
    @ObservationIgnored private let defaults: UserDefaults

    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var autoDark20: Bool { didSet { defaults.set(autoDark20, forKey: "autoDark20") } }
    /// 食物 Emoji 大小：24 / 28 / 34
    var emojiSize: Int { didSet { defaults.set(emojiSize, forKey: "emojiSize") } }
    var hand: Hand { didSet { defaults.set(hand.rawValue, forKey: "hand") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    /// 已读过首次启动的免责声明
    var ack: Bool { didSet { defaults.set(ack, forKey: "ack") } }
    /// 分析页的时间范围：7 / 30 / 90
    var range: Int { didSet { defaults.set(range, forKey: "range") } }
    var excludeOutliers: Bool { didSet { defaults.set(excludeOutliers, forKey: "excludeOutliers") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        autoDark20 = defaults.bool(forKey: "autoDark20")
        emojiSize = [24, 28, 34].contains(defaults.integer(forKey: "emojiSize")) ? defaults.integer(forKey: "emojiSize") : 28
        hand = Hand(rawValue: defaults.string(forKey: "hand") ?? "") ?? .right
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        ack = defaults.bool(forKey: "ack")
        range = [7, 30, 90].contains(defaults.integer(forKey: "range")) ? defaults.integer(forKey: "range") : 30
        excludeOutliers = defaults.object(forKey: "excludeOutliers") as? Bool ?? true
    }

    /// nil 表示跟随系统。
    func colorScheme(at date: Date) -> ColorScheme? {
        switch appearance {
        case .dark: return .dark
        case .light: return .light
        case .system:
            let hour = Calendar.current.component(.hour, from: date)
            return autoDark20 && (hour >= 20 || hour < 6) ? .dark : nil
        }
    }
}

@MainActor enum Haptics {
    static var enabled = true

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
