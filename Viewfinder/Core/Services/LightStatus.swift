import Foundation

/// 탐색 화면 상단의 "지금의 빛" 상태. 예) 골든아워까지 1시간 12분
struct LightStatus: Hashable {
    let phase: LightPhase
    let headline: String
}

enum LightStatusBuilder {
    static func status(now: Date, coordinate: GeoPoint, calendar: Calendar = .kst) -> LightStatus {
        let phase = LightClassifier.phase(at: now, coordinate: coordinate, calendar: calendar)
        let today = SunCalculator.times(on: now, coordinate: coordinate, calendar: calendar)

        func minutes(until date: Date?) -> Int? {
            guard let date else { return nil }
            let value = Int((date.timeIntervalSince(now) / 60).rounded(.up))
            return value >= 0 ? value : nil
        }

        switch phase {
        case .goldenMorning:
            return remaining(phase, "골든아워", minutes(until: today.goldenMorningEnd))
        case .goldenEvening:
            return remaining(phase, "골든아워", minutes(until: today.blueEveningStart))
        case .blueMorning:
            return remaining(phase, "블루아워", minutes(until: today.blueMorningEnd))
        case .blueEvening:
            return remaining(phase, "블루아워", minutes(until: today.dusk))
        case .day:
            if let m = minutes(until: today.goldenEveningStart) {
                return LightStatus(phase: phase, headline: "골든아워까지 \(VFFormat.duration(minutes: m))")
            }
            return LightStatus(phase: phase, headline: "한낮")
        case .night:
            let nextDawn: Date?
            if now < today.solarNoon {
                nextDawn = today.dawn
            } else {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                nextDawn = SunCalculator.times(on: tomorrow, coordinate: coordinate, calendar: calendar).dawn
            }
            if let m = minutes(until: nextDawn) {
                return LightStatus(phase: phase, headline: "블루아워까지 \(VFFormat.duration(minutes: m))")
            }
            return LightStatus(phase: phase, headline: "밤")
        }
    }

    private static func remaining(_ phase: LightPhase, _ name: String, _ minutes: Int?) -> LightStatus {
        guard let minutes else { return LightStatus(phase: phase, headline: "지금 \(name)") }
        return LightStatus(phase: phase, headline: "지금 \(name) · \(VFFormat.duration(minutes: minutes)) 남음")
    }
}

/// 해의 방향과 카메라 방향을 비교해 어떤 빛인지 알려줍니다.
struct LightingAdvice: Hashable {
    let title: String
    let detail: String
    /// 카메라 방향 기준 해의 상대 각도 (-180...180, + = 오른쪽)
    let relativeAngle: Double
}

enum LightingAdvisor {
    static func advice(heading: Double, fov: Double, sun: SunPosition) -> LightingAdvice {
        let relative = GeoMath.signedDelta(from: heading, to: sun.azimuth)
        let magnitude = abs(relative)

        if sun.altitude < -18 {
            return LightingAdvice(title: "완전한 밤", detail: "별과 야경의 시간이에요. 삼각대와 긴 노출을 준비하세요.", relativeAngle: relative)
        }
        if sun.altitude < -4 {
            return LightingAdvice(title: "해가 진 뒤", detail: "푸른 하늘빛과 도시 불빛이 균형을 이루는 시간이에요.", relativeAngle: relative)
        }
        if magnitude <= fov / 2 && sun.altitude < 25 {
            return LightingAdvice(title: "해가 화면 안에", detail: "실루엣과 빛 갈라짐을 노려보세요. 노출은 하늘에 맞추세요.", relativeAngle: relative)
        }
        if sun.altitude > 50 {
            return LightingAdvice(title: "높은 해", detail: "그림자가 짧고 대비가 강해요. 그늘 속 인물이나 디테일 컷이 좋아요.", relativeAngle: relative)
        }
        if magnitude <= 70 {
            return LightingAdvice(title: "역광", detail: "윤곽이 빛나고 공기감이 살아나요. 렌즈 후드를 챙기세요.", relativeAngle: relative)
        }
        if magnitude >= 110 {
            return LightingAdvice(title: "순광", detail: "색이 선명하고 하늘이 파랗게 나와요.", relativeAngle: relative)
        }
        return LightingAdvice(title: "측광", detail: "질감과 입체감이 가장 잘 살아나는 빛이에요.", relativeAngle: relative)
    }
}
