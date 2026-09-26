import SwiftUI
import MapKit

/// 촬영 카드: "어디에 서서, 어느 방향을 보고, 언제, 무엇으로" 찍었는지.
/// 이 네 가지가 있어야 "나도 찍을 수 있겠다"를 상상할 수 있습니다.
struct ShotCardView: View {
    let frame: Frame
    var onOpenPlace: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showSave = false

    private let columns = [
        GridItem(.flexible(), spacing: 16, alignment: .topLeading),
        GridItem(.flexible(), spacing: 16, alignment: .topLeading)
    ]

    var body: some View {
        let relation = SunCalculator.relation(of: frame.capturedAt, at: frame.coordinate)
        let saved = model.isSaved(frame.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이 사진은 이렇게 찍혔어요")
                        .font(VF.Typeface.title(20))
                        .foregroundStyle(VF.Palette.textPrimary)
                    Text(frame.caption)
                        .font(VF.Typeface.body(14))
                        .foregroundStyle(VF.Palette.textSecondary)
                }

                ShotMiniMap(frame: frame)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: VF.Metric.corner))

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    fact("시기", "\(VFFormat.monthPart(frame.capturedAt)) · \(frame.season.title)")
                    fact("빛", relation.text)
                    fact("날씨", frame.weather)
                    fact("렌즈", "\(frame.camera.focalLength)mm · 화각 \(Int(frame.camera.horizontalFOV.rounded()))°")
                    fact("노출", "\(frame.camera.apertureText) · \(frame.camera.shutter) · ISO \(frame.camera.iso)")
                    fact("장비", frame.camera.tripod ? "삼각대 사용" : "핸드헬드")
                    fact("서 있던 곳", frame.standingNote)
                    fact("방향", "\(VFFormat.compass(frame.heading)) \(Int(frame.heading))°")
                }

                credit

                HStack(spacing: 10) {
                    Button("이 포인트 보기", action: onOpenPlace)
                        .buttonStyle(.vfSecondary)
                    Button {
                        showSave = true
                    } label: {
                        Label(saved ? "담은 프레임" : "프레임 저장", systemImage: saved ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.vfPrimary)
                }

                Button {
                    dismiss()
                    model.openInField(frame.id)
                } label: {
                    Label("필드 모드로 안내받기", systemImage: "scope")
                        .font(VF.Typeface.label(14))
                        .foregroundStyle(VF.Palette.amber)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(VF.Palette.surface)
        .sheet(isPresented: $showSave) {
            SaveToRollSheet(frame: frame)
        }
    }

    private var credit: some View {
        HStack(spacing: 8) {
            Text(verbatim: "© \(frame.photographer)")
                .font(VF.Typeface.mono(11))
                .foregroundStyle(VF.Palette.textSecondary)
            Spacer()
            if frame.verified {
                VerifiedBadge()
            } else {
                Label("미인증 · 위치 정보 없음", systemImage: "questionmark.circle")
                    .font(VF.Typeface.label(11))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(VF.Typeface.label(11))
                .foregroundStyle(VF.Palette.textTertiary)
            Text(value)
                .font(VF.Typeface.body(14))
                .foregroundStyle(VF.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 촬영 위치 ● 와 시야 부채꼴, 시선 방향 점선
struct ShotMiniMap: View {
    let frame: Frame

    var body: some View {
        let sight = GeoMath.destination(from: frame.coordinate, bearing: frame.heading, distance: 1800)
        Map(
            initialPosition: .region(MKCoordinateRegion(center: frame.coordinate.clCoordinate, latitudinalMeters: 3200, longitudinalMeters: 3200)),
            interactionModes: []
        ) {
            MapPolyline(coordinates: [frame.coordinate.clCoordinate, sight.clCoordinate])
                .stroke(VF.Palette.amber, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Annotation(frame.caption, coordinate: frame.coordinate.clCoordinate, anchor: .center) {
                ZStack {
                    ShotConeGlyph(fov: frame.camera.horizontalFOV, heading: frame.heading, size: 150)
                    Circle()
                        .fill(VF.Palette.amber)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .overlay(alignment: .topLeading) {
            Text(verbatim: "● 촬영 위치   ▸ \(VFFormat.compass(frame.heading)) \(Int(frame.heading))°")
                .font(VF.Typeface.mono(10))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.55))
                .padding(8)
        }
    }
}
