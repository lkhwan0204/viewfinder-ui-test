import Foundation

struct SimilarityMatch: Identifiable, Hashable {
    var id: String { frame.id }
    let frame: Frame
    let score: Double
    /// 공통점 설명 (예: 반영 · 블루아워 · 24mm 근처)
    let reasons: [String]
}

/// "이런 느낌의 다른 곳" — 장면 유형, 빛, 분위기, 화각으로 비슷한 프레임을 찾습니다.
/// 실제 서비스에서는 이미지 임베딩 유사도로 교체할 수 있습니다.
enum SimilarityEngine {
    static func similar(to source: Frame, in frames: [Frame], catalog: Catalog, limit: Int = 12, excludeSamePlace: Bool = true) -> [SimilarityMatch] {
        frames
            .filter { $0.id != source.id && (!excludeSamePlace || $0.placeID != source.placeID) }
            .map { candidate -> SimilarityMatch in
                let (score, reasons) = compare(source, candidate, catalog: catalog)
                return SimilarityMatch(frame: candidate, score: score, reasons: reasons)
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    static func compare(_ a: Frame, _ b: Frame, catalog: Catalog) -> (Double, [String]) {
        var reasons: [String] = []

        // 장면 유형 (Jaccard)
        let common = a.scenes.intersection(b.scenes)
        let union = a.scenes.union(b.scenes)
        let sceneScore = union.isEmpty ? 0 : Double(common.count) / Double(union.count)
        reasons += SceneType.allCases.filter { common.contains($0) }.prefix(2).map(\.title)

        // 빛
        let phaseA = catalog.phase(of: a), phaseB = catalog.phase(of: b)
        var lightScore = 0.0
        if phaseA == phaseB {
            lightScore = 1
            reasons.append(phaseA.shortTitle)
        } else if phaseA.isSameKind(as: phaseB) {
            lightScore = 0.7
            reasons.append(phaseA.shortTitle)
        }

        // 분위기 (따뜻함, 밝기, 고요함)
        let dw = a.mood.warmth - b.mood.warmth
        let db = a.mood.brightness - b.mood.brightness
        let dc = a.mood.calm - b.mood.calm
        let moodScore = max(0, 1 - sqrt(dw * dw + db * db + dc * dc) / sqrt(3))

        // 화각
        let ratio = Double(max(a.camera.focalLength, b.camera.focalLength)) / Double(max(1, min(a.camera.focalLength, b.camera.focalLength)))
        let focalScore = max(0, 1 - log2(ratio) / 3)
        if ratio <= 1.5 { reasons.append("\(b.camera.focalLength)mm 근처") }

        let score = sceneScore * 0.45 + lightScore * 0.2 + moodScore * 0.25 + focalScore * 0.1
        return (score, Array(reasons.prefix(3)))
    }
}
