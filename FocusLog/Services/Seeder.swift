import Foundation
import SwiftData

/// 起動時に保存済みデータを整える。
@MainActor
enum Seeder {
    /// 上限を180分から60分に下げたため、それより長いタスクを60分に揃える。
    static func clampTaskDurations(_ context: ModelContext) {
        let limit = Limits.timerMinutes.upperBound
        let tasks = (try? context.fetch(FetchDescriptor<TaskTemplate>(predicate: #Predicate { $0.durationMinutes > limit }))) ?? []
        guard !tasks.isEmpty else { return }
        tasks.forEach { $0.durationMinutes = limit }
        try? context.save()
    }
}
