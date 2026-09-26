import Foundation

/// 장소·포인트·프레임을 한곳에 모은 저장소. 조회용 인덱스와 빛 구간 캐시를 갖습니다.
struct Catalog {
    private(set) var places: [Place]
    private(set) var frames: [Frame]
    private(set) var reports: [FieldReport]

    private var placeIndex: [String: Place] = [:]
    private var spotIndex: [String: Spot] = [:]
    private var frameIndex: [String: Frame] = [:]
    private var phaseIndex: [String: LightPhase] = [:]

    init(places: [Place], frames: [Frame], reports: [FieldReport] = []) {
        self.places = places
        self.frames = frames
        self.reports = reports
        for place in places {
            placeIndex[place.id] = place
            for spot in place.spots { spotIndex[spot.id] = spot }
        }
        for frame in frames { index(frame) }
    }

    func place(_ id: String) -> Place? { placeIndex[id] }
    func spot(_ id: String) -> Spot? { spotIndex[id] }
    func frame(_ id: String) -> Frame? { frameIndex[id] }

    func frames(atPlace placeID: String) -> [Frame] {
        frames.filter { $0.placeID == placeID }.sorted { $0.prominence > $1.prominence }
    }

    func frames(atSpot spotID: String) -> [Frame] {
        frames.filter { $0.spotID == spotID }.sorted { $0.prominence > $1.prominence }
    }

    /// 촬영 당시의 빛 구간 (캐시)
    func phase(of frame: Frame) -> LightPhase {
        phaseIndex[frame.id] ?? LightClassifier.phase(at: frame.capturedAt, coordinate: frame.coordinate)
    }

    func reports(for placeID: String) -> [FieldReport] {
        reports.filter { $0.placeID == placeID }.sorted { $0.postedAt > $1.postedAt }
    }

    mutating func add(_ frame: Frame) {
        frames.insert(frame, at: 0)
        index(frame)
    }

    mutating func add(_ report: FieldReport) {
        reports.insert(report, at: 0)
    }

    private mutating func index(_ frame: Frame) {
        frameIndex[frame.id] = frame
        phaseIndex[frame.id] = LightClassifier.phase(at: frame.capturedAt, coordinate: frame.coordinate)
    }
}
