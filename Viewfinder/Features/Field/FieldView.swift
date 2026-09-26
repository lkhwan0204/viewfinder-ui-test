import SwiftUI

/// 필드 탭 = 현장 모드. 발견한 프레임을 실제 촬영까지 이어줍니다.
/// - 나침반: 포인트까지 걸어갈 방향 → 도착하면 카메라를 향할 방향
/// - 고스트: 카메라 화면 위에 참고 사진을 반투명하게 겹쳐 구도 맞추기
/// - 적색 모드: 새벽·밤 촬영에서 눈의 암순응 보호
struct FieldView: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location

    @State private var mode: FieldMode = .compass
    @State private var showPicker = false
    @State private var showUpload = false
    @State private var simulatedHeading: Double = 0

    enum FieldMode: String, CaseIterable, Identifiable {
        case compass, ghost

        var id: String { rawValue }
        var title: String { self == .compass ? "나침반" : "고스트" }
        var symbol: String { self == .compass ? "location.north.line" : "square.on.square.dashed" }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                if let target = model.fieldTarget {
                    content(target)
                } else {
                    EmptyStateView(
                        symbol: "scope",
                        title: "현장에서 안내할 프레임을 고르세요",
                        message: "촬영 카드나 롤에서 '필드 모드로'를 누르거나, 저장한 프레임 중에서 골라보세요.",
                        actionTitle: "저장한 프레임에서 고르기"
                    ) {
                        showPicker = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(VF.Palette.matte.ignoresSafeArea())
            .navigationTitle("필드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("프레임 고르기", systemImage: "film.stack")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $model.nightRedMode) {
                        Label("적색 모드", systemImage: "moon.fill")
                    }
                    .toggleStyle(.button)
                    .tint(.red)
                }
            }
            .sheet(isPresented: $showPicker) {
                FieldTargetPicker()
            }
            .sheet(isPresented: $showUpload) {
                if let target = model.fieldTarget {
                    UploadFrameSheet(target: target)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            location.requestWhenInUse()
            location.startHeading()
        }
        .onDisappear {
            location.stopHeading()
        }
    }

    private func content(_ target: Frame) -> some View {
        let place = model.catalog.place(target.placeID)
        let spot = model.catalog.spot(target.spotID)
        let here = location.reference
        let distance = GeoMath.distance(here, target.coordinate)
        let bearingToSpot = GeoMath.bearing(from: here, to: target.coordinate)
        let arrived = !location.isUsingFallback && distance < 60
        let heading = location.heading ?? simulatedHeading

        return ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FrameThumbnail(frame: target, size: 56, fill: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place?.name ?? "")
                            .font(VF.Typeface.title(17))
                            .foregroundStyle(Color.white)
                        Text("\(spot?.name ?? "") · \(target.standingNote)")
                            .font(VF.Typeface.body(12))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(2)
                    }
                    Spacer()
                }

                statusLine(distance: distance, bearing: bearingToSpot, arrived: arrived, target: target)

                Picker("모드", selection: $mode) {
                    ForEach(FieldMode.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .compass:
                    CompassGuideView(
                        deviceHeading: heading,
                        walkBearing: arrived ? nil : bearingToSpot,
                        shootHeading: target.heading,
                        fov: target.camera.horizontalFOV,
                        isSimulated: location.heading == nil,
                        simulatedHeading: $simulatedHeading
                    )
                case .ghost:
                    GhostOverlayView(frame: target)
                }

                Button {
                    showUpload = true
                } label: {
                    Label("촬영 완료 · 여기서 찍은 사진 공유하기", systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.vfPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func statusLine(distance: Double, bearing: Double, arrived: Bool, target: Frame) -> some View {
        if location.isUsingFallback {
            HStack(spacing: 8) {
                Image(systemName: "location.slash")
                Text(location.isDenied ? "위치 권한이 꺼져 있어 서울 기준으로 안내해요" : "현재 위치를 찾는 중이에요 (서울 기준)")
            }
            .font(VF.Typeface.body(13))
            .foregroundStyle(Color.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if arrived {
            Label("도착! 이제 카메라를 \(VFFormat.compass(target.heading)) \(Int(target.heading))°로 향하세요", systemImage: "checkmark.circle.fill")
                .font(VF.Typeface.label(14, weight: .semibold))
                .foregroundStyle(VF.Palette.amber)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                Text(verbatim: "포인트까지 \(VFFormat.distance(distance)) · \(VFFormat.compass(bearing)) 방향")
            }
            .font(VF.Typeface.mono(13, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 저장한 프레임 중 안내받을 프레임 고르기
struct FieldTargetPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.rolls) { roll in
                    let frames = model.frames(in: roll)
                    if !frames.isEmpty {
                        Section(roll.name) {
                            ForEach(frames) { frame in
                                row(frame)
                            }
                        }
                    }
                }
            }
            .navigationTitle("안내받을 프레임")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func row(_ frame: Frame) -> some View {
        Button {
            Haptics.tick()
            model.fieldTargetID = frame.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                FrameThumbnail(frame: frame, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.catalog.place(frame.placeID)?.name ?? "")
                        .font(VF.Typeface.body(15))
                        .foregroundStyle(VF.Palette.textPrimary)
                    Text(verbatim: "\(VFFormat.distance(GeoMath.distance(location.reference, frame.coordinate))) · \(frame.caption)")
                        .font(VF.Typeface.mono(10))
                        .foregroundStyle(VF.Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if model.fieldTargetID == frame.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(VF.Palette.amber)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
