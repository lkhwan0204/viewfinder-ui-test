import Foundation

/// 실제 사진 대신 그리는 "사진 같은" 장면의 레시피.
/// UI 레이어의 `PlaceholderArtView`가 이 레시피를 Canvas로 렌더링합니다.
/// 실제 사진을 넣으면(Frame.imageName) 이 값은 쓰이지 않습니다.
struct PlaceholderArt: Hashable {
    var sky: SkyPalette
    /// 수평선 위치 (0 = 위, 1 = 아래)
    var horizon: Double
    var celestial: Celestial? = nil
    var stars: Bool = false
    var milkyWay: Bool = false
    var backdrop: [Backdrop] = []
    var surface: Surface
    var foreground: [Foreground] = []
    var seed: UInt64
}

enum SkyPalette: String, Hashable {
    case dawn, golden, day, dusk, blue, night, mist, spring

    /// 위 → 수평선 순서의 하늘 색 (0xRRGGBB)
    var stops: [UInt32] {
        switch self {
        case .dawn: return [0x1B2440, 0x4A4F7A, 0xC98A8A, 0xF2C08A]
        case .golden: return [0x2B3A67, 0xC8735A, 0xF4A259, 0xF9D29D]
        case .day: return [0x3C6E9E, 0x7FB0D9, 0xC9E1F2]
        case .dusk: return [0x1E1B3A, 0x6B3F6E, 0xE0785A, 0xF7B267]
        case .blue: return [0x0B1633, 0x1D3461, 0x3E5C8A, 0x7A8FB3]
        case .night: return [0x04060C, 0x0B1020, 0x172038]
        case .mist: return [0x7D858E, 0xA9AFB6, 0xD5D8DB]
        case .spring: return [0x8FB0D3, 0xC9C2DA, 0xF2D9DC]
        }
    }

    /// 실루엣(지형) 색
    var silhouette: UInt32 {
        switch self {
        case .dawn: return 0x141722
        case .golden: return 0x1A130E
        case .day: return 0x2C3A33
        case .dusk: return 0x140F16
        case .blue: return 0x0A1224
        case .night: return 0x030409
        case .mist: return 0x5E666E
        case .spring: return 0x4C5B4B
        }
    }

    /// 해/빛 번짐 색
    var glow: UInt32 {
        switch self {
        case .dawn: return 0xF6C7A0
        case .golden: return 0xFFD27A
        case .day: return 0xFFF6DA
        case .dusk: return 0xFF9E5E
        case .blue: return 0x9DB4E0
        case .night: return 0xDCE3F5
        case .mist: return 0xF4F1EA
        case .spring: return 0xFFF0E0
        }
    }
}

enum Celestial: Hashable {
    case sun(x: Double, y: Double)
    case moon(x: Double, y: Double)
}

/// 수평선 위에 서는 실루엣
enum Backdrop: Hashable {
    case ridges(layers: Int, height: Double)
    case hills(height: Double)
    case volcano(x: Double, width: Double, height: Double)
    case skyline(lit: Bool, height: Double)
    case tower(x: Double, height: Double, lit: Bool)
    case bridge(lit: Bool)
    case tree(x: Double, scale: Double)
    case pavilion(x: Double, lit: Bool)
    case lighthouse(x: Double)
}

/// 수평선 아래 바닥면
enum Surface: Hashable {
    case sea
    case calmWater
    case land(LandTone)
    case teaRows
    case road(TreeTone)
    case sCurve
}

enum LandTone: String, Hashable { case dark, green, snow, field }
enum TreeTone: String, Hashable { case autumn, green }
enum BlossomTone: String, Hashable { case yellow, pink }

/// 가장 앞에 그리는 요소
enum Foreground: Hashable {
    case rocks
    case blossoms(BlossomTone, density: Double)
    case person(x: Double)
    case lightTrails
    case fog(level: Double)
    case reeds
}
