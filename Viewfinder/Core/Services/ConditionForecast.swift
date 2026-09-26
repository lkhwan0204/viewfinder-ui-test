import Foundation

/// 장소·날짜별 촬영 조건 예보
struct ConditionOutlook: Hashable {
    let placeID: String
    let date: Date
    let fogChance: Int
    let cloudCover: Int
    let windSpeed: Double
    let snowChance: Int
    let moonIllumination: Double

    /// 조건 하나의 가능성 (0...100)
    func likelihood(of condition: Condition, month: Int, bestMonths: [Int]) -> Int {
        switch condition {
        case .clear: return 100 - cloudCover
        case .fog: return fogChance
        case .cloudSea: return cloudCover < 70 ? Int(Double(fogChance) * 0.8) : fogChance / 3
        case .calmWater: return max(0, min(100, Int(100 - windSpeed * 22)))
        case .milkyWay:
            guard (3...10).contains(month) else { return 0 }
            return Int(Double(100 - cloudCover) * (1 - moonIllumination))
        case .snow: return snowChance
        case .blossom: return bestMonths.contains(month) ? 80 : 5
        case .autumnLeaves: return (10...11).contains(month) ? 85 : 5
        case .lowTide: return 70
        }
    }

    /// 여러 조건이 모두 맞을 가능성 — 가장 약한 조건을 기준으로 합니다.
    func likelihood(for conditions: Set<Condition>, month: Int, bestMonths: [Int]) -> Int {
        guard !conditions.isEmpty else { return 100 - cloudCover }
        return conditions.map { likelihood(of: $0, month: month, bestMonths: bestMonths) }.min() ?? 0
    }

    var summary: String {
        "구름 \(cloudCover)% · 바람 \(String(format: "%.1f", windSpeed))m/s · 안개 \(fogChance)%"
    }
}

/// 실제 서비스에서는 WeatherKit + 물때 API로 교체할 수 있도록 프로토콜로 둡니다.
protocol ForecastProviding {
    func outlook(for place: Place, on date: Date) -> ConditionOutlook
}

/// 샘플 예보. 장소와 날짜로 시드를 만들어 항상 같은 값을 돌려줍니다. (실제 날씨가 아닙니다)
struct SampleForecast: ForecastProviding {
    /// 안개가 잘 끼는 장소
    var fogBias: [String: Int] = ["dumulmeori": 38, "boseong": 30, "anbandegi": 14, "ojori": 10]
    /// 하늘이 맑은 편인 장소
    var clearBias: [String: Int] = ["anbandegi": 20]

    func outlook(for place: Place, on date: Date) -> ConditionOutlook {
        let dayNumber = Int((date.timeIntervalSince1970 + 9 * 3600) / 86_400)
        var rng = SeededRandom(seed: StableHash.fnv1a(place.id) ^ (UInt64(dayNumber) &* 0x9E37_79B9_7F4A_7C15))
        let month = Calendar.kst.component(.month, from: date)
        let fog = min(95, Int(rng.range(0, 60)) + (fogBias[place.id] ?? 0))
        let cloud = max(0, Int(rng.range(0, 90)) - (clearBias[place.id] ?? 0))
        let wind = rng.range(0.3, 6.5)
        let snow = (month == 12 || month <= 2) ? Int(rng.range(0, 70)) : 0
        return ConditionOutlook(
            placeID: place.id,
            date: date,
            fogChance: fog,
            cloudCover: cloud,
            windSpeed: wind,
            snowChance: snow,
            moonIllumination: SunCalculator.moonIllumination(at: date).fraction
        )
    }
}

/// "저장한 두물머리 물안개 프레임, 내일 새벽 안개 가능성 72%" 같은 조건 알림
struct ConditionAlert: Identifiable, Hashable {
    let id: String
    let frameID: String
    let placeID: String
    let date: Date
    let condition: Condition
    let likelihood: Int
    let headline: String
    let detail: String
}

enum AlertEngine {
    static func alerts(
        for frames: [Frame],
        catalog: Catalog,
        forecast: ForecastProviding,
        now: Date,
        days: Int = 3,
        threshold: Int = 60
    ) -> [ConditionAlert] {
        var result: [ConditionAlert] = []
        for frame in frames {
            guard let place = catalog.place(frame.placeID) else { continue }
            let notable = frame.conditions.filter(\.isNotable)
            guard !notable.isEmpty else { continue }
            let phase = catalog.phase(of: frame)

            dayLoop: for offset in 0..<days {
                guard let day = Calendar.kst.date(byAdding: .day, value: offset, to: now) else { continue }
                let shootTime = ShootTime.target(for: frame, on: day)
                if shootTime < now { continue }
                let outlook = forecast.outlook(for: place, on: day)
                let month = Calendar.kst.component(.month, from: day)
                let scored = notable
                    .map { ($0, outlook.likelihood(of: $0, month: month, bestMonths: place.bestMonths)) }
                    .sorted { $0.1 > $1.1 }
                guard let best = scored.first, best.1 >= threshold else { continue }

                let dayWord = VFFormat.dayLabel(day, relativeTo: now)
                let detail = "\(dayWord) \(timeWord(phase)) \(best.0.title) 가능성 \(best.1)% · \(eventText(frame: frame, phase: phase, day: day, outlook: outlook))"
                result.append(ConditionAlert(
                    id: "\(frame.id)-\(offset)",
                    frameID: frame.id,
                    placeID: place.id,
                    date: shootTime,
                    condition: best.0,
                    likelihood: best.1,
                    headline: "저장한 \(place.name) \(best.0.title) 프레임",
                    detail: detail
                ))
                break dayLoop
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func timeWord(_ phase: LightPhase) -> String {
        switch phase {
        case .blueMorning: return "새벽"
        case .goldenMorning: return "아침"
        case .day: return "낮"
        case .goldenEvening, .blueEvening: return "저녁"
        case .night: return "밤"
        }
    }

    private static func eventText(frame: Frame, phase: LightPhase, day: Date, outlook: ConditionOutlook) -> String {
        let times = SunCalculator.times(on: day, coordinate: frame.coordinate)
        if phase.isMorning, let sunrise = times.sunrise { return "일출 \(VFFormat.time(sunrise))" }
        if phase.isEvening, let sunset = times.sunset { return "일몰 \(VFFormat.time(sunset))" }
        if phase == .night { return "달 밝기 \(Int(outlook.moonIllumination * 100))%" }
        return "구름 \(outlook.cloudCover)%"
    }
}
