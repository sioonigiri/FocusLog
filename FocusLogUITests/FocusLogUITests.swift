import XCTest

/// 実際に画面を操作して確かめるテスト。-UITesting で、メモリ上のテストデータを使って起動する。
/// テストデータ：英語（単語25分・リスニング30分）、数学（計算1分）。今日は単語25分×2と計算10分。
final class FocusLogUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    private var menuButton: XCUIElement { app.buttons["タスク一覧"] }
    private var calendarButton: XCUIElement { app.buttons["カレンダー"] }

    private func openDrawer() {
        menuButton.tap()
        XCTAssertTrue(app.staticTexts["タイマー"].waitForExistence(timeout: 2))
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func task(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private var deleteAction: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["削除", "Delete"])).firstMatch
    }

    // MARK: ホーム

    func testInitialTimerAndSelectingTask() {
        XCTAssertTrue(app.buttons["10:00"].waitForExistence(timeout: 3), "初期タイマーは10分")
        openDrawer()
        task("単語").tap()
        XCTAssertTrue(app.buttons["25:00"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["タイマー"].exists, "選ぶとドロワーが閉じる")
    }

    func testTapDigitsChangesMinutesForThisTimeOnly() {
        app.buttons["10:00"].tap()
        XCTAssertTrue(app.navigationBars["タイマー時間"].waitForExistence(timeout: 2))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "5分")
        app.buttons["決定"].tap()
        XCTAssertTrue(app.buttons["05:00"].waitForExistence(timeout: 2))

        // キャンセルでは変わらない
        app.buttons["05:00"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "40分")
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.buttons["05:00"].waitForExistence(timeout: 2))

        // タスクを選び直すと、タスクの時間に戻る
        openDrawer()
        task("単語").tap()
        XCTAssertTrue(app.buttons["25:00"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["05:00"].exists)
    }

    func testMinutesPickerRangeIs1To60() {
        app.buttons["10:00"].tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 2))
        wheel.adjust(toPickerWheelValue: "60分")
        app.buttons["決定"].tap()
        XCTAssertTrue(app.buttons["60:00"].waitForExistence(timeout: 2))
        app.buttons["60:00"].tap()
        wheel.adjust(toPickerWheelValue: "1分")
        app.buttons["決定"].tap()
        XCTAssertTrue(app.buttons["01:00"].waitForExistence(timeout: 2))
    }

    func testRunningHidesMenuAndControlsWork() {
        app.buttons["再生"].tap()
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 2))
        XCTAssertFalse(menuButton.exists, "実行中は≡を隠す")
        XCTAssertFalse(calendarButton.exists, "実行中はカレンダーを隠す")

        // 実行中は数字をタップしても時間を変えられない
        app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", "\\d\\d:\\d\\d")).firstMatch.tap()
        XCTAssertFalse(app.navigationBars["タイマー時間"].waitForExistence(timeout: 1))

        app.buttons["一時停止"].tap()
        XCTAssertTrue(app.buttons["再開"].waitForExistence(timeout: 2))
        app.buttons["再開"].tap()
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 2))
        app.buttons["リセット"].tap()
        XCTAssertTrue(app.buttons["再生"].waitForExistence(timeout: 2))
        XCTAssertTrue(menuButton.exists)
        XCTAssertTrue(app.buttons["10:00"].exists)
    }

    // MARK: 完了画面

    func testCompletionSlideToStopAndRecord() {
        openDrawer()
        task("計算").tap()
        XCTAssertTrue(app.buttons["01:00"].waitForExistence(timeout: 2))
        app.buttons["再生"].tap()

        XCTAssertTrue(app.staticTexts["タイマー終了"].waitForExistence(timeout: 75))
        XCTAssertFalse(menuButton.exists, "完了画面では≡を隠す")
        XCTAssertFalse(calendarButton.exists)

        let slider = app.buttons["スライドして停止"]
        XCTAssertTrue(slider.exists)
        // 途中まででは止まらない
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)))
        XCTAssertTrue(app.staticTexts["タイマー終了"].waitForExistence(timeout: 1))
        // 右端まで動かすと止まってホームに戻る
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)))
        XCTAssertTrue(menuButton.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["タイマー終了"].exists)
        XCTAssertTrue(app.buttons["01:00"].exists, "同じタスクがセットされたまま")

        // 今日の記録：計算 10分 + 1分 = 11分
        calendarButton.tap()
        app.buttons[String(Calendar.current.component(.day, from: .now))].tap()
        XCTAssertTrue(app.staticTexts["11分"].waitForExistence(timeout: 2))
    }

    // MARK: カレンダー

    func testCalendarDayDetailMergeSwipeDeleteAndBack() {
        calendarButton.tap()
        XCTAssertTrue(app.navigationBars["カレンダー"].waitForExistence(timeout: 2))
        let gregorian = Calendar(identifier: .gregorian)
        let c = gregorian.dateComponents([.year, .month, .day], from: .now)
        XCTAssertTrue(app.staticTexts["\(c.year!)年\(c.month!)月"].exists, "年は西暦")
        XCTAssertTrue(app.staticTexts["\(c.month!)月の合計"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "\(c.month!)月の合計 ")).firstMatch.exists)

        // 未来の日は押せない
        let range = gregorian.range(of: .day, in: .month, for: .now)!
        if c.day! < range.upperBound - 1 {
            XCTAssertFalse(app.buttons["\(c.day! + 1)"].exists, "明日はボタンにならない")
            XCTAssertTrue(app.staticTexts["\(c.day! + 1)"].exists)
        }

        app.buttons["\(c.day!)"].tap()
        XCTAssertTrue(app.staticTexts["単語"].waitForExistence(timeout: 2))
        // 同じタスク（単語25分×2）は1行にまとまる
        XCTAssertEqual(app.staticTexts.matching(identifier: "単語").count, 1)
        XCTAssertTrue(app.staticTexts["50分"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "合計、1時間")).firstMatch.exists
                      || app.staticTexts["1時間"].exists, "合計 50+10")
        XCTAssertFalse(app.buttons["Edit"].exists || app.buttons["編集"].exists, "編集ボタンはない")
        XCTAssertFalse(app.navigationBars.buttons["追加"].exists)

        // 左スワイプで削除
        app.cells.containing(.staticText, identifier: "単語").firstMatch.swipeLeft()
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        deleteAction.tap()
        XCTAssertFalse(app.staticTexts["単語"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["計算"].exists)
        XCTAssertTrue(app.staticTexts["10分"].exists)

        // 戻るとカレンダー、もう一度戻るとホーム（カレンダーが二重に開かない）
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["カレンダー"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["\(c.year!)年\(c.month!)月"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(menuButton.waitForExistence(timeout: 2))
    }

    func testCalendarMonthSwitchAndEmptyDay() {
        calendarButton.tap()
        app.buttons["前の月"].tap()
        let prev = Calendar(identifier: .gregorian).date(byAdding: .month, value: -1, to: .now)!
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: prev)
        XCTAssertTrue(app.staticTexts["\(c.year!)年\(c.month!)月"].waitForExistence(timeout: 2))
        app.buttons["1"].tap()
        let empty = app.staticTexts["記録がありません"]
        // 前月1日が昨日のことはないので、空のはず
        XCTAssertTrue(empty.waitForExistence(timeout: 2))
    }

    // MARK: ドロワー

    func testDrawerEditModeDeletesTaskAndCategory() {
        openDrawer()
        XCTAssertFalse(app.buttons["新しいタスクを作成"].exists, "下部の作成ボタンはない")
        XCTAssertTrue(app.buttons["設定"].exists)
        app.buttons["タスクを編集"].tap()
        XCTAssertTrue(app.buttons["編集を終了"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["タスクを作成"].isEnabled, "編集中は＋を押せない")

        // タスクの「−」
        let minus = app.buttons.matching(identifier: "削除")
        XCTAssertEqual(minus.count, 3)
        minus.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["「単語」を削除しますか？"].waitForExistence(timeout: 2))
        app.buttons.matching(identifier: "削除").allElementsBoundByIndex.last!.tap()
        XCTAssertFalse(task("単語").waitForExistence(timeout: 1))
        XCTAssertTrue(task("リスニング").exists)

        // カテゴリの「−」
        app.buttons.matching(identifier: "カテゴリを削除").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["「数学」を削除しますか？"].waitForExistence(timeout: 2))
        app.buttons.matching(identifier: "カテゴリを削除").allElementsBoundByIndex.last!.tap()
        XCTAssertFalse(app.staticTexts["数学"].waitForExistence(timeout: 1))
        XCTAssertFalse(task("計算").exists)

        // 削除しても過去の記録はカレンダーに残る
        app.buttons["編集を終了"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        calendarButton.tap()
        app.buttons[String(Calendar.current.component(.day, from: .now))].tap()
        XCTAssertTrue(app.staticTexts["単語"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["計算"].exists)
    }

    func testDrawerEditModeTapOpensEditor() {
        openDrawer()
        app.buttons["タスクを編集"].tap()
        task("リスニング").tap()
        XCTAssertTrue(app.navigationBars["タスクを編集"].waitForExistence(timeout: 2))
        let field = app.textFields.firstMatch
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["すべてを選択"].waitForExistence(timeout: 1) { app.menuItems["すべてを選択"].tap() }
        else if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        field.typeText("シャドーイング")
        app.buttons["保存"].tap()
        XCTAssertTrue(task("シャドーイング").waitForExistence(timeout: 2))
    }

    func testDrawerCollapseCategory() {
        openDrawer()
        XCTAssertTrue(task("計算").exists)
        app.buttons["数学"].tap()
        XCTAssertFalse(task("計算").waitForExistence(timeout: 1))
        app.buttons["数学"].tap()
        XCTAssertTrue(task("計算").waitForExistence(timeout: 2))
    }

    func testCreateTaskWithNewCategory() {
        openDrawer()
        app.buttons["タスクを作成"].tap()
        XCTAssertTrue(app.navigationBars["タスクを追加"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["保存"].isEnabled, "名前が空なら保存できない")
        app.textFields["タスク名"].tap()
        app.textFields["タスク名"].typeText("過去問")

        app.buttons["新しいカテゴリを作成"].tap()
        XCTAssertTrue(app.navigationBars["カテゴリを追加"].waitForExistence(timeout: 2))
        app.textFields["カテゴリ名"].tap()
        app.textFields["カテゴリ名"].typeText("物理")
        app.buttons["パープル"].tap()
        app.navigationBars["カテゴリを追加"].buttons["保存"].tap()

        // 作ったカテゴリが選ばれた状態で戻る
        XCTAssertTrue(app.navigationBars["タスクを追加"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND selected == true", "物理")).firstMatch.exists)
        app.buttons["45"].tap()
        app.navigationBars["タスクを追加"].buttons["保存"].tap()

        XCTAssertTrue(app.staticTexts["物理"].waitForExistence(timeout: 2))
        task("過去問").tap()
        XCTAssertTrue(app.buttons["45:00"].waitForExistence(timeout: 2))
    }

    // MARK: 作成の上限

    func testTaskLimit() {
        app.terminate()
        app.launchArguments = ["-UITesting", "-UITestingFill", "tasks"]
        app.launch()
        openDrawer()
        app.buttons["タスクを作成"].tap()
        XCTAssertTrue(app.alerts["タスクは50個まで作成できます"].waitForExistence(timeout: 2))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(app.navigationBars["タスクを追加"].exists)
    }

    func testCategoryLimit() {
        app.terminate()
        app.launchArguments = ["-UITesting", "-UITestingFill", "categories"]
        app.launch()
        openDrawer()
        app.buttons["タスクを作成"].tap()
        XCTAssertTrue(app.navigationBars["タスクを追加"].waitForExistence(timeout: 2))
        app.buttons["新しいカテゴリを作成"].tap()
        XCTAssertTrue(app.alerts["カテゴリは10個まで作成できます"].waitForExistence(timeout: 2))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(app.navigationBars["カテゴリを追加"].exists)
    }

    // MARK: 設定

    func testSettings() {
        openDrawer()
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Pro")).firstMatch.exists, "Proは隠している")
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Pro")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["カテゴリ"].exists, "管理セクションはない")
        XCTAssertTrue(app.staticTexts["マナーモード中は音が鳴らず、バイブレーションのみになります。通知をオフにしている場合は、音もバイブレーションも鳴りません。"].exists)

        let picker = button(containing: "アラーム音")
        XCTAssertTrue(picker.exists)
        picker.tap()
        for name in ["標準", "チャイム", "ベル", "電子音", "マリンバ"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 2), name)
        }
        app.buttons["ベル"].tap()
        XCTAssertTrue(button(containing: "ベル").waitForExistence(timeout: 2))

        // サウンドをオフにするとアラーム音の選択は隠れる
        app.switches["サウンド"].switches.firstMatch.tap()
        XCTAssertFalse(button(containing: "アラーム音").waitForExistence(timeout: 1))
        app.switches["サウンド"].switches.firstMatch.tap()
        XCTAssertTrue(button(containing: "ベル").waitForExistence(timeout: 2), "選んだ音は残る")

        app.buttons["閉じる"].tap()
        XCTAssertTrue(menuButton.waitForExistence(timeout: 2))
    }
}
