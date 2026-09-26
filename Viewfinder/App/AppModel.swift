import SwiftUI
import Observation
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case explore, rolls, field

    var id: String { rawValue }

    /// 발견한다 → 계획한다 → 찍으러 간다
    var title: String {
        switch self {
        case .explore: return "탐색"
        case .rolls: return "롤"
        case .field: return "필드"
        }
    }

    var symbol: String {
        switch self {
        case .explore: return "viewfinder"
        case .rolls: return "film.stack"
        case .field: return "scope"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case darkroom, gallery, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkroom: return "암실 (다크)"
        case .gallery: return "전시장 (라이트)"
        case .system: return "시스템 설정 따르기"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .darkroom: return .dark
        case .gallery: return .light
        case .system: return nil
        }
    }
}

/// 앱 전체 상태. 롤·취향·설정은 UserDefaults에 저장합니다.
@Observable
final class AppModel {
    var catalog: Catalog
    var rolls: [Roll]
    var hasOnboarded: Bool
    var tasteSeedIDs: [String]
    var appearance: AppearanceMode

    var selectedTab: AppTab = .explore
    var activeFilters: Set<DiscoveryFilter> = []
    /// Frame 뷰 감상 모드 (사진만 남기고 모두 숨김)
    var chromeHidden = false
    /// 필드 모드에서 안내할 프레임
    var fieldTargetID: String?
    /// 야간 촬영용 적색 모드 (눈의 암순응 보호)
    var nightRedMode = false
    /// 사용자가 업로드한 사진 (프로토타입이라 메모리에만 보관)
    var userImages: [String: UIImage] = [:]

    let forecast: any ForecastProviding
    private let defaults: UserDefaults

    private enum Key {
        static let rolls = "vf.rolls"
        static let onboarded = "vf.onboarded"
        static let seeds = "vf.tasteSeeds"
        static let appearance = "vf.appearance"
    }

    init(defaults: UserDefaults = .standard, forecast: any ForecastProviding = SampleForecast()) {
        self.defaults = defaults
        self.forecast = forecast
        self.catalog = Catalog.sample()
        if let data = defaults.data(forKey: Key.rolls),
           let saved = try? JSONDecoder().decode([Roll].self, from: data) {
            self.rolls = saved
        } else {
            self.rolls = SampleData.starterRolls()
        }
        self.hasOnboarded = defaults.bool(forKey: Key.onboarded)
        self.tasteSeedIDs = defaults.stringArray(forKey: Key.seeds) ?? []
        self.appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .darkroom
    }

    // MARK: Images

    /// 업로드한 사진 → Assets의 imageName → Assets의 프레임 id 순서로 실제 사진을 찾습니다.
    /// 없으면 nil (플레이스홀더 장면을 그립니다).
    func image(for frame: Frame) -> UIImage? {
        if let image = userImages[frame.id] { return image }
        if let name = frame.imageName, let image = UIImage(named: name) { return image }
        return UIImage(named: frame.id)
    }

    // MARK: Discovery

    var tasteSeeds: [Frame] { tasteSeedIDs.compactMap { catalog.frame($0) } }

    func feed(reference: GeoPoint, now: Date = Date()) -> [Frame] {
        DiscoveryEngine.feed(
            from: catalog.frames,
            filters: activeFilters,
            seeds: tasteSeeds,
            catalog: catalog,
            forecast: forecast,
            context: DiscoveryContext(now: now, reference: reference)
        )
    }

