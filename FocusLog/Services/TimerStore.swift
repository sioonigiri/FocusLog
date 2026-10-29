import Foundation
import Observation
import SwiftData

/// 実行中のタイマー。アプリが終了しても復元できるようUserDefaultsに保存する（同期はしない）。
struct ActiveTimer: Codable, Equatable {
    var config: TimerConfig
    var plannedSeconds: Int
    var startedAt: Date
    /// 実行中の終了予定時刻。一時停止中はnil。
    var endDate: Date?
    /// 一時停止中の残り時間。実行中はnil。
    var pausedRemaining: TimeInterval?

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: Date = .now) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// 一時停止していた時間を含まない経過秒数。
    func elapsedSeconds(at now: Date = .now) -> Int {
        Int(Double(plannedSeconds) - remaining(at: now))
    }
}

/// 最後まで終わったタイマー。完了画面の表示に使う。
struct CompletedTimer: Equatable {
    var config: TimerConfig
}

@MainActor
@Observable
final class TimerStore {
    static let minimumRecordSeconds = 60
    /// ホーム画面に表示する、最後に使ったタスク。空なら初期タイマー。
    static let selectedTaskKey = "selectedTaskID"
    /// ホームの数字をタップして変えた時間（分）。0なら変更なし。タスクを選び直すと戻る。
    static let minutesOverrideKey = "timerMinutesOverride"
    private static let storageKey = "activeTimer"

    var active: ActiveTimer? {
        didSet { persist() }
    }
    var completed: CompletedTimer?

    var isPresenting: Bool { active != nil || completed != nil }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey) {
            active = try? JSONDecoder().decode(ActiveTimer.self, from: data)
        }
    }

    /// タイマーをセットするだけで、開始はしない。ホーム画面にこのタスクが表示される。
    func select(_ config: TimerConfig) {
        UserDefaults.standard.set(config.taskID?.uuidString ?? "", forKey: Self.selectedTaskKey)
        UserDefaults.standard.set(0, forKey: Self.minutesOverrideKey)
        completed = nil
    }

    func start(_ config: TimerConfig) {
        let now = Date()
        let planned = config.minutes * 60
        UserDefaults.standard.set(config.taskID?.uuidString ?? "", forKey: Self.selectedTaskKey)
        completed = nil
        active = ActiveTimer(config: config,
                             plannedSeconds: planned,
                             startedAt: now,
                             endDate: now.addingTimeInterval(TimeInterval(planned)))
        NotificationManager.requestAuthorizationIfNeeded()
        scheduleNotification()
    }

    func pause() {
        guard var timer = active, !timer.isPaused else { return }
        timer.pausedRemaining = timer.remaining()
        timer.endDate = nil
        active = timer
        NotificationManager.cancelTimer()
    }

    func resume() {
        guard var timer = active, let remaining = timer.pausedRemaining else { return }
        timer.endDate = Date().addingTimeInterval(remaining)
        timer.pausedRemaining = nil
        active = timer
        scheduleNotification()
    }

    /// 終了時刻を過ぎていれば記録して完了画面に切り替える。
    /// バックグラウンド中に終わっていた場合も、復帰時にこれを呼べば記録される。
    func finishIfDue(in context: ModelContext, now: Date = .now) {
        guard let timer = active, !timer.isPaused, let end = timer.endDate, end <= now else { return }
        record(timer, seconds: timer.plannedSeconds, in: context)
        active = nil
        completed = CompletedTimer(config: timer.config)
        NotificationManager.cancelTimer()
        // バックグラウンドで終わっていた場合は通知で知らせ済みなので鳴らさない。
        if now.timeIntervalSince(end) < 2 {
            Feedback.startAlarm()
        }
    }

    /// 途中終了。経過分を記録する（1分未満は記録しない）。
    func stop(record shouldRecord: Bool, in context: ModelContext) {
        guard let timer = active else { return }
        let elapsed = timer.elapsedSeconds()
        if shouldRecord && elapsed >= Self.minimumRecordSeconds {
            record(timer, seconds: elapsed, in: context)
        }
        active = nil
        NotificationManager.cancelTimer()
    }

    /// 完了画面を閉じる。鳴っているアラームも止める。
    func dismissCompleted() {
        Feedback.stopAlarm()
        completed = nil
    }

    private func record(_ timer: ActiveTimer, seconds: Int, in context: ModelContext) {
        let task = timer.config.taskID.flatMap { fetchTask($0, in: context) }
        let session = Session(startedAt: timer.startedAt,
                              durationSeconds: seconds,
                              taskNameSnapshot: timer.config.name,
                              isManual: false,
                              task: task,
                              category: task?.category)
        context.insert(session)
        try? context.save()
    }

    private func fetchTask(_ id: UUID, in context: ModelContext) -> TaskTemplate? {
        let descriptor = FetchDescriptor<TaskTemplate>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func scheduleNotification() {
        guard let timer = active, let end = timer.endDate else { return }
        NotificationManager.scheduleTimerEnd(at: end, taskName: timer.config.name, minutes: timer.plannedSeconds / 60)
    }

    private func persist() {
        if let active, let data = try? JSONEncoder().encode(active) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }
}
