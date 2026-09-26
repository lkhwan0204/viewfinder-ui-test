import Foundation

struct TargetMatch: Identifiable, Hashable {
    var id: String { frame.id }
    let frame: Frame
    /// 촬영 위치 → 대상 중심 거리 (m)
    let distance: Double
    /// 촬영 위치에서 대상을 바라보는 방위
    let bearing: Double
}

/// 역방향 탐색: "이 대상을 찍을 수 있는 자리는 어디지?"
/// 지도에서 그린 영역이 각 프레임의 시야 부채꼴 안에 들어오는지 확인합니다.
enum FrameTargeting {
    static func frames(aimedAt box: GeoBox, in frames: [Frame], maxDistance: Double = 40_000, angularMargin: Double = 6) -> [TargetMatch] {
        let center = box.center
        let points = box.corners + [center]

        return frames.compactMap { frame -> TargetMatch? in
            // 대상 영역 안에서 찍은 사진은 "대상을 향한 자리"가 아니므로 제외
            if box.contains(frame.coordinate) { return nil }
            let distance = GeoMath.distance(frame.coordinate, center)
            guard distance <= maxDistance else { return nil }

            let half = frame.camera.horizontalFOV / 2 + angularMargin
            let relatives = points.map { GeoMath.signedDelta(from: frame.heading, to: GeoMath.bearing(from: frame.coordinate, to: $0)) }
            let anyInside = relatives.contains { abs($0) <= half }
            // 영역이 화면 중심선을 가로지르는 경우 (영역이 부채꼴보다 넓을 때)
            let straddles = (relatives.min() ?? 0) < 0 && (relatives.max() ?? 0) > 0 && ((relatives.max() ?? 0) - (relatives.min() ?? 0)) < 180
            guard anyInside || straddles else { return nil }

            return TargetMatch(frame: frame, distance: distance, bearing: GeoMath.bearing(from: frame.coordinate, to: center))
        }
        .sorted { $0.distance < $1.distance }
    }
}
