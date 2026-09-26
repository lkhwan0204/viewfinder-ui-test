import SwiftUI
import UIKit

/// Viewfinder 디자인 토큰.
/// - 배경: 순수한 검정 대신 따뜻한 근흑색(암실). 라이트 모드는 전시장 벽 같은 오프화이트.
/// - UI는 무채색만 쓰고, 포인트 컬러는 골든아워 앰버 하나만 씁니다.
enum VF {
    enum Palette {
        static let background = Color(light: 0xF3F0EA, dark: 0x0D0D0C)
        static let surface = Color(light: 0xEAE6DE, dark: 0x161614)
        static let elevated = Color(light: 0xFFFFFF, dark: 0x1E1E1B)
        static let hairline = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.12)
        static let textPrimary = Color(light: 0x161513, dark: 0xF2F0EB)
        static let textSecondary = Color(light: 0x5F5B54, dark: 0x9D9A93)
        static let textTertiary = Color(light: 0x8F8A82, dark: 0x67645E)

        /// 골든아워 앰버 — 빛 정보와 핵심 행동에만 씁니다.
        static let amber = Color(hex: 0xF2A93B)
        static let amberSoft = Color(hex: 0xF2A93B, alpha: 0.16)
        static let onAmber = Color(hex: 0x1A1206)
        static let danger = Color(hex: 0xE5534B)

        /// 사진 뒤 배경은 테마와 상관없이 항상 암실색
        static let matte = Color(hex: 0x0D0D0C)
    }

    enum Typeface {
        /// 장소명: 크고 얇게
        static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .light) }
        static func title(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .semibold) }
        static func body(_ size: CGFloat = 15) -> Font { .system(size: size) }
        static func label(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
        /// 촬영 데이터(24mm f/11 1/250)는 카메라 LCD처럼 모노스페이스
        static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    enum Metric {
        static let hairline: CGFloat = 0.5
        /// 사진 액자는 둥글지 않습니다. 모서리는 최소한으로.
        static let corner: CGFloat = 3
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// 라이트/다크 모드에 따라 바뀌는 색
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
