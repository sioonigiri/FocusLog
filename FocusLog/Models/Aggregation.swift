import SwiftUI

/// カテゴリごとに合算した学習時間。
struct CategoryTotal: Identifiable {
    let id: String
    let category: Category?
    let sessions: [Session]

    var seconds: Int { sessions.reduce(0) { $0 + $1.durationSeconds } }
    var name: String { category?.name ?? "未分類" }
    var color: Color { category?.color.color ?? .gray }
}

/// 1日のうち、同じタスクの記録をまとめたもの。
struct TaskTotal: Identifiable {
    let id: String
    let name: String
    let sessions: [Session]

    var seconds: Int { sessions.reduce(0) { $0 + $1.durationSeconds } }
}

extension Array where Element == Session {
    var totalSeconds: Int { reduce(0) { $0 + $1.durationSeconds } }

    /// 同じカテゴリの記録を合算し、カテゴリの並び順で返す。
    func groupedByCategory() -> [CategoryTotal] {
        Dictionary(grouping: self) { $0.category?.id }
            .map { key, sessions in
                CategoryTotal(id: key?.uuidString ?? "none",
                              category: sessions.first?.category,
                              sessions: sessions.sorted { $0.startedAt < $1.startedAt })
            }
            .sorted { ($0.category?.sortOrder ?? .max) < ($1.category?.sortOrder ?? .max) }
    }

    /// 同じタスクの記録を合算する。タスクが削除済み・初期タイマーの記録は、記録時の名前でまとめる。
    func groupedByTask() -> [TaskTotal] {
        Dictionary(grouping: self) { $0.task.map { $0.id.uuidString } ?? "name:\($0.taskNameSnapshot)" }
            .map { key, sessions in
                let sorted = sessions.sorted { $0.startedAt < $1.startedAt }
                return TaskTotal(id: key, name: sorted.last?.taskNameSnapshot ?? "", sessions: sorted)
            }
            .sorted { ($0.sessions.first?.startedAt ?? .distantPast) < ($1.sessions.first?.startedAt ?? .distantPast) }
    }

    func on(_ day: Date, calendar: Calendar = .current) -> [Session] {
        filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
    }
}

enum DurationFormat {
    /// 「45分」「1時間35分」形式。
    static func text(seconds: Int) -> String {
        let minutes = seconds / 60
        guard minutes >= 60 else { return "\(minutes)分" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)時間" : "\(h)時間\(m)分"
    }

    /// タイマー表示用の「29:58」形式。タイマーは60分までなので、60分も「60:00」と分で表す。
    static func clock(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

enum DayFormat {
    static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    /// カレンダーの曜日の並び。月曜始まり。
    static let calendarWeekdays = ["月", "火", "水", "木", "金", "土", "日"]

    /// 「10月28日（水）」形式。
    static func title(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        return "\(c.month!)月\(c.day!)日（\(weekdays[c.weekday! - 1])）"
    }

    /// 「2026年10月」形式。端末が和暦設定でも西暦で表示する。
    static func month(_ date: Date) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = Calendar.current.timeZone
        let c = gregorian.dateComponents([.year, .month], from: date)
        return "\(c.year!)年\(c.month!)月"
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date))!
    }
}
