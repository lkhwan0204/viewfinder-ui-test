import Foundation

struct DiscoveryContext {
    var now: Date
    /// 사용자의 위치 (권한이 없으면 서울시청)
    var reference: GeoPoint
}

/// 탐색 피드의 필터링과 정렬
enum DiscoveryEngine {
    static func feed(
        from frames: [Frame],
        filters: Set<DiscoveryFilter>,
        seeds: [Frame],
        catalog: Catalog,
        forecast: ForecastProviding,
        context: DiscoveryContext
    ) -> [Frame] {
        let filtered = frames.filter { frame in
            filters.allSatisfy { matches(frame, filter: $0, catalog: catalog, forecast: forecast, context: context) }
        }
        return rank(filtered, seeds: seeds, catalog: catalog)
    }

    static func matches(_ frame: Frame, filter: DiscoveryFilter, catalog: Catalog, forecast: ForecastProviding, context: DiscoveryContext) -> Bool {
        let phase = catalog.phase(of: frame)
        switch filter {
        case .now:
            // 지금의 빛, 또는 1시간 안에 올 빛과 같은 성격의 프레임
            let current = LightClassifier.phase(at: context.now, coordinate: context.reference)
            let soon = LightClassifier.phase(at: context.now.addingTimeInterval(3600), coordinate: context.reference)
            return phase.isSameKind(as: current) || phase.isSameKind(as: soon)
        case .tonightSunset:
            return phase.isEvening && driveMinutes(from: context.reference, to: frame.coordinate) <= 150
        case .weekend:
            guard let place = catalog.place(frame.placeID) else { return false }
            return weekendDays(from: context.now).contains { day in
                let month = Calendar.kst.component(.month, from: day)
                return forecast.outlook(for: place, on: day).likelihood(for: frame.conditions, month: month, bestMonths: place.bestMonths) >= 50
            }
        case .fog:
            return frame.conditions.contains(.fog) || frame.conditions.contains(.cloudSea) || frame.scenes.contains(.fog)
        case .reflection:
            return frame.scenes.contains(.reflection)
        case .milkyWay:
            return frame.conditions.contains(.milkyWay) || frame.scenes.contains(.astro)
        case .nightscape:
            return frame.scenes.contains(.lightTrail) || (frame.scenes.contains(.cityscape) && (phase == .night || phase.isBlue))
        case .withinHour:
            return driveMinutes(from: context.reference, to: frame.coordinate) <= 60
        }
    }

    static func driveMinutes(from a: GeoPoint, to b: GeoPoint) -> Int {
        TravelEstimate.drive(from: a, to: b).minutes
    }

    /// 다가오는 토·일 (오늘이 주말이면 오늘부터)
    static func weekendDays(from now: Date, calendar: Calendar = .kst) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
            .filter { [1, 7].contains(calendar.component(.weekday, from: $0)) }
            .prefix(2)
            .map { $0 }
    }

    /// 온보딩에서 고른 사진(취향)과 닮은 순서 + 대표성. 같은 장소가 연달아 나오지 않게 섞습니다.
    static func rank(_ frames: [Frame], seeds: [Frame], catalog: Catalog) -> [Frame] {
        let scored = frames.map { frame -> (Frame, Double) in
            let taste = seeds.isEmpty ? 0 : seeds.map { seed in
                seed.id == frame.id ? 1 : SimilarityEngine.compare(seed, frame, catalog: catalog).0
            }.max() ?? 0
            return (frame, seeds.isEmpty ? frame.prominence : taste * 0.55 + frame.prominence * 0.45)
        }
        var pool = scored.sorted { $0.1 > $1.1 }.map(\.0)
        var result: [Frame] = []
        while !pool.isEmpty {
            let index = pool.firstIndex { $0.placeID != result.last?.placeID } ?? 0
            result.append(pool.remove(at: index))
        }
        return result
    }
}
