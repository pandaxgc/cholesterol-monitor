// 面板路由：同一时间只有一个顶层面板；面板内部再弹出的份量键盘由面板自己管理。
import LipidDomain
import Observation
import SwiftUI

struct KeypadRequest: Identifiable {
    let id = UUID()
    var food: Food
    var meal: Meal
    /// 编辑已有记录时不为空
    var entry: Entry?
}

struct EntryListRequest {
    var title: String
    var entries: [Entry]
    var emptyText: String
}

enum SheetRoute: Identifiable {
    case settings
    case add(meal: Meal?, focusSearch: Bool)
    case oneTouch
    case sources
    case limits
    case why(Advice)
    case dayMenu
    case entryMenu(Entry)
    case keypad(KeypadRequest)
    case foodDetail(String)
    case entryList(EntryListRequest)
    case category(String)
    case labForm(LabResult?)
    case disclaimer(firstRun: Bool)

    var id: String {
        switch self {
        case .settings: "settings"
        case .add: "add"
        case .oneTouch: "oneTouch"
        case .sources: "sources"
        case .limits: "limits"
        case .why(let a): "why:\(a.key)"
        case .dayMenu: "dayMenu"
        case .entryMenu(let e): "entryMenu:\(e.id)"
        case .keypad(let k): "keypad:\(k.id)"
        case .foodDetail(let f): "food:\(f)"
        case .entryList(let r): "list:\(r.title)"
        case .category(let c): "category:\(c)"
        case .labForm(let l): "lab:\(l?.id ?? "new")"
        case .disclaimer: "disclaimer"
        }
    }
}

@MainActor @Observable final class Router {
    var sheet: SheetRoute? {
        didSet { ToastCenter.shared.atTop = sheet != nil }
    }

    /// 本次打开 App 后已经给过“今日已记完”反馈的日子
    var celebrated: Set<String> = []

    /// 先关掉当前面板，再打开下一个。
    func replace(with next: SheetRoute) {
        guard sheet != nil else { sheet = next; return }
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            sheet = next
        }
    }
}
