import SwiftData
import SwiftUI

struct CalendarScreen: View {
    @Query(sort: \Session.startedAt) private var sessions: [Session]
    @State private var month = Calendar.current.startOfMonth(for: .now)
    /// 開いている日別詳細。ホームからの遷移と同じ「状態で開く」方式にそろえる
    /// （値で積むNavigationLinkと混ぜると、カレンダーがもう一度積まれてしまうため）。
    @State private var selectedDay: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthSessions: [Session] {
        sessions.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
    }

    private var sessionsByDay: [Date: [Session]] {
        Dictionary(grouping: monthSessions) { calendar.startOfDay(for: $0.startedAt) }
    }

    /// 月初の曜日に合わせて先頭を空白(nil)で埋めた日付の並び。
    private var days: [Date?] {
        let leading = calendar.component(.weekday, from: month) - 1
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let dates = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month)! }
        return Array(repeating: nil, count: leading) + dates
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                VStack(spacing: 4) {
                    LazyVGrid(columns: columns) {
                        ForEach(DayFormat.weekdays, id: \.self) { weekday in
                            Text(weekday)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                            if let day, day > calendar.startOfDay(for: .now) {
                                // 未来の日は記録がないので開けない。
                                DayCell(day: day, sessions: [])
                            } else if let day {
                                Button { selectedDay = day } label: {
                                    DayCell(day: day, sessions: sessionsByDay[day] ?? [])
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 52)
                            }
                        }
                    }
                }
                MonthSummary(month: month, totals: monthSessions.groupedByCategory())
            }
            .padding()
        }
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDay) { day in
            DayDetailView(day: day)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button("前の月", systemImage: "chevron.left") { shiftMonth(-1) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(DayFormat.month(month))
                .font(.headline)
            Spacer()
            Button("次の月", systemImage: "chevron.right") { shiftMonth(1) }
                .labelStyle(.iconOnly)
        }
        .font(.title3)
    }

    private func shiftMonth(_ value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: month)!
    }
}

private struct DayCell: View {
    let day: Date
    let sessions: [Session]

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.callout.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 30, height: 30)
                .background(isToday ? Color.accentColor : Color.clear, in: Circle())
            HStack(spacing: 3) {
                ForEach(sessions.groupedByCategory().prefix(4)) { total in
                    Circle().fill(total.color).frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct MonthSummary: View {
    let month: Date
    let totals: [CategoryTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Calendar.current.component(.month, from: month))月の合計")
                .foregroundStyle(.secondary)
            let maxSeconds = totals.map(\.seconds).max() ?? 0
            ForEach(totals) { total in
                CategoryTotalRow(total: total, maxSeconds: maxSeconds)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
