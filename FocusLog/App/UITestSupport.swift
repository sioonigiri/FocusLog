import Foundation
import SwiftData

/// 自動テスト用。起動引数に -UITesting があると、端末の記録には触れず、
/// メモリ上だけのデータベースと決まったテストデータで起動する。
@MainActor
enum UITestSupport {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-UITesting")

    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Category.self, TaskTemplate.self, Session.self,
                                           configurations: config)
        resetDefaults()
        seed(container.mainContext)
        return container
    }

    private static func resetDefaults() {
        let defaults = UserDefaults.standard
        ["activeTimer", TimerStore.selectedTaskKey, TimerStore.minutesOverrideKey,
         "collapsedCategoryIDs", AppSettings.soundKey, AppSettings.vibrationKey, AppSettings.alarmSoundKey]
            .forEach(defaults.removeObject(forKey:))
    }

    /// 英語（単語25分・リスニング30分）と数学（計算1分）。
    /// 今日は「単語」を2回（合計50分）と「計算」10分、昨日は「単語」25分の記録がある。
    private static func seed(_ context: ModelContext) {
        let english = Category(name: "英語", color: .blue, sortOrder: 0)
        let math = Category(name: "数学", color: .green, sortOrder: 1)
        let words = TaskTemplate(name: "単語", durationMinutes: 25, sortOrder: 0, category: english)
        let listening = TaskTemplate(name: "リスニング", durationMinutes: 30, sortOrder: 1, category: english)
        let calc = TaskTemplate(name: "計算", durationMinutes: 1, sortOrder: 2, category: math)
        [english, math].forEach(context.insert)
        [words, listening, calc].forEach(context.insert)

        let today = Calendar.current.startOfDay(for: .now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        func add(_ task: TaskTemplate, on day: Date, minutes: Int, hour: Int) {
            context.insert(Session(startedAt: day.addingTimeInterval(TimeInterval(hour * 3600)),
                                   durationSeconds: minutes * 60,
                                   taskNameSnapshot: task.name,
                                   isManual: false,
                                   task: task,
                                   category: task.category))
        }
        add(words, on: today, minutes: 25, hour: 0)
        add(words, on: today, minutes: 25, hour: 0)
        add(calc, on: today, minutes: 10, hour: 0)
        add(words, on: yesterday, minutes: 25, hour: 9)

        // 上限のテスト用に、カテゴリかタスクを上限まで増やす。
        let fill = UserDefaults.standard.string(forKey: "UITestingFill")
        if fill == "categories" {
            for i in 2..<Limits.categories {
                context.insert(Category(name: "カテゴリ\(i + 1)", color: .gray, sortOrder: i))
            }
        } else if fill == "tasks" {
            for i in 3..<Limits.tasks {
                context.insert(TaskTemplate(name: "タスク\(i + 1)", durationMinutes: 10, sortOrder: i, category: math))
            }
        }
        try? context.save()
    }
}
