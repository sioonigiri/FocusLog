import SwiftUI

/// カテゴリに設定できる12色。iOSのシステムカラーを元にしているのでダークモードでも自動で調整される。
enum CategoryColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }

    static func from(_ key: String) -> CategoryColor {
        CategoryColor(rawValue: key) ?? .gray
    }

    /// アプリ全体で使うカテゴリ色。システムカラーを少し薄めて使う。
    var color: Color {
        Color(uiColor: UIColor { traits in
            let base = systemColor.resolvedColor(with: traits)
            // ライトは白に、ダークは黒に寄せて、背景になじむ方向へ薄める。
            return traits.userInterfaceStyle == .dark
                ? base.mixed(with: .black, amount: Self.fadeAmountDark)
                : base.mixed(with: .white, amount: Self.fadeAmountLight)
        })
    }

    private static let fadeAmountLight: CGFloat = 0.4
    private static let fadeAmountDark: CGFloat = 0.3

    private var systemColor: UIColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .mint: .systemMint
        case .teal: .systemTeal
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .pink: .systemPink
        case .brown: .systemBrown
        case .gray: .systemGray
        }
    }

    /// 色の上に載せる文字色。明るい色では黒にして読みやすくする。
    var foreground: Color {
        switch self {
        case .yellow, .mint: .black.opacity(0.8)
        default: .white
        }
    }

    var name: String {
        switch self {
        case .red: "レッド"
        case .orange: "オレンジ"
        case .yellow: "イエロー"
        case .green: "グリーン"
        case .mint: "ミント"
        case .teal: "ティール"
        case .blue: "ブルー"
        case .indigo: "インディゴ"
        case .purple: "パープル"
        case .pink: "ピンク"
        case .brown: "ブラウン"
        case .gray: "グレー"
        }
    }
}

private extension UIColor {
    /// amount（0〜1）の割合で other に寄せた色。
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount,
                       green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount,
                       alpha: a1)
    }
}
