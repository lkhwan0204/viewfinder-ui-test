import SwiftUI
import MapKit

/// 사진이 놓인 지도.
/// - 핀 대신 사진 썸네일 + 시야 부채꼴(Shot Cone)
/// - 줌에 따라 클러스터 (대표 사진 = 그 지역에서 가장 인상적인 한 장)
/// - 밀착 인화에서 넘어오면 사진들이 실제 위치로 흩어지며 내려앉습니다
/// - "대상으로 찾기": 지도에 사각형을 그리면 그 영역을 향해 찍힌 자리만 보여줍니다 (역방향 탐색)
struct ExploreMapView: View {
    let frames: [Frame]
    @Binding var focusedID: String?
    let scatterFrom: [String: CGRect]?
    var onOpenCard: (Frame) -> Void
    var onOpenPlace: (Frame) -> Void

    @State private var position: MapCameraPosition = .region(GeoRegion.korea.mkRegion)
    @State private var region: GeoRegion = .korea
    @State private var mapSize: CGSize = .zero
    @State private var selected: Frame?
    @State private var targetMode = false
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var targetBox: GeoBox?
    @State private var scatterPhase: ScatterPhase = .idle
    @State private var scatterTargets: [String: CGPoint] = [:]

    private enum ScatterPhase { case idle, gathered, flying }

