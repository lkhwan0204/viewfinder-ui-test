import Foundation

// 샘플 데이터 — 실제 사진 대신 PlaceholderArt로 장면을 그립니다.
// 좌표와 방향은 실제 장소를 기준으로 잡아서 역방향 탐색(성산일출봉·남산타워)이 실제처럼 동작합니다.

extension Catalog {
    static func sample(now: Date = Date()) -> Catalog {
        Catalog(places: SampleData.places, frames: SampleData.frames, reports: SampleData.reports(now: now))
    }
}

enum SampleData {
    // MARK: Helpers

    private static func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.kst.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? Date()
    }

    private static func cam(_ focal: Int, _ aperture: Double, _ shutter: String, _ iso: Int, tripod: Bool = false) -> CameraSettings {
        CameraSettings(focalLength: focal, aperture: aperture, shutter: shutter, iso: iso, tripod: tripod)
    }

    private static func spot(_ id: String, _ place: String, _ name: String, _ lat: Double, _ lon: Double, _ access: String) -> Spot {
        Spot(id: id, placeID: place, name: name, coordinate: GeoPoint(lat, lon), access: access)
    }

    private static func frame(
        _ id: String, place: String, spot: String, _ caption: String, by photographer: String,
        at date: Date, _ camera: CameraSettings, heading: Double, standing: String,
        scenes: Set<SceneType>, conditions: Set<Condition>, weather: String,
        aspect: Double, mood: Mood, art: PlaceholderArt, prominence: Double, verified: Bool = true
    ) -> Frame {
        let coordinate = places.first { $0.id == place }?.spots.first { $0.id == spot }?.coordinate ?? GeoPoint(0, 0)
        return Frame(
            id: id, placeID: place, spotID: spot, caption: caption, photographer: photographer,
            capturedAt: date, camera: camera, heading: heading, coordinate: coordinate,
            standingNote: standing, scenes: scenes, conditions: conditions, weather: weather,
            aspectRatio: aspect, mood: mood, art: art, prominence: prominence, verified: verified
        )
    }

    // MARK: Places

    static let places: [Place] = [
        Place(
            id: "gwangchigi", name: "광치기해변", region: "제주 서귀포",
            summary: "간조 때 드러나는 이끼 바위 너머로 성산일출봉이 떠오르는 해변",
            coordinate: GeoPoint(33.4510, 126.9225),
            spots: [
                spot("gwangchigi-rocks", "gwangchigi", "북쪽 이끼 바위", 33.4521, 126.9240, "주차장에서 해변 따라 도보 5분 · 간조 때만 접근"),
                spot("gwangchigi-center", "gwangchigi", "해변 중앙 모래톱", 33.4502, 126.9222, "주차장 바로 앞"),
                spot("gwangchigi-hill", "gwangchigi", "도로변 유채꽃 언덕", 33.4488, 126.9195, "해안도로 갓길 · 사유지 경계 주의")
            ],
            bestMonths: [3, 4],
            practical: PracticalInfo(
                parking: "광치기해변 공영주차장 (무료)", fee: "무료",
                tripod: .allowed, tripodNote: "바위 위는 미끄러워요",
                drone: .limited, droneNote: "성산일출봉 주변 비행 제한 구역 확인",
                crowd: "일출 30분 전부터 붐벼요 · 평일이 한산", walk: "주차장에서 해변까지 1분",
                tide: "간조 전후 2시간에 이끼 바위가 드러나요"
            ),
            sensitivity: .open,
            etiquette: ["이끼 바위는 밟으면 훼손돼요. 모래 쪽에서 담아주세요.", "유채꽃밭은 사유지예요. 입장료가 있는 곳만 들어가세요."],
            focalUsage: [14: 8, 24: 34, 35: 21, 50: 9, 85: 5, 135: 3, 200: 2]
        ),
        Place(
            id: "seopjikoji", name: "섭지코지", region: "제주 서귀포",
            summary: "붉은 등대 언덕에서 바다 건너 일출봉을 망원으로 당겨 담는 곳",
            coordinate: GeoPoint(33.4240, 126.9310),
            spots: [spot("seopji-lighthouse", "seopjikoji", "등대 언덕", 33.4250, 126.9318, "섭지코지 주차장에서 도보 15분")],
            bestMonths: [4, 5],
            practical: PracticalInfo(
                parking: "섭지코지 주차장 (유료 1,000원)", fee: "무료",
                tripod: .allowed, tripodNote: "산책로 밖 초지로 나가지 마세요",
                drone: .limited, droneNote: "관광객 머리 위 비행 금지",
                crowd: "오후 관광객 많음 · 일몰 무렵 한산", walk: "완만한 언덕길 도보 15분",
                tide: "바람이 강한 날이 많아요"
            ),
            sensitivity: .open,
            etiquette: ["산책로 밖 초지는 보호 구역이에요."],
            focalUsage: [14: 2, 24: 10, 35: 12, 50: 9, 85: 14, 135: 11, 200: 6]
        ),
        Place(
            id: "ojori", name: "오조리 내수면", region: "제주 서귀포",
            summary: "잔잔한 내수면에 일출봉이 거꾸로 비치는 새벽 반영 포인트",
            coordinate: GeoPoint(33.4650, 126.9170),
            spots: [spot("ojo-lagoon", "ojori", "내수면 둑길", 33.4655, 126.9185, "마을 공터 주차 후 둑길 도보 3분")],
            bestMonths: [10, 11, 12],
            practical: PracticalInfo(
                parking: "마을 공터 (주민 차량 우선)", fee: "무료",
                tripod: .allowed, tripodNote: "둑길이 좁아요 · 통행로 확보",
                drone: .prohibited, droneNote: "철새 도래지 · 비행 금지",
                crowd: "새벽에도 사진가 10명 안팎", walk: "둑길 평지",
                tide: "만조 때 수면이 넓어져 반영이 커져요"
            ),
            sensitivity: .protected(note: "철새 도래지예요. 11–2월에는 둑 끝 쪽 접근을 자제해 주세요."),
            etiquette: ["새벽 마을이에요. 차 문 소리와 대화를 줄여주세요.", "철새가 앉아 있으면 플래시와 드론을 쓰지 마세요."],
            focalUsage: [14: 4, 24: 22, 35: 15, 50: 6, 85: 3, 135: 1, 200: 0]
        ),
        Place(
            id: "banpo", name: "반포한강공원", region: "서울 서초구",
            summary: "달빛무지개분수와 잠수교, 남산을 한 번에 담는 한강 야경의 기본",
            coordinate: GeoPoint(37.5112, 126.9960),
            spots: [
                spot("banpo-steps", "banpo", "세빛섬 남단 계단", 37.5110, 126.9947, "고속터미널역 8-1번 출구 도보 15분"),
                spot("banpo-riverside", "banpo", "잠수교 남단 둔치", 37.5125, 126.9960, "반포한강공원 2주차장 도보 5분")
            ],
            bestMonths: [4, 5, 6, 9, 10],
            practical: PracticalInfo(
                parking: "반포한강공원 주차장 (유료)", fee: "무료",
                tripod: .allowed, tripodNote: "분수 쇼 시간엔 계단이 붐벼요",
                drone: .prohibited, droneNote: "한강 전 구역 비행 금지 (P73)",
                crowd: "주말 저녁 매우 혼잡 · 평일 20시 이후 추천", walk: "평지 · 자전거 도로 주의"
            ),
            sensitivity: .open,
            etiquette: ["자전거 도로에 삼각대를 펴지 마세요."],
            focalUsage: [14: 6, 24: 28, 35: 18, 50: 10, 85: 8, 135: 9, 200: 5]
        ),
        Place(
            id: "eungbongsan", name: "응봉산", region: "서울 성동구",
            summary: "봄엔 개나리 언덕, 밤엔 강변북로 빛 궤적이 흐르는 도심 전망대",
            coordinate: GeoPoint(37.5503, 127.0319),
            spots: [spot("eungbong-pavilion", "eungbongsan", "팔각정 데크", 37.5503, 127.0319, "응봉역에서 계단 도보 15분")],
            bestMonths: [3, 4],
            practical: PracticalInfo(
                parking: "응봉근린공원 주차장 (협소)", fee: "무료",
                tripod: .limited, tripodNote: "데크가 좁아요 · 한 자리 오래 점유 금지",
                drone: .prohibited, droneNote: "서울 도심 비행 금지",
                crowd: "개나리철 주말 저녁은 줄 서서 촬영", walk: "계단 오르막 15분"
            ),
            sensitivity: .open,
            etiquette: ["데크 난간 위에 장비를 올려두지 마세요."],
            focalUsage: [14: 3, 24: 12, 35: 10, 50: 16, 85: 14, 135: 7, 200: 4]
        ),
        Place(
            id: "naksan", name: "낙산공원 성곽길", region: "서울 종로구",
            summary: "성곽을 따라 걷다 보면 노을 진 도심이 배경이 되는 스냅 명소",
            coordinate: GeoPoint(37.5806, 127.0075),
            spots: [spot("naksan-wall", "naksan", "성곽 안쪽 산책로", 37.5800, 127.0068, "혜화역 2번 출구 도보 15분")],
            bestMonths: [4, 5, 10, 11],
            practical: PracticalInfo(
                parking: "낙산공원 주차장 (유료)", fee: "무료",
                tripod: .allowed, tripodNote: "산책로 통행 우선",
                drone: .prohibited, droneNote: "서울 도심 비행 금지",
                crowd: "노을 30분 전부터 붐벼요", walk: "완만한 오르막 15분"
            ),
            sensitivity: .open,
            etiquette: ["성곽 위로 올라가지 마세요.", "주민이 사는 집 쪽으로는 렌즈를 향하지 마세요."],
            focalUsage: [14: 1, 24: 6, 35: 18, 50: 24, 85: 20, 135: 5, 200: 1]
        ),
        Place(
            id: "dumulmeori", name: "두물머리", region: "경기 양평",
            summary: "400년 느티나무와 물안개, 남한강과 북한강이 만나는 새벽",
            coordinate: GeoPoint(37.5345, 127.3185),
            spots: [
                spot("dumul-tree", "dumulmeori", "느티나무 앞 물가", 37.5347, 127.3180, "두물머리 주차장에서 도보 7분"),
                spot("dumul-bridge", "dumulmeori", "배다리 입구", 37.5360, 127.3150, "세미원 배다리 쪽 도보 10분")
            ],
            bestMonths: [10, 11, 12, 1],
            practical: PracticalInfo(
                parking: "두물머리 공영주차장 (유료)", fee: "무료",
                tripod: .allowed, tripodNote: "느티나무 보호 펜스 안쪽 금지",
                drone: .limited, droneNote: "상수원 보호구역 · 사전 승인 필요",
                crowd: "가을 주말 새벽 5시부터 자리 경쟁", walk: "평지 산책로"
            ),
            sensitivity: .open,
            etiquette: ["느티나무 보호 펜스 안으로 들어가지 마세요."],
            focalUsage: [14: 5, 24: 20, 35: 22, 50: 12, 85: 9, 135: 6, 200: 3]
        ),
        Place(
            id: "anbandegi", name: "안반데기", region: "강원 강릉",
            summary: "해발 1,100m 고랭지 배추밭 위로 은하수가 흐르는 곳",
            coordinate: GeoPoint(37.6245, 128.7420),
            spots: [spot("anban-observatory", "anbandegi", "멍에전망대", 37.6260, 128.7425, "전망대 주차장 바로 옆")],
            bestMonths: [6, 7, 8, 9],
            practical: PracticalInfo(
                parking: "멍에전망대 주차장 (무료, 협소)", fee: "무료",
                tripod: .allowed, tripodNote: "전망대에서만",
                drone: .limited, droneNote: "야간 비행은 승인 필요",
                crowd: "은하수 시즌 주말 밤 혼잡", walk: "주차장에서 1분"
            ),
            sensitivity: .protected(note: "농민의 생계 터전이에요. 밭 안쪽 포인트는 공개하지 않아요."),
            etiquette: ["밭 안으로 들어가지 마세요. 전망대에서만 촬영하세요.", "헤드라이트와 손전등은 적색광으로 바꿔주세요.", "차박과 취사는 금지예요."],
            focalUsage: [14: 30, 24: 18, 35: 5, 50: 2, 85: 4, 135: 2, 200: 1]
        ),
        Place(
            id: "gwangalli", name: "광안리 해변", region: "부산 수영구",
            summary: "해변과 민락 방파제에서 광안대교를 정면·측면으로 담는 곳",
            coordinate: GeoPoint(35.1532, 129.1186),
            spots: [
                spot("gwangan-beach", "gwangalli", "해변 모래사장", 35.1535, 129.1190, "광안역 3번 출구 도보 10분"),
                spot("millak-breakwater", "gwangalli", "민락수변공원 방파제", 35.1555, 129.1312, "민락수변공원 주차장 도보 3분")
            ],
            bestMonths: [5, 6, 7, 8, 11],
            practical: PracticalInfo(
                parking: "해변 공영주차장 (유료)", fee: "무료",
                tripod: .allowed, tripodNote: "모래사장 가능",
                drone: .prohibited, droneNote: "해수욕장 비행 금지",
                crowd: "여름 밤·불꽃축제 기간 매우 혼잡", walk: "평지",
                tide: "만조 때 방파제 끝 파도 주의"
            ),
            sensitivity: .open,
            etiquette: ["방파제 테트라포드 위로 올라가지 마세요."],
            focalUsage: [14: 5, 24: 24, 35: 14, 50: 12, 85: 10, 135: 8, 200: 6]
        ),
        Place(
            id: "igidae", name: "이기대 해안산책로", region: "부산 남구",
            summary: "갯바위 너머 해운대 마린시티 스카이라인이 빛나는 야경 포인트",
            coordinate: GeoPoint(35.1255, 129.1225),
            spots: [spot("igidae-point", "igidae", "동생말 전망대", 35.1285, 129.1230, "이기대 입구 주차장 도보 10분")],
            bestMonths: [10, 11, 12, 1, 2],
            practical: PracticalInfo(
                parking: "이기대 입구 공영주차장", fee: "무료",
                tripod: .allowed, tripodNote: "데크 통행 우선",
                drone: .limited, droneNote: "해운대 방향 비행 제한",
                crowd: "야경 시간대 보통", walk: "해안 데크 계단 10분",
                tide: "파도가 높으면 갯바위 접근 금지"
            ),
            sensitivity: .open,
            etiquette: ["밤의 해안 산책로는 어두워요. 헤드랜턴을 챙기세요."],
            focalUsage: [14: 3, 24: 14, 35: 12, 50: 16, 85: 9, 135: 5, 200: 2]
        ),
        Place(
            id: "donggung", name: "동궁과 월지", region: "경북 경주",
            summary: "연못에 비친 전각이 가장 아름다운 블루아워",
            coordinate: GeoPoint(35.8347, 129.2266),
            spots: [spot("donggung-west", "donggung", "서쪽 연못가", 35.8345, 129.2255, "정문 입장 후 오른쪽 산책로")],
            bestMonths: [4, 7, 10, 11],
            practical: PracticalInfo(
                parking: "동궁과 월지 주차장 (무료)", fee: "3,000원 (21:30 입장 마감)",
                tripod: .limited, tripodNote: "혼잡할 때는 사용 자제 요청",
                drone: .prohibited, droneNote: "사적지 비행 금지",
                crowd: "일몰 직후 가장 붐빔 · 21시 이후 한산", walk: "평지 산책로"
            ),
            sensitivity: .open,
            etiquette: ["연못가 난간에 기대지 마세요.", "다른 관람객 동선을 막지 마세요."],
            focalUsage: [14: 7, 24: 26, 35: 16, 50: 8, 85: 4, 135: 2, 200: 1]
        ),
        Place(
            id: "damyang", name: "담양 메타세쿼이아길", region: "전남 담양",
            summary: "끝없이 이어지는 가로수가 만드는 완벽한 소실점",
            coordinate: GeoPoint(35.3240, 126.9865),
            spots: [spot("damyang-center", "damyang", "가로수길 중앙", 35.3245, 126.9880, "매표소에서 도보 5분")],
            bestMonths: [6, 7, 11],
            practical: PracticalInfo(
                parking: "메타세쿼이아길 주차장 (유료)", fee: "2,000원",
                tripod: .limited, tripodNote: "길 가운데는 통행로 · 가장자리에서만",
                drone: .prohibited, droneNote: "관광지 비행 금지",
                crowd: "주말 오후 혼잡 · 개장 직후 추천", walk: "평지"
            ),
            sensitivity: .open,
            etiquette: ["길 한가운데에 오래 서 있지 마세요."],
            focalUsage: [14: 2, 24: 10, 35: 12, 50: 14, 85: 18, 135: 12, 200: 8]
        ),
        Place(
            id: "boseong", name: "보성 녹차밭", region: "전남 보성",
            summary: "물결치는 차밭 이랑에 새벽 안개가 내려앉는 곳",
            coordinate: GeoPoint(34.7115, 127.0808),
            spots: [spot("boseong-ridge", "boseong", "전망대 능선", 34.7125, 127.0820, "농원 입구에서 오르막 20분")],
            bestMonths: [4, 5, 6],
            practical: PracticalInfo(
                parking: "농원 주차장 (무료)", fee: "4,000원",
                tripod: .allowed, tripodNote: "이랑 사이 출입 금지",
                drone: .limited, droneNote: "사유지 · 농원 허가 필요",
                crowd: "5월 주말 혼잡", walk: "오르막 계단 20분"
            ),
            sensitivity: .open,
            etiquette: ["차밭 이랑 사이로 들어가지 마세요."],
            focalUsage: [14: 1, 24: 8, 35: 10, 50: 12, 85: 16, 135: 12, 200: 7]
        ),
        Place(
            id: "suncheon", name: "순천만 용산전망대", region: "전남 순천",
            summary: "S자 물길이 노을빛으로 물드는 순천만의 대표 풍경",
            coordinate: GeoPoint(34.8845, 127.5115),
            spots: [
                spot("suncheon-yongsan", "suncheon", "용산전망대", 34.8835, 127.5120, "습지 입구에서 도보 40분"),
                spot("suncheon-deck", "suncheon", "갈대 데크길", 34.8860, 127.5095, "습지 입구에서 도보 10분")
            ],
            bestMonths: [10, 11],
            practical: PracticalInfo(
                parking: "순천만습지 주차장 (유료)", fee: "8,000원 (국가정원 통합권)",
                tripod: .allowed, tripodNote: "전망대 앞줄은 교대로",
                drone: .prohibited, droneNote: "습지보호지역 비행 금지",
                crowd: "가을 일몰 전망대 매우 혼잡", walk: "왕복 약 1시간 30분 · 오르막 포함",
                tide: "만조 전후에 S자 물길이 선명해요"
            ),
            sensitivity: .protected(note: "람사르 습지예요. 흑두루미 월동기(11–3월)에는 일부 데크가 통제돼요."),
            etiquette: ["갈대밭 안으로 들어가지 마세요.", "철새에게 가까이 다가가지 마세요."],
            focalUsage: [14: 1, 24: 6, 35: 8, 50: 10, 85: 14, 135: 16, 200: 12]
        )
    ]

    // MARK: Frames

    static let frames: [Frame] = [
        frame("gwangchigi-01", place: "gwangchigi", spot: "gwangchigi-rocks", "이끼 바위 너머 성산일출봉 일출", by: "@jeju.morning",
              at: kst(2026, 3, 24, 6, 48), cam(24, 11, "1/250", 100, tripod: true), heading: 69, standing: "해변 북쪽, 이끼 바위 옆 모래",
              scenes: [.seascape, .silhouette, .mountain], conditions: [.lowTide, .clear], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.8, brightness: 0.55, calm: 0.7),
              art: PlaceholderArt(sky: .golden, horizon: 0.58, celestial: .sun(x: 0.62, y: 0.46), backdrop: [.volcano(x: 0.62, width: 0.5, height: 0.13)], surface: .sea, foreground: [.rocks], seed: 101),
              prominence: 0.95),
        frame("gwangchigi-02", place: "gwangchigi", spot: "gwangchigi-hill", "유채꽃 너머 일출봉", by: "@yellow.march",
              at: kst(2026, 4, 2, 7, 40), cam(35, 8, "1/500", 100), heading: 64, standing: "해안도로 옆 유채꽃 언덕 가장자리",
              scenes: [.flower, .mountain, .portraitBackdrop], conditions: [.blossom, .clear], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.6, brightness: 0.85, calm: 0.6),
              art: PlaceholderArt(sky: .day, horizon: 0.55, backdrop: [.volcano(x: 0.55, width: 0.46, height: 0.16)], surface: .land(.field), foreground: [.blossoms(.yellow, density: 1.0)], seed: 102),
              prominence: 0.8),
        frame("gwangchigi-03", place: "gwangchigi", spot: "gwangchigi-center", "물웅덩이에 비친 블루아워 일출봉", by: "@tide.lines",
              at: kst(2025, 12, 14, 7, 2), cam(16, 8, "2s", 100, tripod: true), heading: 65, standing: "해변 중앙, 물웅덩이 바로 앞 낮은 자세",
              scenes: [.reflection, .seascape, .silhouette], conditions: [.calmWater, .lowTide], weather: "구름 조금",
              aspect: 0.667, mood: Mood(warmth: 0.3, brightness: 0.3, calm: 0.9),
              art: PlaceholderArt(sky: .blue, horizon: 0.5, backdrop: [.volcano(x: 0.5, width: 0.56, height: 0.14)], surface: .calmWater, seed: 103),
              prominence: 0.75),
        frame("seopjikoji-01", place: "seopjikoji", spot: "seopji-lighthouse", "등대 언덕에서 당겨 본 일출봉", by: "@coastline.kim",
              at: kst(2026, 4, 10, 18, 52), cam(85, 8, "1/320", 200), heading: 15, standing: "등대 아래 언덕 산책로 끝",
              scenes: [.seascape, .mountain, .silhouette], conditions: [.clear], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.75, brightness: 0.6, calm: 0.6),
              art: PlaceholderArt(sky: .golden, horizon: 0.6, celestial: .sun(x: 0.15, y: 0.5), backdrop: [.volcano(x: 0.58, width: 0.34, height: 0.12), .lighthouse(x: 0.18)], surface: .sea, seed: 104),
              prominence: 0.6),
        frame("ojori-01", place: "ojori", spot: "ojo-lagoon", "내수면에 거꾸로 비친 일출봉", by: "@still.water",
              at: kst(2025, 11, 8, 6, 52), cam(24, 11, "1/30", 400, tripod: true), heading: 110, standing: "내수면 둑길 중간, 수문 옆",
              scenes: [.reflection, .silhouette, .mountain], conditions: [.calmWater], weather: "맑음, 바람 없음",
              aspect: 1.5, mood: Mood(warmth: 0.55, brightness: 0.4, calm: 0.95),
              art: PlaceholderArt(sky: .dawn, horizon: 0.52, celestial: .sun(x: 0.55, y: 0.53), backdrop: [.volcano(x: 0.55, width: 0.42, height: 0.12)], surface: .calmWater, seed: 105),
              prominence: 0.85),
        frame("banpo-01", place: "banpo", spot: "banpo-steps", "달빛무지개분수와 반포대교", by: "@hangang.nights",
              at: kst(2026, 5, 16, 19, 58), cam(24, 8, "4s", 100, tripod: true), heading: 60, standing: "세빛섬 남단 계단 세 번째 칸",
              scenes: [.cityscape, .lightTrail, .reflection], conditions: [.calmWater], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.45, brightness: 0.3, calm: 0.6),
              art: PlaceholderArt(sky: .blue, horizon: 0.56, backdrop: [.skyline(lit: true, height: 0.12), .bridge(lit: true)], surface: .calmWater, seed: 106),
              prominence: 0.9),
        frame("banpo-02", place: "banpo", spot: "banpo-riverside", "잠수교 너머 남산타워", by: "@seoul.tele",
              at: kst(2025, 10, 18, 19, 20), cam(135, 8, "2s", 200, tripod: true), heading: 351, standing: "잠수교 남단 둔치 벤치 뒤",
              scenes: [.cityscape, .architecture], conditions: [.clear], weather: "맑음",
              aspect: 0.667, mood: Mood(warmth: 0.4, brightness: 0.2, calm: 0.7),
              art: PlaceholderArt(sky: .night, horizon: 0.62, backdrop: [.skyline(lit: true, height: 0.1), .tower(x: 0.5, height: 0.34, lit: true)], surface: .calmWater, seed: 107),
              prominence: 0.7),
        frame("eungbong-01", place: "eungbongsan", spot: "eungbong-pavilion", "강변북로 빛 궤적", by: "@trail.shooter",
              at: kst(2026, 4, 5, 19, 45), cam(50, 11, "15s", 100, tripod: true), heading: 140, standing: "팔각정 데크 동쪽 난간 앞",
              scenes: [.lightTrail, .cityscape], conditions: [.clear], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.5, brightness: 0.3, calm: 0.3),
              art: PlaceholderArt(sky: .blue, horizon: 0.5, backdrop: [.skyline(lit: true, height: 0.16)], surface: .land(.dark), foreground: [.lightTrails, .blossoms(.yellow, density: 0.35)], seed: 108),
              prominence: 0.8),
        frame("eungbong-02", place: "eungbongsan", spot: "eungbong-pavilion", "개나리 언덕 너머 노을 속 남산", by: "@forsythia.lens",
              at: kst(2026, 3, 30, 18, 30), cam(85, 5.6, "1/400", 100), heading: 272, standing: "팔각정 아래 서쪽 계단 중턱",
              scenes: [.flower, .cityscape, .portraitBackdrop], conditions: [.blossom], weather: "맑음, 미세먼지 보통",
              aspect: 0.8, mood: Mood(warmth: 0.85, brightness: 0.6, calm: 0.5),
              art: PlaceholderArt(sky: .golden, horizon: 0.6, celestial: .sun(x: 0.4, y: 0.52), backdrop: [.skyline(lit: false, height: 0.09), .tower(x: 0.6, height: 0.26, lit: false)], surface: .land(.dark), foreground: [.blossoms(.yellow, density: 0.9)], seed: 109),
              prominence: 0.65),
        frame("naksan-01", place: "naksan", spot: "naksan-wall", "성곽길 노을 스냅", by: "@snap.hyewon",
              at: kst(2025, 11, 2, 17, 20), cam(50, 1.8, "1/1000", 100), heading: 207, standing: "성곽 안쪽 산책로, 암문 조금 지나서",
              scenes: [.portraitBackdrop, .architecture, .cityscape], conditions: [.clear], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.8, brightness: 0.55, calm: 0.5),
              art: PlaceholderArt(sky: .dusk, horizon: 0.64, celestial: .sun(x: 0.7, y: 0.55), backdrop: [.skyline(lit: false, height: 0.1)], surface: .land(.dark), foreground: [.person(x: 0.36)], seed: 110),
              prominence: 0.55, verified: false),
        frame("dumul-01", place: "dumulmeori", spot: "dumul-tree", "물안개 속 느티나무", by: "@mist.river",
              at: kst(2025, 10, 25, 6, 58), cam(35, 8, "1/125", 200), heading: 100, standing: "느티나무 서쪽 물가, 펜스 바깥",
              scenes: [.fog, .silhouette, .reflection], conditions: [.fog, .calmWater], weather: "안개",
              aspect: 1.5, mood: Mood(warmth: 0.5, brightness: 0.6, calm: 0.95),
              art: PlaceholderArt(sky: .mist, horizon: 0.58, celestial: .sun(x: 0.72, y: 0.5), backdrop: [.hills(height: 0.08), .tree(x: 0.42, scale: 1.0)], surface: .calmWater, foreground: [.fog(level: 0.8)], seed: 111),
              prominence: 0.92),
        frame("dumul-02", place: "dumulmeori", spot: "dumul-tree", "눈 내린 겨울 강변", by: "@winter.frame",
              at: kst(2026, 1, 18, 7, 35), cam(24, 11, "1/60", 100, tripod: true), heading: 95, standing: "느티나무 앞 눈 쌓인 둔치",
              scenes: [.fog, .silhouette], conditions: [.snow, .fog], weather: "눈 그친 뒤 흐림",
              aspect: 1.778, mood: Mood(warmth: 0.3, brightness: 0.55, calm: 0.9),
              art: PlaceholderArt(sky: .mist, horizon: 0.55, backdrop: [.hills(height: 0.07), .tree(x: 0.6, scale: 0.9)], surface: .land(.snow), foreground: [.fog(level: 0.5)], seed: 112),
              prominence: 0.6),
        frame("dumul-03", place: "dumulmeori", spot: "dumul-bridge", "연둣빛 봄 배다리", by: "@green.april",
              at: kst(2026, 4, 20, 16, 30), cam(35, 8, "1/320", 100), heading: 40, standing: "배다리 입구 계단 위",
              scenes: [.portraitBackdrop, .reflection], conditions: [.clear], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.55, brightness: 0.8, calm: 0.8),
              art: PlaceholderArt(sky: .spring, horizon: 0.55, backdrop: [.hills(height: 0.1), .tree(x: 0.75, scale: 0.7)], surface: .calmWater, seed: 113),
              prominence: 0.45),
        frame("anban-01", place: "anbandegi", spot: "anban-observatory", "배추밭 위 은하수", by: "@milkyway.kr",
              at: kst(2025, 8, 20, 22, 30), cam(14, 2.8, "20s", 3200, tripod: true), heading: 185, standing: "멍에전망대 남쪽 난간 앞",
              scenes: [.astro, .mountain], conditions: [.milkyWay, .clear], weather: "맑음, 월몰 후",
              aspect: 0.667, mood: Mood(warmth: 0.2, brightness: 0.12, calm: 0.85),
              art: PlaceholderArt(sky: .night, horizon: 0.72, stars: true, milkyWay: true, backdrop: [.ridges(layers: 2, height: 0.08)], surface: .land(.field), seed: 114),
              prominence: 0.88),
        frame("anban-02", place: "anbandegi", spot: "anban-observatory", "운해 위로 떠오르는 해", by: "@cloud.sea",
              at: kst(2025, 9, 28, 6, 18), cam(70, 8, "1/250", 100, tripod: true), heading: 95, standing: "멍에전망대 동쪽 끝",
              scenes: [.fog, .mountain, .silhouette], conditions: [.cloudSea], weather: "운해",
              aspect: 1.5, mood: Mood(warmth: 0.75, brightness: 0.5, calm: 0.85),
              art: PlaceholderArt(sky: .dawn, horizon: 0.55, celestial: .sun(x: 0.6, y: 0.47), backdrop: [.ridges(layers: 3, height: 0.14)], surface: .land(.dark), foreground: [.fog(level: 1.0)], seed: 115),
              prominence: 0.7),
        frame("gwangan-01", place: "gwangalli", spot: "gwangan-beach", "광안대교 블루아워 장노출", by: "@busan.bluehour",
              at: kst(2025, 7, 12, 20, 5), cam(24, 11, "25s", 100, tripod: true), heading: 150, standing: "해변 모래사장 중앙, 물가에서 5m",
              scenes: [.cityscape, .seascape, .lightTrail], conditions: [.calmWater], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.45, brightness: 0.3, calm: 0.6),
              art: PlaceholderArt(sky: .blue, horizon: 0.55, backdrop: [.skyline(lit: true, height: 0.08), .bridge(lit: true)], surface: .calmWater, seed: 116),
              prominence: 0.86),
        frame("gwangan-02", place: "gwangalli", spot: "millak-breakwater", "민락 방파제에서 본 해 질 녘 광안대교", by: "@harbor.light",
              at: kst(2026, 2, 15, 18, 5), cam(85, 8, "1/200", 100), heading: 228, standing: "민락수변공원 방파제 계단 끝",
              scenes: [.silhouette, .cityscape, .seascape], conditions: [.clear], weather: "맑음",
              aspect: 1.778, mood: Mood(warmth: 0.85, brightness: 0.5, calm: 0.6),
              art: PlaceholderArt(sky: .dusk, horizon: 0.6, celestial: .sun(x: 0.3, y: 0.52), backdrop: [.bridge(lit: false)], surface: .sea, seed: 117),
              prominence: 0.6),
        frame("igidae-01", place: "igidae", spot: "igidae-point", "갯바위 너머 마린시티 야경", by: "@night.coast",
              at: kst(2025, 12, 5, 17, 40), cam(50, 8, "8s", 100, tripod: true), heading: 33, standing: "동생말 전망대 아래 데크",
              scenes: [.cityscape, .seascape, .reflection], conditions: [.calmWater], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.35, brightness: 0.3, calm: 0.7),
              art: PlaceholderArt(sky: .blue, horizon: 0.55, backdrop: [.skyline(lit: true, height: 0.2)], surface: .calmWater, foreground: [.rocks], seed: 118),
              prominence: 0.72),
        frame("donggung-01", place: "donggung", spot: "donggung-west", "월지에 비친 전각, 블루아워", by: "@gyeongju.reflect",
              at: kst(2025, 10, 3, 18, 28), cam(24, 8, "2s", 200, tripod: true), heading: 80, standing: "서쪽 연못가 산책로, 안내판 옆",
              scenes: [.reflection, .architecture], conditions: [.calmWater], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.6, brightness: 0.35, calm: 0.95),
              art: PlaceholderArt(sky: .blue, horizon: 0.5, backdrop: [.hills(height: 0.05), .pavilion(x: 0.45, lit: true)], surface: .calmWater, seed: 119),
              prominence: 0.9),
        frame("donggung-02", place: "donggung", spot: "donggung-west", "연꽃 피는 여름 아침", by: "@lotus.morning",
              at: kst(2025, 7, 20, 5, 40), cam(35, 8, "1/250", 100), heading: 75, standing: "연못 남쪽 연꽃 단지 앞",
              scenes: [.flower, .architecture], conditions: [.blossom], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.65, brightness: 0.7, calm: 0.85),
              art: PlaceholderArt(sky: .dawn, horizon: 0.52, celestial: .sun(x: 0.7, y: 0.45), backdrop: [.hills(height: 0.06), .pavilion(x: 0.35, lit: false)], surface: .calmWater, foreground: [.blossoms(.pink, density: 0.7)], seed: 120),
              prominence: 0.5),
        frame("damyang-01", place: "damyang", spot: "damyang-center", "끝없는 메타세쿼이아 소실점", by: "@vanishing.kim",
              at: kst(2025, 11, 15, 7, 45), cam(85, 5.6, "1/200", 200), heading: 45, standing: "가로수길 중앙선 살짝 왼쪽",
              scenes: [.vanishingPoint, .portraitBackdrop], conditions: [.autumnLeaves], weather: "맑음",
              aspect: 0.667, mood: Mood(warmth: 0.9, brightness: 0.6, calm: 0.7),
              art: PlaceholderArt(sky: .golden, horizon: 0.52, surface: .road(.autumn), seed: 121),
              prominence: 0.84),
        frame("damyang-02", place: "damyang", spot: "damyang-center", "초록 터널의 한낮", by: "@green.tunnel",
              at: kst(2025, 6, 21, 10, 30), cam(24, 8, "1/250", 100), heading: 45, standing: "매표소 지나 첫 벤치",
              scenes: [.vanishingPoint], conditions: [.clear], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.5, brightness: 0.8, calm: 0.75),
              art: PlaceholderArt(sky: .day, horizon: 0.5, surface: .road(.green), seed: 122),
              prominence: 0.5),
        frame("boseong-01", place: "boseong", spot: "boseong-ridge", "안개 낀 차밭 이랑", by: "@tea.fields",
              at: kst(2026, 5, 5, 5, 58), cam(85, 8, "1/250", 200, tripod: true), heading: 200, standing: "전망대 아래 능선 데크",
              scenes: [.fog, .mountain], conditions: [.fog], weather: "안개",
              aspect: 1.5, mood: Mood(warmth: 0.45, brightness: 0.7, calm: 0.9),
              art: PlaceholderArt(sky: .mist, horizon: 0.35, backdrop: [.ridges(layers: 2, height: 0.08)], surface: .teaRows, foreground: [.fog(level: 0.6)], seed: 123),
              prominence: 0.78),
        frame("suncheon-01", place: "suncheon", spot: "suncheon-yongsan", "S자 물길과 일몰", by: "@scurve.sunset",
              at: kst(2025, 11, 10, 17, 20), cam(70, 11, "1/125", 100, tripod: true), heading: 225, standing: "용산전망대 2층 가운데 난간",
              scenes: [.silhouette, .reflection, .mountain], conditions: [.clear], weather: "맑음",
              aspect: 1.5, mood: Mood(warmth: 0.95, brightness: 0.5, calm: 0.8),
              art: PlaceholderArt(sky: .dusk, horizon: 0.4, celestial: .sun(x: 0.55, y: 0.3), backdrop: [.ridges(layers: 2, height: 0.07)], surface: .sCurve, seed: 124),
              prominence: 0.87),
        frame("suncheon-02", place: "suncheon", spot: "suncheon-deck", "갈대 데크길 인물 스냅", by: "@reed.portrait",
              at: kst(2025, 10, 20, 17, 25), cam(50, 2, "1/800", 100), heading: 250, standing: "갈대 데크길 첫 번째 쉼터 앞",
              scenes: [.portraitBackdrop, .silhouette], conditions: [.clear], weather: "맑음",
              aspect: 0.8, mood: Mood(warmth: 0.85, brightness: 0.6, calm: 0.6),
              art: PlaceholderArt(sky: .golden, horizon: 0.55, celestial: .sun(x: 0.3, y: 0.5), backdrop: [.hills(height: 0.05)], surface: .land(.field), foreground: [.reeds, .person(x: 0.6)], seed: 125),
              prominence: 0.55, verified: false)
    ]

    // MARK: Field reports

    static func reports(now: Date) -> [FieldReport] {
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        return [
            FieldReport(id: "r1", placeID: "gwangchigi", postedAt: ago(20), kind: .condition, message: "간조 11:40 · 이끼 바위가 잘 드러났어요"),
            FieldReport(id: "r2", placeID: "dumulmeori", postedAt: ago(30), kind: .condition, message: "새벽 기온이 떨어져 물안개가 자주 껴요"),
            FieldReport(id: "r3", placeID: "eungbongsan", postedAt: ago(52), kind: .closure, message: "팔각정 데크 보수 공사 끝 · 다시 개방"),
            FieldReport(id: "r4", placeID: "donggung", postedAt: ago(120), kind: .closure, message: "연못 준설로 동쪽 산책로 일부 통제"),
            FieldReport(id: "r5", placeID: "anbandegi", postedAt: ago(96), kind: .closure, message: "배추 수확 중 · 밭 진입 금지, 전망대만 이용"),
            FieldReport(id: "r6", placeID: "suncheon", postedAt: ago(40), kind: .bloom, message: "갈대 이삭이 올라와 황금빛이 짙어지는 중"),
            FieldReport(id: "r7", placeID: "damyang", postedAt: ago(70), kind: .bloom, message: "길 끝쪽부터 조금씩 물들기 시작"),
            FieldReport(id: "r8", placeID: "banpo", postedAt: ago(8), kind: .crowd, message: "평일 21시 분수 쇼 이후 계단이 한산해요")
        ]
    }

    // MARK: Starter rolls

    static func starterRolls() -> [Roll] {
        [
            Roll(name: "언젠가 롤", frameIDs: ["anban-01", "suncheon-01"], isDefault: true),
            Roll(name: "제주 3월 롤", frameIDs: ["gwangchigi-01", "gwangchigi-02", "seopjikoji-01", "ojori-01"]),
            Roll(name: "서울 야경 롤", frameIDs: ["banpo-01", "eungbong-01", "banpo-02"]),
            Roll(name: "물안개 롤", frameIDs: ["dumul-01", "boseong-01"])
        ]
    }
}
