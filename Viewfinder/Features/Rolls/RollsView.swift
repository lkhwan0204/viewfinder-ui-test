import SwiftUI

enum RollsRoute: Hashable {
    case roll(UUID)
    case plan(UUID)
    case place(placeID: String, spotID: String?)
}

/// 롤 탭: 저장한 프레임을 필름 롤처럼 모으고, 조건이 맞으면 알려주고, 계획으로 바꿉니다.
struct RollsView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [RollsRoute] = []
    @State private var showNewRoll = false
    @State private var newRollName = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("찍고 싶은 장면을 모아 계획으로")
                        .font(VF.Typeface.body(14))
                        .foregroundStyle(VF.Palette.textSecondary)
                        .padding(.horizontal, 20)

                    alertsSection

                    VStack(spacing: 26) {
                        ForEach(model.rolls) { roll in
                            Button {
                                path.append(.roll(roll.id))
                            } label: {
                                RollStripCard(roll: roll)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(VF.Palette.background)
            .navigationTitle("롤")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewRoll = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("새 롤 만들기")
                }
            }
            .navigationDestination(for: RollsRoute.self) { route in
                switch route {
                case let .roll(id):
                    RollDetailView(
                        rollID: id,
                        onOpenPlace: { frame in path.append(.place(placeID: frame.placeID, spotID: frame.spotID)) },
                        onPlan: { path.append(.plan(id)) }
                    )
                case let .plan(id):
                    PlanView(rollID: id)
                case let .place(placeID, spotID):
                    PlaceDetailView(placeID: placeID, initialSpotID: spotID)
                }
            }
            .alert("새 롤", isPresented: $showNewRoll) {
                TextField("예: 제주 3월 롤", text: $newRollName)
                Button("만들기") {
                    model.createRoll(named: newRollName)
                    newRollName = ""
                }
                Button("취소", role: .cancel) { newRollName = "" }
            } message: {
                Text("찍고 싶은 장면을 모아둘 롤의 이름을 정해주세요")
            }
        }
    }

    /// 저장만 하고 잊어버리지 않도록: 저장한 프레임의 조건이 맞는 날을 알려줍니다.
    @ViewBuilder
    private var alertsSection: some View {
        let alerts = model.alerts()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("조건 알림", systemImage: "bell.badge")
                    .font(VF.Typeface.label(13, weight: .semibold))
                    .foregroundStyle(VF.Palette.amber)
                Spacer()
                Text(verbatim: "NEXT 3 DAYS")
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
            if alerts.isEmpty {
                Text("저장한 프레임 중 조건이 맞는 날이 아직 없어요. 맞는 날이 오면 알려드릴게요.")
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(VF.Palette.textSecondary)
            }
            ForEach(alerts) { alert in
                if let frame = model.catalog.frame(alert.frameID) {
                    Button {
                        path.append(.place(placeID: frame.placeID, spotID: frame.spotID))
                    } label: {
                        AlertCard(alert: alert, frame: frame)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct AlertCard: View {
    let alert: ConditionAlert
    let frame: Frame

    var body: some View {
        HStack(spacing: 12) {
            FrameThumbnail(frame: frame, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.headline)
                    .font(VF.Typeface.label(14, weight: .semibold))
                    .foregroundStyle(VF.Palette.textPrimary)
                    .lineLimit(1)
                Text(alert.detail)
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(VF.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(verbatim: "\(alert.likelihood)%")
                .font(VF.Typeface.mono(16, weight: .medium))
                .foregroundStyle(VF.Palette.amber)
        }
        .padding(12)
        .background(VF.Palette.amberSoft, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
        .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(VF.Palette.amber.opacity(0.35), lineWidth: VF.Metric.hairline))
        .accessibilityElement(children: .combine)
    }
}

/// 롤 한 줄: 이름 + 필름 스트립
struct RollStripCard: View {
    let roll: Roll
    @Environment(AppModel.self) private var model

    var body: some View {
        let frames = model.frames(in: roll)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(roll.name)
                    .font(VF.Typeface.title(18))
                    .foregroundStyle(VF.Palette.textPrimary)
                if roll.isDefault {
                    TagLabel(text: "두 번 탭으로 저장", tint: VF.Palette.amber)
                }
                Spacer()
                if roll.isOfflineReady {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(VF.Palette.amber)
                        .accessibilityLabel("오프라인 저장됨")
                }
                Text(verbatim: "\(frames.count) FRAMES")
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
            .padding(.horizontal, 20)

            FilmStrip(frames: frames, frameHeight: 92)
        }
    }
}

/// 필름 스트립: 스프로킷 구멍 사이로 프레임이 이어집니다. 사진은 3:2 칸 안에 크롭 없이.
struct FilmStrip: View {
    let frames: [Frame]
    var frameHeight: CGFloat = 92

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                if frames.isEmpty {
                    Text("아직 비어 있어요 · 탐색에서 사진을 두 번 탭해 담아보세요")
                        .font(VF.Typeface.mono(10))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(height: frameHeight)
                }
                ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                    VStack(spacing: 4) {
                        ZStack {
                            Color.black
                            FramePhotoView(frame: frame)
                                .padding(3)
                        }
                        .frame(width: frameHeight * 1.5, height: frameHeight)
                        Text(verbatim: String(format: "%02dA", index + 1))
                            .font(VF.Typeface.mono(8))
                            .foregroundStyle(VF.Palette.amber.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(alignment: .top) { SprocketRow(hole: Color(hex: 0x33332F)).padding(.top, 2) }
            .background(alignment: .bottom) { SprocketRow(hole: Color(hex: 0x33332F)).padding(.bottom, 2) }
            .background(VF.Palette.matte)
        }
        .scrollIndicators(.hidden)
        .environment(\.colorScheme, .dark)
    }
}
