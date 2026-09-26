import Foundation

/// 태양 위치. azimuth는 나침반 방위 (0 = 북, 시계 방향), altitude는 지평선 기준 고도(도).
struct SunPosition: Hashable {
    let azimuth: Double
    let altitude: Double
}

/// 하루의 빛 경계 시각
struct SunTimes: Hashable {
    let solarNoon: Date
    /// -18° (천문박명 시작)
    let nightEnd: Date?
    /// -6° (시민박명 시작 = 블루아워 시작)
    let dawn: Date?
    /// -4° (블루아워 끝 = 골든아워 시작)
    let blueMorningEnd: Date?
    /// -0.833° (일출)
    let sunrise: Date?
    /// +6° (아침 골든아워 끝)
    let goldenMorningEnd: Date?
    /// +6° (저녁 골든아워 시작)
    let goldenEveningStart: Date?
    /// -0.833° (일몰)
    let sunset: Date?
    /// -4° (골든아워 끝 = 블루아워 시작)
    let blueEveningStart: Date?
    /// -6° (블루아워 끝)
    let dusk: Date?
    /// -18° (완전한 밤)
    let night: Date?
}

/// 태양 위치/시각 계산 (SunCalc 알고리즘 기반, 네트워크 없이 동작)
enum SunCalculator {
    private static let rad = Double.pi / 180
    private static let j1970 = 2_440_588.0
    private static let j2000 = 2_451_545.0
    private static let obliquity = rad * 23.4397
    private static let j0 = 0.0009

    // MARK: Public

    static func position(at date: Date, coordinate: GeoPoint) -> SunPosition {
        let lw = rad * -coordinate.longitude
        let phi = rad * coordinate.latitude
        let d = toDays(date)
        let c = sunCoords(d)
        let h = siderealTime(d, lw) - c.ra
        // SunCalc의 방위각은 남쪽 기준(서쪽이 +)이므로 나침반 방위로 바꿉니다.
        let azimuthFromSouth = atan2(sin(h), cos(h) * sin(phi) - tan(c.dec) * cos(phi)) / rad
        let altitude = asin(sin(phi) * sin(c.dec) + cos(phi) * cos(c.dec) * cos(h)) / rad
        return SunPosition(azimuth: GeoMath.normalize(azimuthFromSouth + 180), altitude: altitude)
    }

    static func times(on date: Date, coordinate: GeoPoint, calendar: Calendar = .kst) -> SunTimes {
        // 해당 날짜의 현지 정오를 기준으로 계산해야 날짜가 밀리지 않습니다.
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let lw = rad * -coordinate.longitude
        let phi = rad * coordinate.latitude
        let d = toDays(noon)
        let n = (d - j0 - lw / (2 * .pi)).rounded()
        let ds = approxTransit(0, lw, n)
        let m = solarMeanAnomaly(ds)
        let l = eclipticLongitude(m)
        let dec = declination(l, 0)
        let jNoon = solarTransitJ(ds, m, l)

        func pair(_ angle: Double) -> (rise: Date?, set: Date?) {
            let x = (sin(angle * rad) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
            guard x >= -1, x <= 1 else { return (nil, nil) }
            let w = acos(x)
            let jSet = solarTransitJ(approxTransit(w, lw, n), m, l)
            let jRise = jNoon - (jSet - jNoon)
            return (fromJulian(jRise), fromJulian(jSet))
        }

        let astronomical = pair(-18)
        let civil = pair(-6)
        let blue = pair(-4)
        let horizon = pair(-0.833)
        let golden = pair(6)

        return SunTimes(
            solarNoon: fromJulian(jNoon),
            nightEnd: astronomical.rise,
            dawn: civil.rise,
            blueMorningEnd: blue.rise,
            sunrise: horizon.rise,
            goldenMorningEnd: golden.rise,
            goldenEveningStart: golden.set,
            sunset: horizon.set,
            blueEveningStart: blue.set,
            dusk: civil.set,
            night: astronomical.set
        )
    }

    /// 달의 밝기 (0 = 삭, 1 = 보름) — 은하수 촬영 조건에 사용
    static func moonIllumination(at date: Date) -> (fraction: Double, phase: Double) {
        let synodicMonth = 29.530588853
        let knownNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC
        let days = date.timeIntervalSince(knownNewMoon) / 86_400
        var phase = days.truncatingRemainder(dividingBy: synodicMonth) / synodicMonth
        if phase < 0 { phase += 1 }
        return ((1 - cos(2 * .pi * phase)) / 2, phase)
    }

    /// 촬영 시각을 "일출 17분 후" 같은 표현으로 바꿉니다.
    static func relation(of date: Date, at coordinate: GeoPoint, calendar: Calendar = .kst) -> SunRelation {
        let t = times(on: date, coordinate: coordinate, calendar: calendar)
        var candidates: [(SunEvent, Int)] = []
        if let sunrise = t.sunrise { candidates.append((.sunrise, Int((date.timeIntervalSince(sunrise) / 60).rounded()))) }
        if let sunset = t.sunset { candidates.append((.sunset, Int((date.timeIntervalSince(sunset) / 60).rounded()))) }
        if let nearest = candidates.min(by: { abs($0.1) < abs($1.1) }), abs(nearest.1) <= 150 {
            return .relative(nearest.0, minutes: nearest.1)
        }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return .clock(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    // MARK: SunCalc internals

    private static func toJulian(_ date: Date) -> Double { date.timeIntervalSince1970 / 86_400 - 0.5 + j1970 }
    private static func fromJulian(_ j: Double) -> Date { Date(timeIntervalSince1970: (j + 0.5 - j1970) * 86_400) }
    private static func toDays(_ date: Date) -> Double { toJulian(date) - j2000 }

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(obliquity) - tan(b) * sin(obliquity), cos(l))
    }

    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(obliquity) + cos(b) * sin(obliquity) * sin(l))
    }

    private static func siderealTime(_ d: Double, _ lw: Double) -> Double { rad * (280.16 + 360.985_623_5 * d) - lw }
    private static func solarMeanAnomaly(_ d: Double) -> Double { rad * (357.5291 + 0.985_600_28 * d) }

    private static func eclipticLongitude(_ m: Double) -> Double {
        let center = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let perihelion = rad * 102.9372
        return m + center + perihelion + .pi
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let l = eclipticLongitude(solarMeanAnomaly(d))
        return (declination(l, 0), rightAscension(l, 0))
    }

    private static func approxTransit(_ ht: Double, _ lw: Double, _ n: Double) -> Double { j0 + (ht + lw) / (2 * .pi) + n }

    private static func solarTransitJ(_ ds: Double, _ m: Double, _ l: Double) -> Double {
        j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
    }
}

/// 태양 고도로 빛 구간을 나눕니다.
enum LightClassifier {
    static func phase(at date: Date, coordinate: GeoPoint, calendar: Calendar = .kst) -> LightPhase {
        let altitude = SunCalculator.position(at: date, coordinate: coordinate).altitude
        let noon = SunCalculator.times(on: date, coordinate: coordinate, calendar: calendar).solarNoon
        let isMorning = date < noon
        switch altitude {
        case ..<(-6): return .night
        case ..<(-4): return isMorning ? .blueMorning : .blueEvening
        case ..<6: return isMorning ? .goldenMorning : .goldenEvening
        default: return .day
        }
    }
}
