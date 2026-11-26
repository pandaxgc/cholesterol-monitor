import LipidDomain
import SwiftData
import SwiftUI

@main
struct CholesterolMonitorApp: App {
    @State private var store: AppStore
    @State private var prefs: Prefs
    @State private var router = Router()
    private let container: ModelContainer

    init() {
        let args = ProcessInfo.processInfo.arguments
        // 界面测试：内存数据库与独立的偏好，不碰真实数据
        let testing = args.contains("-uiTesting")
        let defaults: UserDefaults
        if testing, let suite = UserDefaults(suiteName: "ui-testing") {
            suite.removePersistentDomain(forName: "ui-testing")
            defaults = suite
        } else {
            defaults = .standard
        }
        do {
            container = try Persistence.makeContainer(inMemory: testing)
        } catch {
            // 数据库无法打开时退回内存库，避免启动即崩溃；界面会提示
            container = try! Persistence.makeContainer(inMemory: true)
        }
        let store = AppStore(container: container)
        let prefs = Prefs(defaults: defaults)
        if testing {
            if args.contains("-demo") { store.reset(.demo) }
            if args.contains("-ack") { prefs.ack = true }
            if let i = args.firstIndex(of: "-appearance"), i + 1 < args.count, let a = Appearance(rawValue: args[i + 1]) { prefs.appearance = a }
            if let i = args.firstIndex(of: "-range"), i + 1 < args.count, let r = Int(args[i + 1]) { prefs.range = r }
        }
        _store = State(initialValue: store)
        _prefs = State(initialValue: prefs)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(prefs)
                .environment(router)
        }
        .modelContainer(container)
    }
}
