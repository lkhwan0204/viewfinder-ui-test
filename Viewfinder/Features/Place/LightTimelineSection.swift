import SwiftUI
import MapKit

/// 02 빛 타임라인: 슬라이더를 끌면 지도 위 해의 방향이 움직이고,
/// 대표 사진도 그 시간대에 찍힌 사진으로 바뀝니다. "몇 시에 가야 하는지"를 직접 만져보며 알게 됩니다.
struct LightTimelineSection: View {
    let spot: Spot
    let frames: [Frame]
    @Binding var date: Date
    @Binding var minutes: Double

    var body: some View {
        let dayStart = Calendar.kst.startOfDay(for: date)
        let moment = dayStart.addingTimeInterval(minutes * 60)
        let sun = SunCalculator.position(at: moment, coordinate: spot.coordinate)
        let phase = LightClassifier.phase(at: moment, coordinate: spot.coordinate)
        let times = SunCalculator.times(on: date, coordinate: spot.coordinate)
        let weekend = DiscoveryEngine.weekendDays(from: Date()).first

        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(index: "02", title: "빛 타임라인", subtitle: "시간을 끌어서 해의 방향과 사진의 빛을 미리 확인하세요")

            HStack(spacing: 8) {
                DatePicker("날짜", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                Spacer()
                quickDay("오늘", Date())
                if let weekend { quickDay("이번 주말", weekend) }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: VFFormat.time(moment))
                    .font(VF.Typeface.mono(40, weight: .light))
                    .foregroundStyle(VF.Palette.textPrimary)
                    .contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 3) {
                    Label(phase.title, systemImage: phase.symbol)
                        .font(VF.Typeface.label(13))
                        .foregroundStyle(phase.isGolden || phase.isBlue ? VF.Palette.amber : VF.Palette.textSecondary)
                    Text(verbatim: "고도 \(Int(sun.altitude.rounded()))° · 방위 \(Int(sun.azimuth.rounded()))° \(VFFormat.compass(sun.azimuth))")
                        .font(VF.Typeface.mono(11))
                        .foregroundStyle(VF.Palette.textSecondary)
                }
            }

            SunDirectionMap(spot: spot, frames: frames, sun: sun)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: VF.Metric.corner))
                .id(spot.id)

            if let primary = frames.first {
                let advice = LightingAdvisor.advice(heading: primary.heading, fov: primary.camera.horizontalFOV, sun: sun)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sun.max")
                        .foregroundStyle(VF.Palette.amber)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(advice.title)
                            .font(VF.Typeface.label(14, weight: .semibold))
                            .foregroundStyle(VF.Palette.textPrimary)
                        Text(advice.detail)
                            .font(VF.Typeface.body(13))
                            .foregroundStyle(VF.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
            }

            SkyScrubber(coordinate: spot.coordinate, date: date, minutes: $minutes)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    eventChip("블루아워", times.dawn, dayStart: dayStart)
                    eventChip("일출", times.sunrise, dayStart: dayStart)
                    eventChip("골든 끝", times.goldenMorningEnd, dayStart: dayStart)
                    eventChip("골든아워", times.goldenEveningStart, dayStart: dayStart)
                    eventChip("일몰", times.sunset, dayStart: dayStart)
                    eventChip("블루아워", times.blueEveningStart, dayStart: dayStart)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func quickDay(_ title: String, _ day: Date) -> some View {
        Button(title) {
            Haptics.tick()
            date = day
        }
        .buttonStyle(.plain)
        .font(VF.Typeface.label(12))
        .foregroundStyle(VF.Palette.amber)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(VF.Palette.amber.opacity(0.5), lineWidth: 1))
    }

    private func eventChip(_ title: String, _ time: Date?, dayStart: Date) -> some View {
        Button {
            guard let time else { return }
            Haptics.tick()
            withAnimation(.snappy) {
                minutes = min(max(time.timeIntervalSince(dayStart) / 60, 0), 1435)
            }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(VF.Typeface.label(11))
                    .foregroundStyle(VF.Palette.textSecondary)
                Text(verbatim: time.map { VFFormat.time($0) } ?? "—")
                    .font(VF.Typeface.mono(12, weight: .medium))
                    .foregroundStyle(VF.Palette.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(VF.Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 하루의 하늘빛 위를 드래그해 시간을 고릅니다 (5분 단위, 정시마다 햅틱).
struct SkyScrubber: View {
    let coordinate: GeoPoint
    let date: Date
    @Binding var minutes: Double

    @State private var lastHour = -1

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let x = width * CGFloat(minutes / 1440)
                ZStack(alignment: .leading) {
                    SkyBand(coordinate: coordinate, date: date)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: x - 1)
                    ViewfinderCorners(length: 6)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                        .frame(width: 22, height: geo.size.height + 8)
                        .offset(x: x - 11)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / width, 0), 1)
                            let snapped = (Double(ratio) * 1440 / 5).rounded() * 5
                            minutes = min(snapped, 1435)
                            let hour = Int(minutes / 60)
                            if hour != lastHour {
                                lastHour = hour
                                Haptics.tick()
                            }
                        }
                )
            }
            .frame(height: 40)

            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(verbatim: String(format: "%02d", hour))
                        .font(VF.Typeface.mono(9))
                        .foregroundStyle(VF.Palette.textTertiary)
                    if hour != 24 { Spacer() }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("시간 선택")
        .accessibilityValue(String(format: "%02d시 %02d분", Int(minutes) / 60, Int(minutes) % 60))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(minutes + 30, 1435)
            case .decrement: minutes = max(minutes - 30, 0)
            @unknown default: break
            }
        }
    }
}

/// 포인트 기준 해의 방향선 + 프레임 시야 부채꼴
struct SunDirectionMap: View {
    let spot: Spot
    let frames: [Frame]
    let sun: SunPosition

    var body: some View {
        let sunEnd = GeoMath.destination(from: spot.coordinate, bearing: sun.azimuth, distance: 1500)
        let above = sun.altitude > -4
        let sunTitle = above ? "해" : "해 (지평선 아래)"
        Map(
            initialPosition: .region(MKCoordinateRegion(center: spot.coordinate.clCoordinate, latitudinalMeters: 4000, longitudinalMeters: 4000)),
            interactionModes: [.zoom]
        ) {
            ForEach(frames) { frame in
                Annotation(frame.caption, coordinate: frame.coordinate.clCoordinate, anchor: .center) {
                    ShotConeGlyph(fov: frame.camera.horizontalFOV, heading: frame.heading, size: 120, color: Color.white)
                }
            }
            MapPolyline(coordinates: [spot.coordinate.clCoordinate, sunEnd.clCoordinate])
                .stroke(
                    above ? VF.Palette.amber : Color.white.opacity(0.35),
                    style: StrokeStyle(lineWidth: above ? 2.5 : 1.5, dash: above ? [] : [4, 4])
                )
            Annotation(sunTitle, coordinate: sunEnd.clCoordinate, anchor: .center) {
                Image(systemName: above ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(above ? VF.Palette.amber : Color.white.opacity(0.7))
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            Annotation(spot.name, coordinate: spot.coordinate.clCoordinate, anchor: .center) {
                Circle()
                    .fill(VF.Palette.amber)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .annotationTitles(.hidden)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .topLeading) {
            Text(verbatim: "━ 해의 방향   ◠ 프레임 시야")
                .font(VF.Typeface.mono(10))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.55))
                .padding(8)
        }
    }
}
