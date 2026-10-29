import Foundation
import SwiftData

// iCloud同期（CloudKit）に対応させるため、全プロパティにデフォルト値を持たせ、
// リレーションはすべてOptionalにしている。@Attribute(.unique) はCloudKitでは使えない。

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var colorKey: String = CategoryColor.blue.rawValue
    /// 削除されたカテゴリ。過去の記録を残すため実体は消さない。
    var isArchived: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TaskTemplate.category)
    var tasks: [TaskTemplate]? = []

    @Relationship(deleteRule: .nullify, inverse: \Session.category)
    var sessions: [Session]? = []

    init(name: String, color: CategoryColor, sortOrder: Int) {
        self.name = name
        self.colorKey = color.rawValue
        self.sortOrder = sortOrder
    }

    var color: CategoryColor { CategoryColor.from(colorKey) }
}

/// ホーム画面に並ぶタスクボタン。
@Model
final class TaskTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var durationMinutes: Int = 25
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Session.task)
    var sessions: [Session]? = []

    init(name: String, durationMinutes: Int, sortOrder: Int, category: Category?) {
        self.name = name
        self.durationMinutes = durationMinutes
        self.sortOrder = sortOrder
        self.category = category
    }
}

/// 学習1回分の記録。
@Model
final class Session {
    var id: UUID = UUID()
    /// どの日の記録かを決めるためだけに使う。時刻は表示しない。
    var startedAt: Date = Date()
    var durationSeconds: Int = 0
    /// タスク名を変更・削除しても過去の記録が壊れないようにコピーして持つ。
    var taskNameSnapshot: String = ""
    var isManual: Bool = false
    var task: TaskTemplate?
    var category: Category?

    init(startedAt: Date, durationSeconds: Int, taskNameSnapshot: String,
         isManual: Bool, task: TaskTemplate?, category: Category?) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.taskNameSnapshot = taskNameSnapshot
        self.isManual = isManual
        self.task = task
        self.category = category
    }
}

enum Limits {
    static let freeCategories = 3
    static let freeTasks = 6
    /// 無料版の作成上限を効かせるか。Proの内容と価格が調整中のあいだは外しておく。
    static let isEnforced = false
    /// タイマー時間の範囲（分）。
    static let timerMinutes = 1...60
}
