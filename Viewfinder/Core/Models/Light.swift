import Foundation

/// 사진가 관점의 빛 구간. 태양 고도와 오전/오후로 나눕니다.
/// - 밤: 고도 < -6°
/// - 블루아워: -6° ~ -4°
/// - 골든아워: -4° ~ +6°
/// - 한낮: +6° 이상
enum LightPhase: String, CaseIterable, Codable, Hashable, Identifiable {
    case night
    case blueMorning
    case goldenMorning
    case day
    case goldenEvening
    case blueEvening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .night: return "밤"
        case .blueMorning: return "새벽 블루아워"
        case .goldenMorning: return "아침 골든아워"
        case .day: return "한낮"
        case .goldenEvening: return "저녁 골든아워"
        case .blueEvening: return "저녁 블루아워"
        }
    }

    /// 짧은 이름 (칩, 태그용)
    var shortTitle: String {
        switch self {
        case .night: return "밤"
        case .blueMorning, .blueEvening: return "블루아워"
        case .goldenMorning, .goldenEvening: return "골든아워"
        case .day: return "한낮"
        }
    }

    var symbol: String {
        switch self {
        case .night: return "moon.stars"
        case .blueMorning, .blueEvening: return "sun.horizon"
        case .goldenMorning: return "sunrise"
        case .goldenEvening: return "sunset"
        case .day: return "sun.max"
        }
    }

    var isGolden: Bool { self == .goldenMorning || self == .goldenEvening }
    var isBlue: Bool { self == .blueMorning || self == .blueEvening }
    var isMorning: Bool { self == .blueMorning || self == .goldenMorning }
    var isEvening: Bool { self == .goldenEvening || self == .blueEvening }

    /// 같은 성격의 빛인지 (아침 골든아워 ↔ 저녁 골든아워)
    func isSameKind(as other: LightPhase) -> Bool { shortTitle == other.shortTitle }
}

enum SunEvent: String, Hashable {
    case sunrise
    case sunset

    var title: String { self == .sunrise ? "일출" : "일몰" }
}

/// 촬영 시각을 "해"를 기준으로 표현합니다. 예) 일출 17분 후, 일몰 12분 전
enum SunRelation: Hashable {
    case relative(SunEvent, minutes: Int)
    case clock(hour: Int, minute: Int)

    var text: String {
        switch self {
        case let .relative(event, minutes):
            if minutes == 0 { return "\(event.title) 순간" }
            let amount = VFFormat.duration(minutes: abs(minutes))
            return "\(event.title) \(amount) \(minutes > 0 ? "후" : "전")"
        case let .clock(hour, minute):
            return String(format: "%02d:%02d", hour, minute)
        }
    }
}
