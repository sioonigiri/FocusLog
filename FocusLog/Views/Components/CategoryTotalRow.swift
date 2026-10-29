import SwiftUI

/// カテゴリ名と学習時間を、カテゴリ色の横棒つきで表示する行。
struct CategoryTotalRow: View {
    let total: CategoryTotal
    /// 棒の長さの基準になる秒数（一番長いカテゴリなど）。
    let maxSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                CategoryDot(color: total.color)
                Text(total.name)
                Spacer()
                Text(DurationFormat.text(seconds: total.seconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(total.color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(total.color)
                            .frame(width: proxy.size.width * ratio)
                    }
            }
            .frame(height: 8)
        }
    }

    private var ratio: CGFloat {
        guard maxSeconds > 0 else { return 0 }
        return min(1, CGFloat(total.seconds) / CGFloat(maxSeconds))
    }
}

/// カテゴリ色の丸。
struct CategoryDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 12, height: 12)
    }
}
