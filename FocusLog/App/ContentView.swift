import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(TimerStore.self) private var timer
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingDrawer = false
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                NavigationStack {
                    HomeTimerView(openDrawer: { showingDrawer = true })
                }

                if showingDrawer {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { showingDrawer = false }
                        .transition(.opacity)

                    TaskDrawer(
                        onSelect: { task in
                            showingDrawer = false
                            timer.select(TimerConfig(task: task))
                        },
                        onOpenSettings: {
                            showingDrawer = false
                            showingSettings = true
                        }
                    )
                    .frame(width: min(320, proxy.size.width * 0.82))
                    .transition(.move(edge: .leading))
                    .gesture(DragGesture().onEnded { value in
                        if value.translation.width < -60 { showingDrawer = false }
                    })
                }
            }
            .animation(.easeOut(duration: 0.25), value: showingDrawer)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .task {
            Seeder.seedIfNeeded(context)
            Seeder.clampTaskDurations(context)
            timer.finishIfDue(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timer.finishIfDue(in: context)
            } else if phase == .background {
                // バックグラウンドでは鳴らせないので、戻ったときに急に鳴り出さないよう止めておく。
                Feedback.stopAlarm()
            }
        }
    }
}
