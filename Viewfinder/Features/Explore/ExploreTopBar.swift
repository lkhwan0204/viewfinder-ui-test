import SwiftUI

/// 탐색 상단: 지금의 빛 · 단계 스위처 · 프로필 · 필터 칩
struct ExploreTopBar: View {
    let level: ExploreLevel
    var onLevel: (ExploreLevel) -> Void
    var onProfile: () -> Void

    @Environment(LocationService.self) private var location

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                LightStatusPill(reference: location.reference, referenceName: location.referenceName)
                Spacer(minLength: 4)
                LevelSwitcher(level: level, onSelect: onLevel)
                Button(action: onProfile) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("프로필과 설정")
            }
            .padding(.horizontal, 16)

            FilterBar()
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0.62), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }
}

/// "골든아워까지 1시간 12분" — 앱을 열 때마다 지금 나가면 무엇을 찍을 수 있는지 떠올리게 합니다.
struct LightStatusPill: View {
    let reference: GeoPoint
    let referenceName: String
    @State private var showDetail = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let status = LightStatusBuilder.status(now: context.date, coordinate: reference)
            let highlighted = status.phase.isGolden || status.phase.isBlue
            Button {
                showDetail = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: status.phase.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(highlighted ? VF.Palette.amber : Color.white)
                    Text(status.headline)
                        .font(VF.Typeface.mono(11, weight: .medium))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: VF.Metric.corner))
                .overlay(
                    RoundedRectangle(cornerRadius: VF.Metric.corner)
                        .stroke(highlighted ? VF.Palette.amber.opacity(0.6) : Color.white.opacity(0.14), lineWidth: VF.Metric.hairline)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("지금의 빛, \(status.headline)")
        }
        .sheet(isPresented: $showDetail) {
            TodayLightSheet(reference: reference, referenceName: referenceName)
        }
    }
}

struct LevelSwitcher: View {
    let level: ExploreLevel
    var onSelect: (ExploreLevel) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ExploreLevel.allCases) { item in
                let isOn = item == level
                Button {
                    onSelect(item)
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 34, height: 28)
                        .foregroundStyle(isOn ? VF.Palette.onAmber : Color.white.opacity(0.85))
                        .background(isOn ? VF.Palette.amber : Color.clear, in: RoundedRectangle(cornerRadius: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: VF.Metric.corner + 1))
        .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner + 1).stroke(Color.white.opacity(0.14), lineWidth: VF.Metric.hairline))
    }
}

/// 빛·조건·장면·이동 범위를 자연어에 가까운 칩으로
struct FilterBar: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(DiscoveryFilter.allCases) { filter in
                    FilterChip(title: filter.title, symbol: filter.symbol, isOn: model.activeFilters.contains(filter)) {
                        Haptics.tick()
                        // 위치 권한은 "가까운 곳"이 필요한 칩을 처음 누를 때 요청합니다.
                        if filter.wantsLocation && !location.isAuthorized {
                            location.requestWhenInUse()
                        }
                        withAnimation(.snappy(duration: 0.3)) { model.toggle(filter) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

/// 오늘의 빛 일정
struct TodayLightSheet: View {
    let reference: GeoPoint
    let referenceName: String

    var body: some View {
        let now = Date()
        let times = SunCalculator.times(on: now, coordinate: reference)
        let moon = SunCalculator.moonIllumination(at: now)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 빛")
                        .font(VF.Typeface.title(22))
                        .foregroundStyle(VF.Palette.textPrimary)
                    Text("\(VFFormat.dateLabel(now)) · \(referenceName)")
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(VF.Palette.textSecondary)
                }

                SkyBand(coordinate: reference, date: now, marker: now)
                    .frame(height: 34)

                VStack(spacing: 0) {
                    row("새벽 블루아워", range(times.dawn, times.blueMorningEnd), highlight: true)
                    row("일출", point(times.sunrise))
                    row("아침 골든아워", range(times.blueMorningEnd, times.goldenMorningEnd), highlight: true)
                    row("저녁 골든아워", range(times.goldenEveningStart, times.blueEveningStart), highlight: true)
                    row("일몰", point(times.sunset))
                    row("저녁 블루아워", range(times.blueEveningStart, times.dusk), highlight: true)
                    row("달 밝기", "\(Int((moon.fraction * 100).rounded()))%")
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(VF.Palette.surface)
    }

    private func point(_ date: Date?) -> String { date.map { VFFormat.time($0) } ?? "—" }

    private func range(_ start: Date?, _ end: Date?) -> String {
        guard let start, let end else { return "—" }
        return "\(VFFormat.time(start)) – \(VFFormat.time(end))"
    }

    private func row(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(VF.Typeface.body(15))
                .foregroundStyle(VF.Palette.textPrimary)
            Spacer()
            Text(verbatim: value)
                .font(VF.Typeface.mono(14, weight: .medium))
                .foregroundStyle(highlight ? VF.Palette.amber : VF.Palette.textSecondary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
        }
    }
}