    func toggle(_ filter: DiscoveryFilter) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
            return
        }
        if filter.isTimeFilter {
            activeFilters = activeFilters.filter { !$0.isTimeFilter }
        }
        activeFilters.insert(filter)
    }

    // MARK: Rolls

    var defaultRollID: UUID? { rolls.first(where: { $0.isDefault })?.id }

    func roll(_ id: UUID) -> Roll? { rolls.first { $0.id == id } }

    func frames(in roll: Roll) -> [Frame] { roll.frameIDs.compactMap { catalog.frame($0) } }

    func isSaved(_ frameID: String) -> Bool { rolls.contains { $0.frameIDs.contains(frameID) } }

    func contains(_ frameID: String, in rollID: UUID) -> Bool { roll(rollID)?.frameIDs.contains(frameID) ?? false }

    /// 두 번 탭으로 "언젠가 롤"에 담기/빼기. 담았으면 true.
    @discardableResult
    func quickSave(_ frameID: String) -> Bool {
        let rollID = defaultRollID ?? createRoll(named: "언젠가 롤", isDefault: true).id
        if contains(frameID, in: rollID) {
            remove(frameID, from: rollID)
            return false
        }
        toggle(frameID, in: rollID)
        return true
    }

    func toggle(_ frameID: String, in rollID: UUID) {
        guard let index = rolls.firstIndex(where: { $0.id == rollID }) else { return }
        if let position = rolls[index].frameIDs.firstIndex(of: frameID) {
            rolls[index].frameIDs.remove(at: position)
        } else {
            rolls[index].frameIDs.insert(frameID, at: 0)
        }
        persist()
    }

    func remove(_ frameID: String, from rollID: UUID) {
        guard let index = rolls.firstIndex(where: { $0.id == rollID }) else { return }
        rolls[index].frameIDs.removeAll { $0 == frameID }
        persist()
    }

    @discardableResult
    func createRoll(named name: String, frameIDs: [String] = [], isDefault: Bool = false) -> Roll {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let roll = Roll(name: trimmed.isEmpty ? "새 롤" : trimmed, frameIDs: frameIDs, isDefault: isDefault)
        rolls.append(roll)
        persist()
        return roll
    }

    func renameRoll(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = rolls.firstIndex(where: { $0.id == id }) else { return }
        rolls[index].name = trimmed
        persist()
    }

    /// 기본 롤은 지울 수 없습니다.
    func deleteRoll(_ id: UUID) {
        rolls.removeAll { $0.id == id && !$0.isDefault }
        persist()
    }

    func markOfflineReady(_ id: UUID) {
        guard let index = rolls.firstIndex(where: { $0.id == id }) else { return }
        rolls[index].isOfflineReady = true
        persist()
    }

    /// 저장한 프레임 중 앞으로 3일 안에 조건이 맞는 것
    func alerts(now: Date = Date()) -> [ConditionAlert] {
        let savedIDs = Set(rolls.flatMap(\.frameIDs)).sorted()
        let saved = savedIDs.compactMap { catalog.frame($0) }
        return AlertEngine.alerts(for: saved, catalog: catalog, forecast: forecast, now: now)
    }

    // MARK: Onboarding & settings

    func completeOnboarding(with seeds: [String]) {
        tasteSeedIDs = seeds
        hasOnboarded = true
        defaults.set(seeds, forKey: Key.seeds)
        defaults.set(true, forKey: Key.onboarded)
    }

    func resetOnboarding() {
        hasOnboarded = false
        defaults.set(false, forKey: Key.onboarded)
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        defaults.set(mode.rawValue, forKey: Key.appearance)
    }

    // MARK: Field

    var fieldTarget: Frame? { fieldTargetID.flatMap { catalog.frame($0) } }

    /// 롤·장소 화면에서 "필드 모드로" → 필드 탭으로 이동
    func openInField(_ frameID: String) {
        fieldTargetID = frameID
        selectedTab = .field
    }

    // MARK: Contributions

    func addUserFrame(_ frame: Frame, image: UIImage) {
        userImages[frame.id] = image
        catalog.add(frame)
    }

    func addReport(placeID: String, kind: FieldReport.Kind, message: String) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        catalog.add(FieldReport(id: UUID().uuidString, placeID: placeID, postedAt: Date(), kind: kind, message: text))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(rolls) {
            defaults.set(data, forKey: Key.rolls)
        }
    }
}
