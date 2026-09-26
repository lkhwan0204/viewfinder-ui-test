import SwiftUI

/// 탐색의 세 단계. 핀치 제스처 하나로 오갑니다.
/// Frame(사진 1장) ─핀치 인→ Contact Sheet(밀착 인화) ─핀치 인→ Map(사진이 놓인 지도)
enum ExploreLevel: Int, CaseIterable, Identifiable {
    case frame, sheet, map

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .frame: return "프레임"
        case .sheet: return "밀착 인화"
        case .map: return "지도"
        }
    }

    var symbol: String {
        switch self {
        case .frame: return "rectangle.portrait"
        case .sheet: return "square.grid.3x3"
        case .map: return "map"
        }
    }
}

enum ExploreRoute: Hashable {
    case place(placeID: String, spotID: String?)
}

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location

    @State private var level: ExploreLevel = .frame
    @State private var focusedID: String?
    @State private var path: [ExploreRoute] = []
    @State private var cardFrame: Frame?
    @State private var similarSource: Frame?
    @State private var saveTarget: Frame?
    @State private var showProfile = false
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var scatterFrom: [String: CGRect]?
    @State private var pinch: CGFloat = 1
    @State private var toast: String?

    var body: some View {
        let frames = model.feed(reference: location.reference)
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                VF.Palette.matte.ignoresSafeArea()

                content(frames)

                ExploreTopBar(level: level, onLevel: { setLevel($0) }, onProfile: { showProfile = true })
                    .opacity(model.chromeHidden ? 0 : 1)
                    .allowsHitTesting(!model.chromeHidden)

                if let toast {
                    ToastLabel(text: toast, symbol: "bookmark.fill")
                        .padding(.top, 104)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .environment(\.colorScheme, .dark)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreRoute.self) { route in
                switch route {
                case let .place(placeID, spotID):
                    PlaceDetailView(placeID: placeID, initialSpotID: spotID)
                }
            }
        }
        .sheet(item: $cardFrame) { frame in
            ShotCardView(frame: frame, onOpenPlace: { openPlace(frame) })
        }
        .sheet(item: $similarSource) { frame in
            SimilarFramesView(start: frame, onShowInFeed: { showInFeed($0) }, onOpenPlace: { openPlace($0) })
        }
        .sheet(item: $saveTarget) { frame in
            SaveToRollSheet(frame: frame)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .onChange(of: frames.map(\.id)) { _, ids in
            if let id = focusedID, ids.contains(id) { return }
            focusedID = ids.first
        }
    }

    // MARK: Levels

    @ViewBuilder
    private func content(_ frames: [Frame]) -> some View {
        if frames.isEmpty && level != .map {
            EmptyStateView(
                symbol: "camera.aperture",
                title: "조건에 맞는 프레임이 없어요",
                message: "필터를 줄이거나 다른 시간대를 골라보세요.",
                actionTitle: "필터 초기화"
            ) {
                withAnimation(.snappy) { model.activeFilters.removeAll() }
            }
            .frame(maxHeight: .infinity)
        } else {
            switch level {
            case .frame:
                FrameFeedView(
                    frames: frames,
                    focusedID: $focusedID,
                    onOpenCard: { cardFrame = $0 },
                    onSimilar: { similarSource = $0 },
                    onSave: { saveTarget = $0 },
                    onQuickSave: { quickSave($0) }
                )
                .scaleEffect(pinch)
                .simultaneousGesture(magnify)
                .transition(.scale(scale: 1.08).combined(with: .opacity))
            case .sheet:
                ContactSheetView(
                    frames: frames,
                    focusedID: focusedID,
                    onSelect: { id in
                        focusedID = id
                        setLevel(.frame)
                    },
                    onSimilar: { similarSource = $0 },
                    cellFrames: $cellFrames
                )
                .scaleEffect(pinch)
                .simultaneousGesture(magnify)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            case .map:
                // 지도에서는 핀치가 지도 확대/축소이므로 상단 스위처로 돌아옵니다.
                ExploreMapView(
                    frames: frames,
                    focusedID: $focusedID,
                    scatterFrom: scatterFrom,
                    onOpenCard: { cardFrame = $0 },
                    onOpenPlace: { openPlace($0) }
                )
                .transition(.opacity)
            }
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // 손가락을 따라 살짝 줄어들거나 커지는 탄성 피드백
                pinch = 1 + (min(max(value.magnification, 0.6), 1.5) - 1) * 0.25
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pinch = 1 }
                if value.magnification < 0.8 {
                    zoomOut()
                } else if value.magnification > 1.25 {
                    zoomIn()
                }
            }
    }

    private func zoomOut() {
        switch level {
        case .frame: setLevel(.sheet)
        case .sheet: setLevel(.map)
        case .map: break
        }
    }

    private func zoomIn() {
        switch level {
        case .frame: break
        case .sheet: setLevel(.frame)
        case .map: setLevel(.sheet)
        }
    }

    private func setLevel(_ new: ExploreLevel) {
        guard new != level else { return }
        Haptics.soft()
        // 밀착 인화 → 지도로 갈 때만 "사진이 제자리로 흩어지는" 전환을 씁니다.
        scatterFrom = (level == .sheet && new == .map) ? cellFrames : nil
        model.chromeHidden = false
        withAnimation(.snappy(duration: 0.38)) { level = new }
    }

    // MARK: Actions

    private func openPlace(_ frame: Frame) {
        cardFrame = nil
        similarSource = nil
        path.append(.place(placeID: frame.placeID, spotID: frame.spotID))
    }

    private func showInFeed(_ frame: Frame) {
        similarSource = nil
        if !model.feed(reference: location.reference).contains(frame) {
            model.activeFilters.removeAll()
        }
        focusedID = frame.id
        if level != .frame { setLevel(.frame) }
    }

    private func quickSave(_ frame: Frame) {
        let saved = model.quickSave(frame.id)
        Haptics.shutter()
        showToast(saved ? "언젠가 롤에 담았어요" : "언젠가 롤에서 뺐어요")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.25)) {
                if toast == text { toast = nil }
            }
        }
    }
}
