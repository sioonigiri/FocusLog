import SwiftData
import SwiftUI

struct DayDetailView: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Query(sort: \Session.startedAt) private var sessions: [Session]

    private var daySessions: [Session] { sessions.on(day) }

    var body: some View {
        let totals = daySessions.groupedByCategory()
        List {
            if totals.isEmpty {
                ContentUnavailableView("記録がありません", systemImage: "calendar")
            }
            ForEach(totals) { total in
                Section {
                    // 同じタスクは1行にまとめる。左スワイプでその日のそのタスクの記録をまとめて削除する。
                    let taskTotals = total.sessions.groupedByTask()
                    ForEach(taskTotals) { taskTotal in
                        TaskTotalRow(total: taskTotal)
                    }
                    .onDelete { offsets in
                        offsets.flatMap { taskTotals[$0].sessions }.forEach(context.delete)
                        try? context.save()
                    }
                } header: {
                    HStack {
                        CategoryDot(color: total.color)
                        Text(total.name)
                        Spacer()
                        Text(DurationFormat.text(seconds: total.seconds)).monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(total.color)
                }
            }
            if !totals.isEmpty {
                Section {
                    LabeledContent("合計") {
                        Text(DurationFormat.text(seconds: daySessions.totalSeconds))
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(DayFormat.title(day))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TaskTotalRow: View {
    let total: TaskTotal

    var body: some View {
        HStack {
            Text(total.name)
            Spacer()
            Text(DurationFormat.text(seconds: total.seconds))
                .monospacedDigit()
        }
    }
}
