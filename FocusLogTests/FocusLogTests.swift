import AudioToolbox
import SwiftData
import XCTest
@testable import FocusLog

@MainActor
final class AggregationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(for: Category.self, TaskTemplate.self, Session.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func session(_ task: TaskTemplate?, name: String, minutes: Int, at date: Date) -> Session {
        let s = Session(startedAt: date, durationSeconds: minutes * 60, taskNameSnapshot: name,
                        isManual: false, task: task, category: task?.category)
        context.insert(s)
        return s
    }

    func testSameTaskIsMergedIntoOneRow() {
        let category = Category(name: "英語", color: .blue, sortOrder: 0)
        let task = TaskTemplate(name: "単語", durationMinutes: 25, sortOrder: 0, category: category)
        context.insert(category); context.insert(task)
        let now = Date()
        let sessions = [
            session(task, name: "単語", minutes: 25, at: now),
            session(task, name: "単語", minutes: 25, at: now.addingTimeInterval(60)),
            session(nil, name: "タイマー", minutes: 10, at: now.addingTimeInterval(120)),
            session(nil, name: "タイマー", minutes: 5, at: now.addingTimeInterval(180)),
        ]
        let groups = sessions.groupedByTask()
        XCTAssertEqual(groups.map(\.name), ["単語", "タイマー"])
        XCTAssertEqual(groups.map(\.seconds), [50 * 60, 15 * 60])
    }

    func testRenamedTaskUsesLatestName() {
        let task = TaskTemplate(name: "単語", durationMinutes: 25, sortOrder: 0, category: nil)
        context.insert(task)
        let now = Date()
        let groups = [session(task, name: "旧名", minutes: 5, at: now),
                      session(task, name: "単語", minutes: 5, at: now.addingTimeInterval(60))].groupedByTask()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.name, "単語")
    }

    func testCategoryOrderAndUncategorizedLast() {
        let a = Category(name: "A", color: .red, sortOrder: 1)
        let b = Category(name: "B", color: .blue, sortOrder: 0)
        let ta = TaskTemplate(name: "a", durationMinutes: 1, sortOrder: 0, category: a)
        let tb = TaskTemplate(name: "b", durationMinutes: 1, sortOrder: 1, category: b)
        [a, b].forEach(context.insert); [ta, tb].forEach(context.insert)
        let now = Date()
        let totals = [session(nil, name: "x", minutes: 1, at: now),
                      session(ta, name: "a", minutes: 1, at: now),
                      session(tb, name: "b", minutes: 1, at: now)].groupedByCategory()
        XCTAssertEqual(totals.map(\.name), ["B", "A", "未分類"])
    }

    func testDurationFormat() {
        XCTAssertEqual(DurationFormat.text(seconds: 45 * 60), "45分")
        XCTAssertEqual(DurationFormat.text(seconds: 60 * 60), "1時間")
        XCTAssertEqual(DurationFormat.text(seconds: 95 * 60), "1時間35分")
        XCTAssertEqual(DurationFormat.clock(59.2), "01:00")
        XCTAssertEqual(DurationFormat.clock(3600), "1:00:00")
    }

    func testMonthIsAlwaysGregorian() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .current
        let date = japanese.date(from: DateComponents(era: 236, year: 8, month: 10, day: 28))!
        XCTAssertEqual(DayFormat.month(date), "2026年10月")
    }

    func testDayTitle() {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 28
        XCTAssertEqual(DayFormat.title(Calendar.current.date(from: c)!), "10月28日（水）")
    }

    func testClampTaskDurations() {
        let task = TaskTemplate(name: "長い", durationMinutes: 120, sortOrder: 0, category: nil)
        context.insert(task)
        Seeder.clampTaskDurations(context)
        XCTAssertEqual(task.durationMinutes, 60)
    }

    func testFreeLimitsAreOffWhilePlanned() {
        XCTAssertFalse(Limits.isEnforced)
        let pro = ProStore()
        XCTAssertTrue(pro.canCreateTask(currentCount: 100))
        XCTAssertTrue(pro.canCreateCategory(currentCount: 100))
    }
}

