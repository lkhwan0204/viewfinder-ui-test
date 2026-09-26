import Foundation

/// 위경도 좌표.
/// Core 레이어는 CoreLocation/MapKit에 의존하지 않도록 순수 Foundation 타입을 씁니다.
/// (지도 변환은 UI 레이어의 `GeoPoint+MapKit.swift`에 있습니다.)
struct GeoPoint: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// 지도에 보이는 영역 (중심 + 위경도 폭)
struct GeoRegion: Hashable {
    var center: GeoPoint
    var latitudeDelta: Double
    var longitudeDelta: Double

    var minLatitude: Double { center.latitude - latitudeDelta / 2 }
    var maxLatitude: Double { center.latitude + latitudeDelta / 2 }
    var minLongitude: Double { center.longitude - longitudeDelta / 2 }
    var maxLongitude: Double { center.longitude + longitudeDelta / 2 }

    /// 대한민국 전체가 보이는 기본 영역
    static let korea = GeoRegion(center: GeoPoint(36.0, 127.8), latitudeDelta: 6.4, longitudeDelta: 5.2)

    /// 주어진 점들을 모두 포함하는 영역 (여백 포함)
    static func fitting(_ points: [GeoPoint], padding: Double = 1.35, minimumDelta: Double = 0.02) -> GeoRegion? {
        guard let first = points.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        return GeoRegion(
            center: GeoPoint((minLat + maxLat) / 2, (minLon + maxLon) / 2),
            latitudeDelta: max((maxLat - minLat) * padding, minimumDelta),
            longitudeDelta: max((maxLon - minLon) * padding, minimumDelta)
        )
    }
}

/// 축에 정렬된 위경도 박스. 역방향 탐색에서 "찍고 싶은 대상"을 표현합니다.
struct GeoBox: Hashable {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double

    init(corner a: GeoPoint, _ b: GeoPoint) {
        minLatitude = min(a.latitude, b.latitude)
        maxLatitude = max(a.latitude, b.latitude)
        minLongitude = min(a.longitude, b.longitude)
        maxLongitude = max(a.longitude, b.longitude)
    }

    var center: GeoPoint { GeoPoint((minLatitude + maxLatitude) / 2, (minLongitude + maxLongitude) / 2) }

    /// 남서 → 남동 → 북동 → 북서
    var corners: [GeoPoint] {
        [
            GeoPoint(minLatitude, minLongitude),
            GeoPoint(minLatitude, maxLongitude),
            GeoPoint(maxLatitude, maxLongitude),
            GeoPoint(maxLatitude, minLongitude)
        ]
    }

    func contains(_ point: GeoPoint) -> Bool {
        (minLatitude...maxLatitude).contains(point.latitude) && (minLongitude...maxLongitude).contains(point.longitude)
    }
}

enum GeoMath {
    static let earthRadius = 6_371_000.0

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// 두 점 사이 거리 (m, haversine)
    static func distance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let lat1 = radians(a.latitude), lat2 = radians(b.latitude)
        let dLat = lat2 - lat1
        let dLon = radians(b.longitude - a.longitude)
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// a에서 b를 바라보는 방위각 (0 = 북, 시계 방향, 0..<360)
    static func bearing(from a: GeoPoint, to b: GeoPoint) -> Double {
        let lat1 = radians(a.latitude), lat2 = radians(b.latitude)
        let dLon = radians(b.longitude - a.longitude)
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalize(degrees(atan2(y, x)))
    }

    /// 한 점에서 방위각/거리만큼 이동한 점
    static func destination(from point: GeoPoint, bearing: Double, distance: Double) -> GeoPoint {
        let delta = distance / earthRadius
        let theta = radians(bearing)
        let lat1 = radians(point.latitude), lon1 = radians(point.longitude)
        let lat2 = asin(sin(lat1) * cos(delta) + cos(lat1) * sin(delta) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(delta) * cos(lat1), cos(delta) - sin(lat1) * sin(lat2))
        return GeoPoint(degrees(lat2), degrees(lon2))
    }

    /// 0..<360 으로 정규화
    static func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// a → b 로 가는 가장 짧은 회전각 (-180, 180]
    static func signedDelta(from a: Double, to b: Double) -> Double {
        var delta = normalize(b - a)
        if delta > 180 { delta -= 360 }
        return delta
    }
}
