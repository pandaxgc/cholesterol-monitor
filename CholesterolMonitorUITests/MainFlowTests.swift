// 主要流程的界面测试。每个测试用内存数据库启动，互不影响。
// 设置环境变量 SCREENSHOT_DIR（xcodebuild 用 TEST_RUNNER_SCREENSHOT_DIR）时，把截图写到该目录。
import XCTest

@MainActor
final class MainFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(demo: Bool, ack: Bool = true, appearance: String = "light", extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-appearance", appearance] + (demo ? ["-demo"] : []) + (ack ? ["-ack"] : []) + extra
        app.launch()
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func waitFor(_ e: XCUIElement, _ timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "没有找到 \(e)", file: file, line: line)
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    private func scrollTo(_ e: XCUIElement, maxSwipes: Int = 8) {
        var n = 0
        while !e.isHittable && n < maxSwipes {
            app.swipeUp(velocity: .slow)
            n += 1
        }
    }

    private func toastText() -> String {
        let t = element("toast")
        _ = t.waitForExistence(timeout: 3)
        return t.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
    }

    // MARK: 首次启动

    func testFirstRunShowsDisclaimerAndStartsEmpty() {
        launch(demo: false, ack: false)
        let ack = element("ack-disclaimer")
        waitFor(ack)
        shot("01-disclaimer")
        ack.tap()
        XCTAssertFalse(element("demo-banner").exists, "首次启动应为空白数据")
        waitFor(element("guide-breakfast"))
        XCTAssertEqual(element("balance").label.contains("约 22 克"), true, element("balance").label)
    }

    // MARK: 份量键盘记一笔

    func testLogMealThroughKeypad() {
        launch(demo: false)
        element("fab-add").tap()
        let search = app.textFields["搜索食物，例如 红烧肉"]
        waitFor(search)
        search.tap()
        search.typeText("红烧肉")
        element("food-braised_pork").tap()
        waitFor(element("keypad-submit"))
        element("serving-小碗").tap()
        XCTAssertEqual(element("keypad-sat").label, "饱和脂肪约 7 克")
        shot("05-keypad")
        element("keypad-submit").tap()
        XCTAssertTrue(toastText().contains("已记入早餐：红烧肉"))
        // 添加面板提交后不关闭，餐次状态更新
        waitFor(element("add-status"))
        XCTAssertTrue(element("add-status").label.contains("早餐已记：红烧肉"), element("add-status").label)
        element("sheet-done").tap()
        waitFor(element("entry-breakfast-braised_pork"))
        XCTAssertTrue(element("balance").label.contains("约 15 克"), element("balance").label)
        // 再记一次同餐同食物：合并份量
        element("guide-lunch").tap()
        element("add-meal").buttons["早餐"].tap()
        let search2 = app.textFields["搜索食物，例如 红烧肉"]
        search2.tap()
        search2.typeText("东坡肉")
        element("food-braised_pork").tap()
        element("serving-小碗").tap()
        element("keypad-submit").tap()
        XCTAssertTrue(toastText().contains("已合并为"), toastText())
    }

    // MARK: One Touch

    func testOneTouchLogsAndUndoes() {
        launch(demo: true)
        element("fab-onetouch").tap()
        let tile = element("ot-apple-snack")
        waitFor(tile)
        shot("06-one-touch")
        tile.tap()
        XCTAssertTrue(toastText().contains("已记入加餐：苹果"), toastText())
        XCTAssertTrue(element("sheet-done").waitForExistence(timeout: 5), app.debugDescription)
        element("sheet-done").tap()
        waitFor(element("entry-snack-apple"))
        // 撤销
        element("fab-onetouch").tap()
        element("ot-rice-dinner").tap()
        XCTAssertTrue(toastText().contains("已记入晚餐：米饭"), toastText())
        element("toast-undo").tap()
        element("sheet-done").tap()
        XCTAssertFalse(element("entry-dinner-rice").waitForExistence(timeout: 1))
    }

    // MARK: 离群日

    func testMarkOutlierDay() {
        launch(demo: true)
        waitFor(element("advice"))
        element("day-menu").tap()
        waitFor(element("toggle-outlier"))
        shot("07-day-menu")
        element("toggle-outlier").tap()
        XCTAssertTrue(toastText().contains("已标记为离群日"))
        scrollTo(element("advice-outlier"))
        waitFor(element("advice-outlier"))
        XCTAssertTrue(element("day-menu").label.contains("离群日"), element("day-menu").label)
        XCTAssertTrue(element("balance").label.contains("今天是离群日，不计入日常水位"), element("balance").label)
    }

    // MARK: 载入示例数据

    func testLoadDemoDataFromSettings() {
        launch(demo: false)
        XCTAssertFalse(element("demo-banner").exists)
        element("open-settings").tap()
        let load = element("load-demo")
        waitFor(load)
        scrollTo(load)
        load.tap()
        app.alerts.buttons["载入示例"].firstMatch.tap()
        XCTAssertTrue(toastText().contains("已载入示例数据"))
        element("sheet-done").tap()
        waitFor(element("demo-banner"))
        waitFor(element("entry-lunch-braised_pork"))
        tab("化验")
        XCTAssertTrue(app.staticTexts["示例"].firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: 分析

    func testAnalysisRanges() {
        launch(demo: true)
        tab("分析")
        waitFor(element("analysis-summary"))
        XCTAssertTrue(element("analysis-summary").label.hasPrefix("过去 30 天"), element("analysis-summary").label)
        element("analysis-range").buttons["90 天"].tap()
        XCTAssertTrue(element("analysis-summary").label.hasPrefix("过去 90 天"))
        element("analysis-range").buttons["周"].tap()
        XCTAssertTrue(element("analysis-summary").label.hasPrefix("过去 7 天"))
    }

    // MARK: 化验录入

    func testLabEntry() {
        launch(demo: false)
        tab("化验")
        element("lab-add").tap()
        let save = element("lab-save")
        waitFor(save)
        save.tap()
        waitFor(element("lab-error"))
        XCTAssertEqual(element("lab-error").label, "至少填写一项化验值。")
        let ldl = element("lab-field-LDL-C")
        ldl.tap()
        ldl.typeText("35")
        save.tap()
        XCTAssertEqual(element("lab-error").label, "化验值应在 0 到 30 mmol/L 之间，请核对。")
        ldl.tap()
        ldl.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "3.4")
        element("lab-field-TC").tap()
        element("lab-field-TC").typeText("5.2")
        shot("10-lab-form")
        save.tap()
        XCTAssertTrue(toastText().contains("已保存化验结果"))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "LDL-C 3.4")).firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: 截图：各主屏，今日页浅色与深色

    func testScreenshotsLight() { screenshots(appearance: "light") }
    func testScreenshotsDark() { screenshots(appearance: "dark") }

    private func screenshots(appearance: String) {
        let s = appearance == "dark" ? "-dark" : "-light"
        launch(demo: true, appearance: appearance)
        waitFor(element("advice"))
        shot("02-today\(s)")
        app.swipeUp(velocity: .slow)
        shot("03-today-scrolled\(s)")
        element("fab-add").tap()
        waitFor(element("add-search"))
        shot("04-add-panel\(s)")
        element("sheet-done").tap()
        tab("清单")
        waitFor(element("library-search"))
        shot("08-lists\(s)")
        tab("分析")
        waitFor(element("analysis-summary"))
        shot("09-analysis\(s)")
        app.swipeUp(velocity: .slow)
        shot("09-analysis-scrolled\(s)")
        tab("化验")
        waitFor(element("lab-add"))
        shot("11-labs\(s)")
        tab("今日")
        element("open-settings").tap()
        waitFor(element("sheet-done"))
        shot("12-settings\(s)")
    }
}
