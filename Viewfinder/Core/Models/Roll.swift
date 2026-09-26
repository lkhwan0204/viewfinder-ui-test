import Foundation

/// 저장한 프레임을 묶는 단위. 필름 한 롤처럼 다룹니다.
/// 장소가 아니라 "이 사진을 찍고 싶다"는 의도(프레임)를 저장합니다.
struct Roll: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var frameIDs: [String]
    var createdAt: Date
    var isOfflineReady: Bool
    /// 두 번 탭으로 저장되는 기본 롤 ("언젠가 롤")
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, frameIDs: [String] = [], createdAt: Date = Date(), isOfflineReady: Bool = false, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.frameIDs = frameIDs
        self.createdAt = createdAt
        self.isOfflineReady = isOfflineReady
        self.isDefault = isDefault
    }
}
