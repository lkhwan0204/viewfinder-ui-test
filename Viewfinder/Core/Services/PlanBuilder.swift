import Foundation

/// 이동 시간 추정 (도로 계수 1.35, 평균 55km/h, 주차 10분). 제주 ↔ 육지는 항공 이동으로 봅니다.
struct Travel: Hashable {
    let distanceKm: Double
    let minutes: Int
    let byAir: Bool

    var text: String {
        let mode = byAir ? "비행기 포함" : "차로"
        return "\(mode) 약 \(VFFormat.duration(minutes: minutes)) · \(Int(distanceKm.rounded()))km"
    }
}

enum TravelEstimate {
    static func drive(from a: GeoPoint, to b: GeoPoint) -> Travel {
        let straight = GeoMath.distance(a, b) / 1000
        let isJejuA = a.latitude < 33.7, isJejuB = b.latitude < 33.7
        if isJejuA != isJejuB {
            return Travel(distanceKm: straight, minutes: 240, byAir: true)
        }
        let road = straight * 1.35
        let raw = road / 55 * 60 + (straight < 0.5 ? 0 : 10)
        let rounded = Int((raw / 5).rounded(.up)) * 5
        return Travel(distanceKm: road, minutes: rounded, byAir: false)
    }
}

/// 같은 빛을 다른 날 다시 만나는 시각
enum ShootTime {
    static func target(for frame: Frame, on day: Date, calendar: Calendar = .kst) -> Date {
        let relation = SunCalculator.relation(of: frame.capturedAt, at: frame.coordinate, calendar: calendar)
        let times = SunCalculator.times(on: day, coordinate: frame.coordinate, calendar: calendar)
        switch relation {
        case let .relative(event, minutes):
            let base = event == .sunrise ? times.sunrise : times.sunset
            if let base { return base.addingTimeInterval(Double(minutes) * 60) }
            return clock(frame: frame, on: day, calendar: calendar)
        case .clock:
            return clock(frame: frame, on: day, calendar: calendar)
        }
    }

    private static func clock(frame: Frame, on day: Date, calendar: Calendar) -> Date {
        let c = calendar.dateComponents([.hour, .minute], from: frame.capturedAt)
        let hour = c.hour ?? 12
        let base = calendar.date(bySettingHour: hour, minute: c.minute ?? 0, second: 0, of: day) ?? day
        // 자정 이후의 별 사진은 "그날 밤"으로 봅니다.
        return hour < 4 ? (calendar.date(byAdding: .day, value: 1, to: base) ?? base) : base
    }
}

struct PlanStop: Identifiable, Hashable {
    var id: String { frame.id }
    let frame: Frame
    let placeName: String
    let spotName: String
    let time: Date
    let relationText: String
    let travel: Travel?
    let warning: String?
}

struct PlanDay: Identifiable, Hashable {
    let id: String
    let date: Date
    let regionName: String
    let stops: [PlanStop]
}

struct ShootingPlan: Hashable {
    let days: [PlanDay]
    var isEmpty: Bool { days.isEmpty }
}

/// 롤 → 촬영 계획. 가까운 프레임끼리 하루로 묶고, 각 포인트의 빛 시간 순서로 정렬합니다.
enum PlanBuilder {
    static func build(frames: [Frame], catalog: Catalog, startDay: Date, calendar: Calendar = .kst) -> ShootingPlan {
        // 1) 90km 안쪽끼리 같은 날로 묶기
        var groups: [[Frame]] = []
        for frame in frames {
            if let index = groups.firstIndex(where: { GeoMath.distance($0[0].coordinate, frame.coordinate) <= 90_000 }) {
                groups[index].append(frame)
            } else {
                groups.append([frame])
            }
        }

        // 2) 날짜별로 빛 시간 순 정렬 + 이동 시간 계산
        var days: [PlanDay] = []
        for (offset, group) in groups.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let timed = group
                .map { (frame: $0, time: ShootTime.target(for: $0, on: day, calendar: calendar)) }
                .sorted { $0.time < $1.time }

            var stops: [PlanStop] = []
            var previous: (frame: Frame, time: Date)?
            for item in timed {
                let place = catalog.place(item.frame.placeID)
                let spot = catalog.spot(item.frame.spotID)
                var travel: Travel?
                var warning: String?
                if let previous {
                    let t = TravelEstimate.drive(from: previous.frame.coordinate, to: item.frame.coordinate)
                    travel = t
                    let gap = Int(item.time.timeIntervalSince(previous.time) / 60)
                    if gap < t.minutes + 10 {
                        warning = "이동에 \(VFFormat.duration(minutes: t.minutes)) 필요 · 일정이 빠듯해요"
                    }
                }
                stops.append(PlanStop(
                    frame: item.frame,
                    placeName: place?.name ?? "",
                    spotName: spot?.name ?? "",
                    time: item.time,
                    relationText: SunCalculator.relation(of: item.frame.capturedAt, at: item.frame.coordinate, calendar: calendar).text,
                    travel: travel,
                    warning: warning
                ))
                previous = item
            }

            let region = group.compactMap { catalog.place($0.placeID)?.regionShort }.first ?? ""
            days.append(PlanDay(id: "day-\(offset)", date: day, regionName: region, stops: stops))
        }
        return ShootingPlan(days: days)
    }
}
