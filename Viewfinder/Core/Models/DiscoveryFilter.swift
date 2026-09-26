import Foundation

/// 탐색 화면 상단의 칩. 사진가가 실제로 생각하는 방식(빛, 조건, 장면, 이동 범위)으로 나눕니다.
enum DiscoveryFilter: String, CaseIterable, Identifiable, Hashable {
    case now
    case tonightSunset
    case weekend
    case fog
    case reflection
    case milkyWay
    case nightscape
    case withinHour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: return "지금"
        case .tonightSunset: return "오늘 일몰"
        case .weekend: return "주말"
        case .fog: return "안개"
        case .reflection: return "반영"
        case .milkyWay: return "은하수"
        case .nightscape: return "야경"
        case .withinHour: return "1시간 이내"
        }
    }

    var symbol: String {
        switch self {
        case .now: return "clock"
        case .tonightSunset: return "sunset"
        case .weekend: return "calendar"
        case .fog: return "cloud.fog"
        case .reflection: return "water.waves"
        case .milkyWay: return "sparkles"
        case .nightscape: return "building.2"
        case .withinHour: return "car"
        }
    }

    /// 시간 축 칩은 하나만 켤 수 있습니다.
    var isTimeFilter: Bool { self == .now || self == .tonightSunset || self == .weekend }

    /// 위치 권한이 있으면 더 정확해지는 칩 (처음 누를 때 권한을 요청합니다)
    var wantsLocation: Bool { self == .withinHour || self == .tonightSunset }
}
