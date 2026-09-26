import Foundation

extension Calendar {
    /// 한국 표준시 기준 그레고리력
    static let kst: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()
}

/// 표시용 포맷터. DateFormatter 대신 캘린더 구성요소로 직접 만들어 결과가 항상 같게 합니다.
enum VFFormat {
    private static let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    /// 06:14
    static func time(_ date: Date, calendar: Calendar = .kst) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// 1시간 12분 / 23분 / 3시간
    static func duration(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m)분" }
        let h = m / 60, rest = m % 60
        return rest == 0 ? "\(h)시간" : "\(h)시간 \(rest)분"
    }

    /// 850m / 3.2km / 38km
    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int((meters / 10).rounded()) * 10)m" }
        let km = meters / 1000
        if km < 10 { return String(format: "%.1fkm", km) }
        return "\(Int(km.rounded()))km"
    }

    /// 16방위 (북, 북북동, 북동, 동북동 …)
    static func compass(_ degrees: Double) -> String {
        let names = ["북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동",
                     "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서"]
        let index = Int((GeoMath.normalize(degrees) / 22.5).rounded()) % 16
        return names[index]
    }

    /// 3월 28일 (토)
    static func dateLabel(_ date: Date, calendar: Calendar = .kst) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday = weekdays[((c.weekday ?? 1) - 1 + 7) % 7]
        return "\(c.month ?? 1)월 \(c.day ?? 1)일 (\(weekday))"
    }

    /// 오늘 / 내일 / 모레 / 3월 28일 (토)
    static func dayLabel(_ date: Date, relativeTo now: Date, calendar: Calendar = .kst) -> String {
        let start = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        switch days {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        default: return dateLabel(date, calendar: calendar)
        }
    }

    /// 3월 말 / 4월 초 / 10월 중순
    static func monthPart(_ date: Date, calendar: Calendar = .kst) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        let day = c.day ?? 15
        let part = day <= 10 ? "초" : (day <= 20 ? "중순" : "말")
        return "\(c.month ?? 1)월 \(part)"
    }

    /// 2일 전 / 5시간 전 / 방금
    static func ago(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분 전" }
        if minutes < 60 * 24 { return "\(minutes / 60)시간 전" }
        return "\(minutes / (60 * 24))일 전"
    }

    /// [3, 4] → 3–4월, [12, 1, 2] → 12–2월, [] → 연중
    static func monthRange(_ months: [Int]) -> String {
        let unique = Array(Set(months)).sorted()
        guard let first = unique.first else { return "연중" }
        if unique.count == 1 { return "\(first)월" }
        if unique.count >= 12 { return "연중" }
        // 연속 구간이 되도록 시작 월을 찾습니다 (12 → 1 로 넘어가는 경우 포함)
        for start in unique {
            var expected = start
            var ok = true
            for _ in unique {
                if !unique.contains(expected) { ok = false; break }
                expected = expected % 12 + 1
            }
            if ok {
                let end = (start + unique.count - 2) % 12 + 1
                return "\(start)–\(end)월"
            }
        }
        return unique.map(String.init).joined(separator: "·") + "월"
    }
}