@MainActor
final class TimerStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var store: TimerStore!

    override func setUp() async throws {
        container = try ModelContainer(for: Category.self, TaskTemplate.self, Session.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        UserDefaults.standard.removeObject(forKey: "activeTimer")
        UserDefaults.standard.set(false, forKey: AppSettings.soundKey) // テスト中は音を鳴らさない
        UserDefaults.standard.set(true, forKey: AppSettings.vibrationKey)
        store = TimerStore()
    }

    override func tearDown() async throws {
        Feedback.stopAlarm()
        store.active = nil
        UserDefaults.standard.removeObject(forKey: AppSettings.soundKey)
        UserDefaults.standard.removeObject(forKey: AppSettings.vibrationKey)
    }

    private var sessions: [Session] { (try? context.fetch(FetchDescriptor<Session>())) ?? [] }

    func testFinishRecordsPlannedTimeAndStartsAlarm() {
        let task = TaskTemplate(name: "単語", durationMinutes: 1, sortOrder: 0, category: nil)
        context.insert(task)
        store.start(TimerConfig(task: task))
        store.finishIfDue(in: context, now: store.active!.endDate!.addingTimeInterval(0.5))

        XCTAssertNil(store.active)
        XCTAssertNotNil(store.completed)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.durationSeconds, 60)
        XCTAssertEqual(sessions.first?.task?.id, task.id)
        XCTAssertTrue(Feedback.isRinging)

        store.dismissCompleted()
        XCTAssertFalse(Feedback.isRinging)
        XCTAssertNil(store.completed)
    }

    func testFinishedInBackgroundDoesNotRing() {
        store.start(.initial)
        store.finishIfDue(in: context, now: store.active!.endDate!.addingTimeInterval(30))
        XCTAssertNotNil(store.completed)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(Feedback.isRinging)
    }

    func testNotDueYetDoesNothing() {
        store.start(.initial)
        store.finishIfDue(in: context)
        XCTAssertNotNil(store.active)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPausedTimerNeverFinishes() {
        store.start(.initial)
        store.pause()
        store.finishIfDue(in: context, now: .now.addingTimeInterval(3600))
        XCTAssertNotNil(store.active)
        XCTAssertTrue(store.active!.isPaused)
        store.resume()
        XCTAssertFalse(store.active!.isPaused)
        XCTAssertEqual(store.active!.remaining(), 600, accuracy: 1)
    }

    func testResetRecordsOnlyOneMinuteOrMore() {
        store.start(.initial)
        store.stop(record: true, in: context)
        XCTAssertTrue(sessions.isEmpty, "1分未満は記録しない")

        store.start(.initial)
        store.active!.startedAt = .now.addingTimeInterval(-90)
        store.active!.endDate = store.active!.endDate!.addingTimeInterval(-90)
        store.stop(record: true, in: context)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.durationSeconds ?? 0, 90, accuracy: 1)
        XCTAssertNil(store.active)
    }

    func testSelectResetsMinutesOverride() {
        UserDefaults.standard.set(5, forKey: TimerStore.minutesOverrideKey)
        store.select(.initial)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: TimerStore.minutesOverrideKey), 0)
    }

    func testActiveTimerSurvivesRelaunch() {
        store.start(.initial)
        let restored = TimerStore()
        XCTAssertEqual(restored.active, store.active)
    }

    func testAlarmStopsByItselfAfterOneMinute() async throws {
        Feedback.startAlarm()
        XCTAssertTrue(Feedback.isRinging)
        try await Task.sleep(for: .seconds(Feedback.maxDuration + 3))
        XCTAssertFalse(Feedback.isRinging)
    }
}

@MainActor
final class AlarmSoundTests: XCTestCase {
    func testBundledSoundsLoad() {
        for sound in AlarmSound.allCases where sound != .standard {
            XCTAssertNotNil(Bundle.main.url(forResource: "\(sound.rawValue).wav", withExtension: nil), sound.name)
            XCTAssertNotEqual(sound.systemSoundID, 1005, "\(sound.name) が読み込めず標準音になっている")
        }
        XCTAssertEqual(AlarmSound.standard.systemSoundID, 1005)
    }

    func testNotificationSoundUsesFile() {
        XCTAssertEqual(AlarmSound.standard.notificationSound, .default)
        XCTAssertNotEqual(AlarmSound.bell.notificationSound, .default)
    }
}
