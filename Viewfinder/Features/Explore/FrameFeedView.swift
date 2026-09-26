import SwiftUI

/// 한 화면에 사진 한 장. 세로로 넘기며 감상합니다.
/// - 탭: 감상 모드 (모든 UI 숨김)
/// - 두 번 탭: 언젠가 롤에 담기 (셔터 햅틱)
/// - 길게 누르기: 비슷한 프레임
/// - 아래 정보 영역을 위로 밀거나 탭: 촬영 카드
struct FrameFeedView: View {
    let frames: [Frame]
    @Binding var focusedID: String?
    var onOpenCard: (Frame) -> Void
    var onSimilar: (Frame) -> Void
    var onSave: (Frame) -> Void
    var onQuickSave: (Frame) -> Void

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                    FramePage(
                        frame: frame,
                        index: index,
                        total: frames.count,
                        onOpenCard: onOpenCard,
                        onSimilar: onSimilar,
                        onSave: onSave,
                        onQuickSave: onQuickSave
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $focusedID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .onAppear {
            if focusedID == nil { focusedID = frames.first?.id }
        }
    }
}

struct FramePage: View {
    let frame: Frame
    let index: Int
    let total: Int
    var onOpenCard: (Frame) -> Void
    var onSimilar: (Frame) -> Void
    var onSave: (Frame) -> Void
    var onQuickSave: (Frame) -> Void

    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location
    @State private var flash = false

    var body: some View {
        let place = model.catalog.place(frame.placeID)
        let spot = model.catalog.spot(frame.spotID)
        let saved = model.isSaved(frame.id)
        VStack(spacing: 0) {
            // 상단 바(지금의 빛 + 칩) 영역
            Color.clear.frame(height: 158)

            photo(saved: saved)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            info(place: place, spot: spot, saved: saved)
                .opacity(model.chromeHidden ? 0 : 1)
                .allowsHitTesting(!model.chromeHidden)

            // 탭바 + 홈 인디케이터 영역
            Color.clear.frame(height: 96)
        }
        .background(VF.Palette.matte)
    }

    // MARK: Photo

    private func photo(saved: Bool) -> some View {
        FramePhotoView(frame: frame)
            .overlay(Color.white.opacity(flash ? 0.55 : 0))
            .viewfinderCorners(saved ? VF.Palette.amber : Color.white.opacity(0.7), length: 16, lineWidth: 1.5, outset: 8)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { shutter() }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) { model.chromeHidden.toggle() }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                Haptics.soft()
                onSimilar(frame)
            }
            .accessibilityLabel(frame.caption)
            .accessibilityHint("두 번 탭하면 저장, 길게 누르면 비슷한 프레임을 보여줘요")
    }

    private func shutter() {
        onQuickSave(frame)
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.3)) { flash = false }
        }
    }

    // MARK: Info

    private func info(place: Place?, spot: Spot?, saved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(place?.name ?? "")
                            .font(VF.Typeface.display(26))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if frame.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(VF.Palette.amber)
                                .accessibilityLabel("현장 인증")
                        }
                    }
                    Text(metaLine(place: place, spot: spot))
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    iconButton("square.stack.3d.down.right", label: "비슷한 프레임") { onSimilar(frame) }
                    iconButton(saved ? "bookmark.fill" : "bookmark", label: "롤에 담기", tint: saved ? VF.Palette.amber : .white) { onSave(frame) }
                }
            }

            ExifStrip(frame: frame)

            HStack {
                Label("촬영 카드", systemImage: "chevron.up")
                    .font(VF.Typeface.mono(10, weight: .medium))
                    .foregroundStyle(VF.Palette.amber)
                Spacer()
                Text(verbatim: String(format: "%02d / %02d", index + 1, total))
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture { onOpenCard(frame) }
        // 정보 영역에서 위로 밀면 촬영 카드 (사진 영역에서의 세로 스와이프는 다음 사진)
        .highPriorityGesture(
            DragGesture(minimumDistance: 14).onEnded { value in
                if value.translation.height < -30 { onOpenCard(frame) }
            }
        )
    }

    private func iconButton(_ symbol: String, label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 포인트 · 거리 · 빛 시각 · 추천 시기
    private func metaLine(place: Place?, spot: Spot?) -> String {
        var parts: [String] = []
        if let spot { parts.append(spot.name) }
        parts.append(VFFormat.distance(GeoMath.distance(location.reference, frame.coordinate)))
        parts.append(sunEventText())
        if let place { parts.append(place.bestMonthsText) }
        return parts.joined(separator: " · ")
    }

    private func sunEventText() -> String {
        let now = Date()
        let phase = model.catalog.phase(of: frame)
        let times = SunCalculator.times(on: now, coordinate: frame.coordinate)
        if phase.isMorning, let sunrise = times.sunrise { return "일출 \(VFFormat.time(sunrise))" }
        if phase.isEvening, let sunset = times.sunset { return "일몰 \(VFFormat.time(sunset))" }
        if phase == .night { return "달 \(Int(SunCalculator.moonIllumination(at: now).fraction * 100))%" }
        if let golden = times.goldenEveningStart { return "골든아워 \(VFFormat.time(golden))" }
        return phase.title
    }
}
