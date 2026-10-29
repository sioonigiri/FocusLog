import SwiftData
import SwiftUI
import UserNotifications

@main
struct FocusLogApp: App {
    @State private var timerStore: TimerStore
    @State private var proStore = ProStore()
    private let container: ModelContainer
    private let notificationDelegate = NotificationDelegate()

    init() {
        do {
            // CloudKitの権限（entitlements）を追加すると、この設定のままiCloud同期が有効になる。
            container = UITestSupport.isActive
                ? try UITestSupport.makeContainer()
                : try ModelContainer(for: Category.self, TaskTemplate.self, Session.self)
        } catch {
            fatalError("データベースを開けませんでした: \(error)")
        }
        // テスト用のデータ消去より後に作り、前回のタイマーが残らないようにする。
        _timerStore = State(initialValue: TimerStore())
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerStore)
                .environment(proStore)
        }
        .modelContainer(container)
    }
}
