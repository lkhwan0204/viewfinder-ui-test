import Foundation

struct FrameCluster: Identifiable, Hashable {
    var id: String { representative.id }
    /// 이 지역에서 가장 인상적인 한 장
    let representative: Frame
    let members: [Frame]
    var center: GeoPoint { representative.coordinate }
}

/// 지도 줌 수준에 맞춰 가까운 사진을 묶습니다 (화면 거리 기준, 메르카토르 투영).
enum ClusterEngine {
    static func cluster(_ frames: [Frame], region: GeoRegion, width: Double, height: Double, radius: Double = 46) -> [FrameCluster] {
        guard width > 0, height > 0, region.latitudeDelta > 0, region.longitudeDelta > 0 else {
            return frames.map { FrameCluster(representative: $0, members: [$0]) }
        }
        let top = mercatorY(region.maxLatitude)
        let bottom = mercatorY(region.minLatitude)
        let span = max(top - bottom, 1e-9)

        func screenPoint(_ p: GeoPoint) -> (x: Double, y: Double) {
            let x = (p.longitude - region.minLongitude) / region.longitudeDelta * width
            let y = (top - mercatorY(p.latitude)) / span * height
            return (x, y)
        }

        var anchors: [(x: Double, y: Double)] = []
        var groups: [[Frame]] = []
        for frame in frames.sorted(by: { $0.prominence > $1.prominence }) {
            let p = screenPoint(frame.coordinate)
            if let index = anchors.firstIndex(where: { hypot($0.x - p.x, $0.y - p.y) <= radius }) {
                groups[index].append(frame)
            } else {
                anchors.append(p)
                groups.append([frame])
            }
        }
        return groups.map { FrameCluster(representative: $0[0], members: $0) }
    }

    private static func mercatorY(_ latitude: Double) -> Double {
        let phi = GeoMath.radians(max(-85, min(85, latitude)))
        return log(tan(.pi / 4 + phi / 2))
    }
}
