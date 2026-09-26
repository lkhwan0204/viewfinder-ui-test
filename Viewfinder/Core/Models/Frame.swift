import Foundation

/// 장면 유형. "이런 구도를 찍고 싶다"로 탐색하기 위한 축입니다.
enum SceneType: String, CaseIterable, Codable, Hashable, Identifiable {
    case reflection
    case vanishingPoint
    case silhouette
    case portraitBackdrop
    case lightTrail
    case seascape
    case mountain
    case cityscape
    case fog
    case astro
    case flower
    case architecture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reflection: return "반영"
        case .vanishingPoint: return "소실점"
        case .silhouette: return "실루엣"
        case .portraitBackdrop: return "인물 배경"
        case .lightTrail: return "빛 궤적"
        case .seascape: return "바다"
        case .mountain: return "산"
        case .cityscape: return "도시"
        case .fog: return "안개"
        case .astro: return "별"
        case .flower: return "꽃"
        case .architecture: return "건축"
        }
    }
}

/// 같은 장소라도 "조건"이 맞아야 그 사진이 나옵니다.
enum Condition: String, CaseIterable, Codable, Hashable, Identifiable {
    case clear
    case fog
    case snow
    case blossom
    case calmWater
    case milkyWay
    case lowTide
    case autumnLeaves
    case cloudSea

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: return "맑음"
        case .fog: return "안개"
        case .snow: return "눈"
        case .blossom: return "개화"
        case .calmWater: return "무풍 반영"
        case .milkyWay: return "은하수"
        case .lowTide: return "간조"
        case .autumnLeaves: return "단풍"
        case .cloudSea: return "운해"
        }
    }

    var symbol: String {
        switch self {
        case .clear: return "sun.max"
        case .fog: return "cloud.fog"
        case .snow: return "snowflake"
        case .blossom: return "camera.macro"
        case .calmWater: return "water.waves"
        case .milkyWay: return "sparkles"
        case .lowTide: return "arrow.down.to.line"
        case .autumnLeaves: return "leaf"
        case .cloudSea: return "cloud"
        }
    }

    /// 예보 알림을 보낼 만큼 "특별한" 조건인지
    var isNotable: Bool { self != .clear && self != .lowTide }
}

enum Season: String, CaseIterable, Codable, Hashable, Identifiable {
    case spring, summer, autumn, winter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spring: return "봄"
        case .summer: return "여름"
        case .autumn: return "가을"
        case .winter: return "겨울"
        }
    }

    static func of(month: Int) -> Season {
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

/// 촬영 설정 (35mm 환산 초점거리 기준)
struct CameraSettings: Hashable, Codable {
    var focalLength: Int
    var aperture: Double
    var shutter: String
    var iso: Int
    var tripod: Bool

    /// 수평 화각 (풀프레임 36mm 기준)
    var horizontalFOV: Double {
        2 * atan(36.0 / (2.0 * Double(max(focalLength, 1)))) * 180 / .pi
    }

    var apertureText: String {
        aperture.truncatingRemainder(dividingBy: 1) == 0
            ? "f/\(Int(aperture))"
            : "f/" + String(format: "%.1f", aperture)
    }

    /// 필름 테두리에 찍히는 형태: 24mm  f/11  1/250  ISO 100
    var exifLine: String {
        "\(focalLength)mm  \(apertureText)  \(shutter)  ISO \(iso)"
    }
}

/// 사진의 분위기 (유사 프레임 계산에 사용, 모두 0...1)
struct Mood: Hashable, Codable {
    var warmth: Double
    var brightness: Double
    var calm: Double
}

/// 사진 한 장 = 프레임.
/// "이 자리에서, 이 시간에, 이 방향으로 찍으면 나오는 한 장면"을 표현합니다.
struct Frame: Identifiable, Hashable {
    let id: String
    let placeID: String
    let spotID: String
    let caption: String
    let photographer: String
    let capturedAt: Date
    let camera: CameraSettings
    /// 카메라가 향한 방위각 (0 = 북, 시계 방향)
    let heading: Double
    /// 촬영자가 서 있던 위치
    let coordinate: GeoPoint
    let standingNote: String
    let scenes: Set<SceneType>
    let conditions: Set<Condition>
    let weather: String
    /// 가로 / 세로 비율 (사진은 절대 크롭하지 않습니다)
    let aspectRatio: Double
    let mood: Mood
    /// 실제 사진이 없을 때 그리는 플레이스홀더 장면
    let art: PlaceholderArt
    /// 0...1 — 지도 클러스터의 대표 사진을 고를 때 사용
    let prominence: Double
    /// EXIF 위치와 촬영 포인트가 일치하면 "현장 인증"
    var verified: Bool
    /// Assets에 같은 이름의 이미지가 있으면 실제 사진을 보여줍니다.
    var imageName: String?

    static func == (lhs: Frame, rhs: Frame) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var month: Int { Calendar.kst.component(.month, from: capturedAt) }
    var season: Season { Season.of(month: month) }
}
