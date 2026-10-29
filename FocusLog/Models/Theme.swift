import SwiftUI

extension Color {
    /// アプリのテーマカラー #BFE9FF。
    static let theme = Color(red: 191 / 255, green: 233 / 255, blue: 255 / 255)
}

/// タイマーの色。テーマカラーとカテゴリの12色を同じキーで扱う。
enum TimerPalette {
    static let themeKey = "theme"

    static func fill(_ key: String) -> Color {
        key == themeKey ? .theme : CategoryColor.from(key).color
    }

    /// 塗りつぶしの上に載せるアイコンの色。
    static func foreground(_ key: String) -> Color {
        key == themeKey ? .black.opacity(0.75) : CategoryColor.from(key).foreground
    }
}

/// タイマーを始めるときの設定。タスクを選ぶ前は初期タイマー（テーマカラー・10分）を使う。
struct TimerConfig: Codable, Equatable {
    var taskID: UUID?
    var name: String
    var colorKey: String
    var minutes: Int

    static let initial = TimerConfig(taskID: nil, name: "タイマー", colorKey: TimerPalette.themeKey, minutes: 10)

    init(taskID: UUID?, name: String, colorKey: String, minutes: Int) {
        self.taskID = taskID
        self.name = name
        self.colorKey = colorKey
        self.minutes = minutes
    }

    init(task: TaskTemplate) {
        self.init(taskID: task.id,
                  name: task.name,
                  colorKey: task.category?.colorKey ?? CategoryColor.gray.rawValue,
                  minutes: task.durationMinutes)
    }
}

/// ホーム・タイマー・完了画面で共通の見た目。カテゴリが変わっても同じ形・余白で、色だけが変わる。
enum TimerLayout {
    /// 背景に敷くカテゴリ色の濃さ。
    static let backgroundOpacity = 0.07
    /// リセットボタンなど、補助ボタンの塗りの濃さ。
    static let secondaryFillOpacity = 0.2
    /// 中央の円（タイマーリング・完了のチェック）の大きさ。
    static let centerSize: CGFloat = 280
    /// 下部の操作（ボタン・スライダー）の高さと、画面下からの余白。
    static let controlHeight: CGFloat = 80
    static let controlBottomPadding: CGFloat = 48
}

extension View {
    /// 画面全体にカテゴリ色をごく薄く敷く。
    func categoryBackground(_ colorKey: String) -> some View {
        background {
            TimerPalette.fill(colorKey)
                .opacity(TimerLayout.backgroundOpacity)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: colorKey)
        }
    }
}
