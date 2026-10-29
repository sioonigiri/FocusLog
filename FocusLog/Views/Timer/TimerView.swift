import SwiftData
import SwiftUI

/// ホーム画面のタイマー。表示するのは円と数字、再生／停止、リセットだけ。
/// 開始前は最後に使ったタスク（なければ初期タイマー：テーマカラー・10分）を表示する。
struct TimerView: View {
    @Environment(TimerStore.self) private var timer
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskTemplate.sortOrder) private var tasks: [TaskTemplate]
    @AppStorage(TimerStore.selectedTaskKey) private var selectedTaskID = ""
    @AppStorage(TimerStore.minutesOverrideKey) private var minutesOverride = 0
    @State private var editingMinutes = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    /// 開始前に表示するタイマー設定。
    private var idleConfig: TimerConfig {
        var config = tasks.first { $0.id.uuidString == selectedTaskID && $0.category?.isArchived != true }
            .map(TimerConfig.init(task:)) ?? .initial
        // 数字をタップして変えた時間は今回だけ。タスク自体の時間は変えない。
        if minutesOverride > 0 { config.minutes = minutesOverride }
        config.minutes = min(config.minutes, Limits.timerMinutes.upperBound)
        return config
    }

    var body: some View {
        let active = timer.active
        let colorKey = active?.config.colorKey ?? idleConfig.colorKey
        let color = TimerPalette.fill(colorKey)

        VStack {
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let planned = Double(active?.plannedSeconds ?? idleConfig.minutes * 60)
                let remaining = active?.remaining(at: context.date) ?? planned
                TimerRing(progress: remaining / max(1, planned),
                          color: color,
                          text: DurationFormat.clock(remaining))
            }
            // 開始前だけ、数字をタップして時間を変えられる。
            .contentShape(Circle())
            .onTapGesture {
                if active == nil { editingMinutes = true }
            }
            .accessibilityAddTraits(active == nil ? .isButton : [])
            .accessibilityHint(active == nil ? "タップして時間を変更" : "")
            Spacer()

            // 開始前は再生ボタンだけ。動き出したらリセットと一時停止（一時停止中は再開）に切り替える。
            HStack(spacing: 64) {
                if let active {
                    CircleButton(systemImage: "arrow.counterclockwise",
                                 fill: color.opacity(TimerLayout.secondaryFillOpacity),
                                 foreground: .primary,
                                 label: "リセット") {
                        // 確認なしで即リセット。経過分（1分以上）は記録する。
                        timer.stop(record: true, in: context)
                    }
                    CircleButton(systemImage: active.isPaused ? "play.fill" : "pause.fill",
                                 fill: color,
                                 foreground: TimerPalette.foreground(colorKey),
                                 label: active.isPaused ? "再開" : "一時停止") {
                        active.isPaused ? timer.resume() : timer.pause()
                    }
                } else {
                    CircleButton(systemImage: "play.fill",
                                 fill: color,
                                 foreground: TimerPalette.foreground(colorKey),
                                 label: "再生") {
                        timer.start(idleConfig)
                    }
                }
            }
            .padding(.bottom, TimerLayout.controlBottomPadding)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .categoryBackground(colorKey)
        .onReceive(ticker) { now in
            timer.finishIfDue(in: context, now: now)
        }
        .sheet(isPresented: $editingMinutes) {
            MinutesPicker(initial: idleConfig.minutes) { minutesOverride = $0 }
                .presentationDetents([.height(340)])
        }
    }
}

/// ホームの数字をタップしたときに出る、時間の選択シート。
private struct MinutesPicker: View {
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int

    init(initial: Int, onDone: @escaping (Int) -> Void) {
        self.onDone = onDone
        _minutes = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Picker("時間", selection: $minutes) {
                ForEach(Limits.timerMinutes, id: \.self) { Text("\($0)分").tag($0) }
            }
            .pickerStyle(.wheel)
            .navigationTitle("タイマー時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        onDone(minutes)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 円形タイマー。残り時間に合わせて、上端から反時計回りに減っていく。
struct TimerRing: View {
    let progress: Double
    let color: Color
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: TimerLayout.centerSize, height: TimerLayout.centerSize)
    }
}

private struct CircleButton: View {
    let systemImage: String
    let fill: Color
    let foreground: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(foreground)
                .frame(width: TimerLayout.controlHeight, height: TimerLayout.controlHeight)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// タイマー終了時の画面。中央にチェックマークと「タイマー終了」、下に「スライドして停止」だけを置く。
/// 中央の円と下の操作は、ホームのタイマーリング・ボタンと同じ位置・大きさにそろえる。
struct CompletionView: View {
    let completed: CompletedTimer

    @Environment(TimerStore.self) private var timer
    @State private var appeared = false

    private var colorKey: String { completed.config.colorKey }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(TimerPalette.foreground(colorKey))
                    .frame(width: 140, height: 140)
                    .background(TimerPalette.fill(colorKey), in: Circle())
                Text("タイマー終了")
                    .font(.title2.weight(.semibold))
            }
            .frame(width: TimerLayout.centerSize, height: TimerLayout.centerSize)
            // 軽いフェードインと、少しだけのスケールアップ。
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
            .accessibilityElement(children: .combine)
            Spacer()

            SlideToStop(colorKey: colorKey) {
                timer.dismissCompleted()
            }
            .padding(.bottom, TimerLayout.controlBottomPadding)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .categoryBackground(colorKey)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }
}

/// 「スライドして停止」。チェックマークのつまみを右端まで動かすと onComplete を呼ぶ。
private struct SlideToStop: View {
    let colorKey: String
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var done = false

    private let inset: CGFloat = 6
    private var knob: CGFloat { TimerLayout.controlHeight - inset * 2 }

    var body: some View {
        let color = TimerPalette.fill(colorKey)
        GeometryReader { proxy in
            let maxOffset = max(0, proxy.size.width - knob - inset * 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(TimerLayout.secondaryFillOpacity))
                Text("スライドして停止")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, knob)
                    .opacity(1 - Double(offset / max(1, maxOffset)) * 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(TimerPalette.foreground(colorKey))
                    .frame(width: knob, height: knob)
                    .background(color, in: Circle())
                    .padding(inset)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !done else { return }
                                offset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !done else { return }
                                if offset > maxOffset * 0.8 {
                                    done = true
                                    withAnimation(.snappy(duration: 0.15)) { offset = maxOffset }
                                    onComplete()
                                } else {
                                    withAnimation(.snappy) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(width: 300, height: TimerLayout.controlHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("スライドして停止")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onComplete() }
    }
}