    var body: some View {
        let matches = targetBox.map { FrameTargeting.frames(aimedAt: $0, in: frames) } ?? []
        let matchIDs = Set(matches.map(\.frame.id))
        let clusters = ClusterEngine.cluster(frames, region: region, width: Double(mapSize.width), height: Double(mapSize.height))

        MapReader { proxy in
            Map(position: $position, interactionModes: targetMode ? [] : [.pan, .zoom]) {
                UserAnnotation()

                ForEach(clusters) { cluster in
                    Annotation(cluster.representative.caption, coordinate: cluster.center.clCoordinate, anchor: .center) {
                        FrameMapMarker(
                            frame: cluster.representative,
                            count: cluster.members.count,
                            isSelected: selected?.id == cluster.representative.id,
                            isDimmed: targetBox != nil && !cluster.members.contains { matchIDs.contains($0.id) }
                        )
                        .opacity(scatterPhase == .idle ? 1 : 0)
                        .onTapGesture { handleTap(cluster) }
                    }
                    .annotationTitles(.hidden)
                }

                if let box = targetBox {
                    MapPolygon(coordinates: box.corners.map(\.clCoordinate))
                        .foregroundStyle(VF.Palette.amber.opacity(0.14))
                    MapPolyline(coordinates: (box.corners + [box.corners[0]]).map(\.clCoordinate))
                        .stroke(VF.Palette.amber, lineWidth: 1.5)
                    // 시선: 서야 할 자리 → 대상
                    ForEach(matches) { match in
                        MapPolyline(coordinates: [match.frame.coordinate.clCoordinate, box.center.clCoordinate])
                            .stroke(VF.Palette.amber.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls { MapScaleView() }
            .onMapCameraChange(frequency: .onEnd) { context in
                region = GeoRegion(context.region)
            }
            .overlay { scatterLayer }
            .overlay {
                if targetMode { targetLayer(proxy) }
            }
            .onAppear { start(proxy) }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) { bottomPanel(matches) }
        .overlay(alignment: .trailing) { sideControls }
        .animation(.snappy(duration: 0.3), value: targetBox)
        .animation(.snappy(duration: 0.3), value: selected?.id)
    }

    // MARK: Scatter transition

    private func start(_ proxy: MapProxy) {
        let fit = GeoRegion.fitting(frames.map(\.coordinate)) ?? .korea
        region = fit
        position = .region(fit.mkRegion)
        guard let from = scatterFrom, !from.isEmpty, !frames.isEmpty else { return }
        scatterPhase = .gathered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var targets: [String: CGPoint] = [:]
            for frame in frames {
                if let point = proxy.convert(frame.coordinate.clCoordinate, to: .local) {
                    targets[frame.id] = point
                }
            }
            scatterTargets = targets
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) { scatterPhase = .flying }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.25)) { scatterPhase = .idle }
            }
        }
    }

    /// 밀착 인화의 각 칸 위치에서 지도 위 실제 위치로 날아가는 썸네일들
    private var scatterLayer: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                Color.clear
                if let from = scatterFrom, scatterPhase != .idle {
                    ForEach(frames.filter { from[$0.id] != nil }) { frame in
                        let rect = from[frame.id] ?? .zero
                        let startPoint = CGPoint(x: rect.midX - origin.x, y: rect.midY - origin.y)
                        let flying = scatterPhase == .flying
                        FrameThumbnail(frame: frame, size: flying ? 40 : max(rect.width - 16, 40), fill: flying)
                            .overlay(Rectangle().stroke(Color.white.opacity(flying ? 0.9 : 0), lineWidth: 1))
                            .position(flying ? (scatterTargets[frame.id] ?? startPoint) : startPoint)
                    }
                }
            }
            .onAppear { mapSize = geo.size }
            .onChange(of: geo.size) { _, size in mapSize = size }
        }
        .allowsHitTesting(false)
    }

    // MARK: Reverse search (프레임 드래그)

    private func targetLayer(_ proxy: MapProxy) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.18)
            if let s = dragStart, let c = dragCurrent {
                let rect = CGRect(x: min(s.x, c.x), y: min(s.y, c.y), width: abs(c.x - s.x), height: abs(c.y - s.y))
                Rectangle()
                    .fill(VF.Palette.amber.opacity(0.1))
                    .overlay(Rectangle().stroke(VF.Palette.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    .overlay(ViewfinderCorners(length: 12).stroke(VF.Palette.amber, style: StrokeStyle(lineWidth: 2.5, lineCap: .square)))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .local)
                .onChanged { value in
                    dragStart = value.startLocation
                    dragCurrent = value.location
                }
                .onEnded { value in
                    defer {
                        dragStart = nil
                        dragCurrent = nil
                    }
                    guard abs(value.translation.width) > 12, abs(value.translation.height) > 12,
                          let a = proxy.convert(value.startLocation, from: .local),
                          let b = proxy.convert(value.location, from: .local) else { return }
                    Haptics.shutter()
                    targetBox = GeoBox(corner: GeoPoint(a), GeoPoint(b))
                    targetMode = false
                    selected = nil
                }
        )
    }

    // MARK: Panels & controls

    @ViewBuilder
    private func bottomPanel(_ matches: [TargetMatch]) -> some View {
        if targetBox != nil {
            TargetResultsPanel(matches: matches, onSelect: onOpenCard) {
                targetBox = nil
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let selected {
            MapPreviewCard(
                frame: selected,
                onCard: { onOpenCard(selected) },
                onPlace: { onOpenPlace(selected) },
                onClose: { self.selected = nil }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if targetMode {
            Label("찍고 싶은 대상을 사각형으로 감싸세요", systemImage: "viewfinder")
                .font(VF.Typeface.label(13))
                .foregroundStyle(VF.Palette.onAmber)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(VF.Palette.amber, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
                .padding(.bottom, 16)
                .transition(.opacity)
        }
    }

    private var sideControls: some View {
        VStack(spacing: 8) {
            MapSquareButton(symbol: targetMode ? "xmark" : "viewfinder", label: "대상으로 찾기", isOn: targetMode) {
                Haptics.tick()
                withAnimation(.snappy) {
                    targetMode.toggle()
                    if targetMode { selected = nil }
                }
            }
            MapSquareButton(symbol: "arrow.up.left.and.arrow.down.right", label: "전체 보기", isOn: false) {
                fitAll()
            }
        }
        .padding(.trailing, 14)
    }

    private func handleTap(_ cluster: FrameCluster) {
        Haptics.tick()
        if cluster.members.count > 1,
           let fit = GeoRegion.fitting(cluster.members.map(\.coordinate), padding: 2.2, minimumDelta: 0.01) {
            withAnimation(.easeInOut(duration: 0.6)) { position = .region(fit.mkRegion) }
        } else {
            focusedID = cluster.representative.id
            selected = cluster.representative
        }
    }

    private func fitAll() {
        guard let fit = GeoRegion.fitting(frames.map(\.coordinate)) else { return }
        withAnimation(.easeInOut(duration: 0.6)) { position = .region(fit.mkRegion) }
    }
}

// MARK: - Marker

/// 지도 위 사진 썸네일 + 촬영 방향 부채꼴 + 클러스터 장수
struct FrameMapMarker: View {
    let frame: Frame
    let count: Int
    var isSelected: Bool = false
    var isDimmed: Bool = false

    var body: some View {
        ZStack {
            ShotConeGlyph(fov: frame.camera.horizontalFOV, heading: frame.heading, size: 92)
            FrameThumbnail(frame: frame, size: 40)
                .overlay(Rectangle().stroke(Color.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .focusLock(isSelected)
            if count > 1 {
                Text(verbatim: "\(count)")
                    .font(VF.Typeface.mono(10, weight: .semibold))
                    .foregroundStyle(VF.Palette.onAmber)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(VF.Palette.amber)
                    .offset(x: 21, y: -21)
            }
        }
        .frame(width: 92, height: 92)
        .opacity(isDimmed ? 0.28 : 1)
        .contentShape(Rectangle().size(width: 48, height: 48).offset(x: 22, y: 22))
        .accessibilityLabel(count > 1 ? "\(frame.caption) 외 \(count - 1)장" : frame.caption)
    }
}

struct MapSquareButton: View {
    let symbol: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isOn ? VF.Palette.onAmber : Color.white)
                .frame(width: 42, height: 42)
                .background(isOn ? VF.Palette.amber : Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: VF.Metric.corner))
                .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(Color.white.opacity(0.15), lineWidth: VF.Metric.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Panels

/// 역방향 탐색 결과: "이 영역을 향해 찍힌 자리 N곳"
struct TargetResultsPanel: View {
    let matches: [TargetMatch]
    var onSelect: (Frame) -> Void
    var onClear: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let title: String = matches.isEmpty ? "이 영역을 향한 프레임이 아직 없어요" : "이 영역을 향해 찍힌 자리 \(matches.count)곳"
        let subtitle: String = matches.isEmpty ? "영역을 조금 넓게 그려보세요" : "점선을 따라가면 서야 할 자리가 보여요"
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(VF.Typeface.title(16))
                        .foregroundStyle(Color.white)
                    Text(subtitle)
                        .font(VF.Typeface.body(12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                Button("지우기", action: onClear)
                    .buttonStyle(.plain)
                    .font(VF.Typeface.label(13))
                    .foregroundStyle(VF.Palette.amber)
            }
            if !matches.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(matches) { match in
                            Button {
                                onSelect(match.frame)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    FrameThumbnail(frame: match.frame, size: 96, fill: false)
                                    Text(model.catalog.place(match.frame.placeID)?.name ?? "")
                                        .font(VF.Typeface.label(12))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(1)
                                    Text(verbatim: "\(VFFormat.distance(match.distance)) · \(VFFormat.compass(match.bearing))")
                                        .font(VF.Typeface.mono(10))
                                        .foregroundStyle(VF.Palette.amber)
                                }
                                .frame(width: 96, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .background(VF.Palette.matte.opacity(0.95), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: VF.Metric.hairline))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

/// 지도에서 사진을 탭했을 때 아래에 뜨는 카드
struct MapPreviewCard: View {
    let frame: Frame
    var onCard: () -> Void
    var onPlace: () -> Void
    var onClose: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FrameThumbnail(frame: frame, size: 88, fill: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.catalog.place(frame.placeID)?.name ?? "")
                    .font(VF.Typeface.title(17))
                    .foregroundStyle(Color.white)
                Text(frame.caption)
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    compactButton("촬영 카드", filled: true, action: onCard)
                    compactButton("장소 보기", filled: false, action: onPlace)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(12)
        .background(VF.Palette.matte.opacity(0.95), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: VF.Metric.hairline))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func compactButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VF.Typeface.label(12, weight: .semibold))
                .foregroundStyle(filled ? VF.Palette.onAmber : Color.white)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(filled ? VF.Palette.amber : Color.clear, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
                .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(Color.white.opacity(filled ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
