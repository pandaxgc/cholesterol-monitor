import LipidDomain
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        @Bindable var router = router
        TabView(selection: $store.tab) {
            Tab("今日", image: Icon.asset("doc.text.fill"), value: AppTab.today) { TodayView() }
            Tab("清单", image: Icon.asset("list.bullet"), value: AppTab.lists) { ListsView() }
            Tab("分析", image: Icon.asset("chart.bar.fill"), value: AppTab.analysis) { AnalysisView() }
            Tab("化验", image: Icon.asset("flask.fill"), value: AppTab.labs) { LabsView() }
        }
        .tint(Theme.accent)
        .font(.gBody)
        .sheet(item: $router.sheet) { route in
            SheetView(route: route)
                .environment(store)
                .environment(prefs)
                .environment(router)
        }
        .preferredColorScheme(prefs.colorScheme(at: store.now))
        .onAppear {
            Haptics.enabled = prefs.haptics
            ToastCenter.shared.colorScheme = colorScheme
            if !prefs.ack { router.sheet = .disclaimer(firstRun: true) }
            reschedule()
        }
        .onChange(of: colorScheme) { ToastCenter.shared.colorScheme = colorScheme }
        .onChange(of: prefs.haptics) { Haptics.enabled = prefs.haptics }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                store.tick()
                reschedule()
            }
        }
        .onChange(of: store.entries) { reschedule() }
        .onChange(of: store.settings.reminderEnabled) { reschedule() }
        .onChange(of: store.settings.reminderTime) { reschedule() }
        .onReceive(clock) { _ in store.tick() }
        .alert("出错了", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private func reschedule() {
        let todayEntries = store.entries(on: store.today)
        let full = Meal.main.allSatisfy { m in todayEntries.contains { $0.meal == m } }
        Reminders.reschedule(enabled: store.settings.reminderEnabled, time: store.settings.reminderTime, skipToday: full)
    }
}

/// 顶层面板的内容。
struct SheetView: View {
    let route: SheetRoute

    var body: some View {
        Group {
            switch route {
            case .settings: SettingsView()
            case .add(let meal, let focus): AddPanelView(initialMeal: meal, focusSearch: focus)
            case .oneTouch: OneTouchView()
            case .sources: SourcesSheet()
            case .limits: LimitsSheet()
            case .why(let a): WhySheet(advice: a)
            case .dayMenu: DayMenuSheet()
            case .entryMenu(let e): EntryMenuSheet(entry: e)
            case .keypad(let k): KeypadView(request: k)
            case .foodDetail(let id): SheetNav(title: nil) { FoodDetailView(foodId: id) }
            case .entryList(let r): EntryListSheet(request: r)
            case .category(let id): CategorySheet(categoryId: id)
            case .labForm(let lab): LabFormView(lab: lab)
            case .disclaimer(let first): DisclaimerSheet(firstRun: first)
            }
        }
        .presentationBackground(Theme.bg)
        .presentationCornerRadius(32)
    }
}

/// 面板外壳：居中的行内标题，右上角“完成”。
struct SheetNav<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    var title: String?
    var doneLabel = "完成"
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(doneLabel) { dismiss() }
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("sheet-done")
                    }
                }
                .background(Theme.bg)
        }
    }
}
