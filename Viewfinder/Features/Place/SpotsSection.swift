import SwiftUI
import MapKit

/// 01 포인트: 한 장소에도 서는 자리마다 완전히 다른 사진이 나옵니다.
struct SpotsSection: View {
    let place: Place
    let selectedSpot: Spot
    var onSelect: (String) -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "01", title: "포인트", subtitle: "서는 자리마다 다른 사진이 나와요")

            if let note = place.sensitivity.note {
                ProtectedNotice(note: note)
            }

            SpotMap(place: place, selectedSpotID: selectedSpot.id)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: VF.Metric.corner))

            VStack(spacing: 8) {
                ForEach(place.spots) { spot in
                    let count = model.catalog.frames(atSpot: spot.id).count
                    let isOn = spot.id == selectedSpot.id
                    Button {
                        Haptics.tick()
                        onSelect(spot.id)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(isOn ? VF.Palette.amber : Color.clear)
                                .overlay(Circle().stroke(isOn ? VF.Palette.amber : VF.Palette.textTertiary, lineWidth: 1.5))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spot.name)
                                    .font(VF.Typeface.label(15, weight: .semibold))
                                    .foregroundStyle(VF.Palette.textPrimary)
                                Text(spot.access)
                                    .font(VF.Typeface.body(12))
                                    .foregroundStyle(VF.Palette.textSecondary)
                            }
                            Spacer()
                            Text(verbatim: "프레임 \(count)")
                                .font(VF.Typeface.mono(11))
                                .foregroundStyle(isOn ? VF.Palette.amber : VF.Palette.textTertiary)
                        }
                        .padding(12)
                        .background(isOn ? VF.Palette.amberSoft : VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
                        .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(isOn ? VF.Palette.amber.opacity(0.6) : Color.clear, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }

            LookAroundBox(spot: selectedSpot, isProtected: place.sensitivity.isProtected)
        }
    }
}

/// 포인트와 각 프레임의 시야 부채꼴. 보호 장소는 정확한 위치 대신 넓은 원으로 흐립니다.
struct SpotMap: View {
    let place: Place
    let selectedSpotID: String

    @Environment(AppModel.self) private var model

    var body: some View {
        let frames = model.catalog.frames(atPlace: place.id)
        let region = GeoRegion.fitting(place.spots.map(\.coordinate), padding: 2.5, minimumDelta: 0.012)
            ?? GeoRegion(center: place.coordinate, latitudeDelta: 0.02, longitudeDelta: 0.02)
        Map(initialPosition: .region(region.mkRegion), interactionModes: [.pan, .zoom]) {
            if place.sensitivity.isProtected {
                MapCircle(center: place.coordinate.clCoordinate, radius: 700)
                    .foregroundStyle(VF.Palette.amber.opacity(0.18))
            } else {
                ForEach(frames) { frame in
                    Annotation(frame.caption, coordinate: frame.coordinate.clCoordinate, anchor: .center) {
                        ShotConeGlyph(
                            fov: frame.camera.horizontalFOV,
                            heading: frame.heading,
                            size: 110,
                            color: frame.spotID == selectedSpotID ? VF.Palette.amber : Color.white
                        )
                    }
                }
                ForEach(place.spots) { spot in
                    Annotation(spot.name, coordinate: spot.coordinate.clCoordinate, anchor: .center) {
                        Circle()
                            .fill(spot.id == selectedSpotID ? VF.Palette.amber : Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .annotationTitles(.hidden)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .bottomLeading) {
            if place.sensitivity.isProtected {
                Text("정확한 포인트는 공개하지 않아요")
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.6))
                    .padding(8)
            }
        }
    }
}

/// 가능하면 Look Around로 그 자리를 미리 보여줍니다.
struct LookAroundBox: View {
    let spot: Spot
    let isProtected: Bool

    @State private var scene: MKLookAroundScene?
    @State private var state: LoadState = .loading

    private enum LoadState { case loading, ready, unavailable }

    var body: some View {
        Group {
            if isProtected {
                placeholder("보호 구역은 거리 사진을 보여주지 않아요", symbol: "eye.slash")
            } else {
                switch state {
                case .loading:
                    placeholder("그 자리를 미리 불러오는 중…", symbol: "binoculars")
                case .ready:
                    LookAroundPreview(initialScene: scene)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: VF.Metric.corner))
                case .unavailable:
                    placeholder("이 포인트는 Look Around를 지원하지 않아요", symbol: "binoculars")
                }
            }
        }
        .task(id: spot.id) {
            await load()
        }
    }

    private func load() async {
        guard !isProtected else { return }
        state = .loading
        scene = nil
        let request = MKLookAroundSceneRequest(coordinate: spot.coordinate.clCoordinate)
        do {
            let result = try await request.scene
            scene = result
            state = result == nil ? .unavailable : .ready
        } catch {
            state = .unavailable
        }
    }

    private func placeholder(_ text: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(VF.Typeface.body(13))
        .foregroundStyle(VF.Palette.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
        .overlay(
            RoundedRectangle(cornerRadius: VF.Metric.corner)
                .stroke(VF.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }
}

/// 민감 장소 보호 안내
struct ProtectedNotice: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "eye.slash")
                .foregroundStyle(VF.Palette.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("보호가 필요한 장소예요")
                    .font(VF.Typeface.label(14, weight: .semibold))
                    .foregroundStyle(VF.Palette.textPrimary)
                Text(note)
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(VF.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VF.Palette.amberSoft, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
    }
}
