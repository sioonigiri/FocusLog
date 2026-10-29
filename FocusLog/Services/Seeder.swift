import Foundation
import SwiftData

/// 初回起動時にサンプルのカテゴリとタスクを入れる。
@MainActor
enum Seeder {
    private static let key = "didSeedSampleData"

    /// 上限を180分から60分に下げたため、それより長いタスクを60分に揃える。
    static func clampTaskDurations(_ context: ModelContext) {
        let limit = Limits.timerMinutes.upperBound
        let tasks = (try? context.fetch(FetchDescriptor<TaskTemplate>(predicate: #Predicate { $0.durationMinutes > limit }))) ?? []
        guard !tasks.isEmpty else { return }
        tasks.forEach { $0.durationMinutes = limit }
        try? context.save()
    }

    static func seedIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // 別の端末からiCloudで同期済みのデータがあれば入れない。
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }

        let english = Category(name: "英語", color: .blue, sortOrder: 0)
        context.insert(english)
        context.insert(TaskTemplate(name: "英語", durationMinutes: 25, sortOrder: 0, category: english))
        try? context.save()
    }
}
