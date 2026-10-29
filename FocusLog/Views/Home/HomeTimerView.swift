import SwiftUI

/// ホーム画面。タイマーと、左上の「≡」「カレンダー」ボタンだけを表示する。
struct HomeTimerView: View {
    let openDrawer: () -> Void

    @Environment(TimerStore.self) private var timer
    @State private var showingCalendar = false

    var body: some View {
        Group {
            if let completed = timer.completed {
                CompletionView(completed: completed)
            } else {
                TimerView()
            }
        }
        .toolbar {
            // タイマー中は集中できるように、また別のタスクに切り替わらないようにメニューを隠す。
            // 完了画面ではチェックマークとホームボタンだけにする。
            if timer.active == nil && timer.completed == nil {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("タスク一覧", systemImage: "line.3.horizontal", action: openDrawer)
                    Button("カレンダー", systemImage: "calendar") { showingCalendar = true }
                }
            }
        }
        .navigationDestination(isPresented: $showingCalendar) {
            CalendarScreen()
        }
    }
}
