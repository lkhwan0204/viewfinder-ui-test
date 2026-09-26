import Foundation

/// 장소 안에서 실제로 서는 위치 (포인트)
struct Spot: Identifiable, Hashable {
    let id: String
    let placeID: String
    let name: String
    let coordinate: GeoPoint
    /// 접근 방법 (예: 주차장에서 도보 5분)
    let access: String
}

enum Permission: String, Hashable {
    case allowed, limited, prohibited

    var title: String {
        switch self {
        case .allowed: return "가능"
        case .limited: return "제한"
        case .prohibited: return "금지"
        }
    }
}

/// "가기 전에" 섹션 — 리뷰 대신 구조화된 실용 정보
struct PracticalInfo: Hashable {
    var parking: String
    var fee: String
    var tripod: Permission
    var tripodNote: String
    var drone: Permission
    var droneNote: String
    var crowd: String
    var walk: String
    /// 해안 장소만
    var tide: String? = nil
}

/// 민감 장소 보호: 생태 보호구역, 사유지 등은 정확한 위치를 흐리게 처리합니다.
enum Sensitivity: Hashable {
    case open
    case protected(note: String)

    var isProtected: Bool {
        if case .protected = self { return true }
        return false
    }

    var note: String? {
        if case let .protected(note) = self { return note }
        return nil
    }
}

/// 넓은 영역의 장소 (예: 광치기해변)
struct Place: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let summary: String
    let coordinate: GeoPoint
    let spots: [Spot]
    let bestMonths: [Int]
    let practical: PracticalInfo
    let sensitivity: Sensitivity
    let etiquette: [String]
    /// 커뮤니티 초점거리 통계 (버킷 mm → 장수)
    let focalUsage: [Int: Int]

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// "제주 서귀포" → "제주"
    var regionShort: String { region.split(separator: " ").first.map(String.init) ?? region }

    /// 3–4월, 12–2월, 연중
    var bestMonthsText: String { VFFormat.monthRange(bestMonths) }
}

/// 최근 방문자가 남기는 짧은 현장 상태
struct FieldReport: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable, Identifiable {
        case bloom, condition, crowd, closure

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bloom: return "개화·단풍"
            case .condition: return "현장 조건"
            case .crowd: return "혼잡도"
            case .closure: return "통제·공사"
            }
        }

        var symbol: String {
            switch self {
            case .bloom: return "leaf"
            case .condition: return "cloud.sun"
            case .crowd: return "person.2"
            case .closure: return "exclamationmark.triangle"
            }
        }
    }

    let id: String
    let placeID: String
    let postedAt: Date
    let kind: Kind
    let message: String
}
