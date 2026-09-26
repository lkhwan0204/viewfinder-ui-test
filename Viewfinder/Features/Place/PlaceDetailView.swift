import SwiftUI

/// 장소 상세 = 정보 페이지가 아니라 "촬영 계획서".
/// 포인트 → 빛 타임라인 → 사계절 → 초점거리 → 가기 전에 → 현장 업데이트
struct PlaceDetailView: View {
    let placeID: String
    var initialSpotID: String? = nil

    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location

    @State private var spotID: String?
    @State private var date = Date()
    @State private var minutes: Double = 12 * 60
    @State private var didInitTime = false
    @State private var showPlan = false
    @State private var showReport = false
    @State private var saveTarget: Frame?

    var body: some View {
        if let place = model.catalog.place(placeID) {
            content(place)
        } else {
            ContentUnavailableView("장소를 찾을 수 없어요", systemImage: "mappin.slash")
        }
    }

    private func content(_ place: Place) -> some View {
        let spot = currentSpot(place)
        let placeFrames = model.catalog.frames(atPlace: place.id)
        let spotFrames = model.catalog.frames(atSpot: spot.id)
        let timelineFrames = spotFrames.isEmpty ? placeFrames : spotFrames
        let moment = Calendar.kst.startOfDay(for: date).addingTimeInterval(minutes * 60)
        let hero = heroFrame(candidates: timelineFrames, fallback: placeFrames, spot: spot, moment: moment)
        let latestReport = model.catalog.reports(for: place.id).first

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let hero {
                    PlaceHero(
                        place: place,
                        frame: hero,
                        distanceText: VFFormat.distance(GeoMath.distance(location.reference, place.coordinate)),
                        frameCount: placeFrames.count
                    )
                }

                VStack(alignment: .leading, spacing: 40) {
                    if let latestReport {
                        LatestReportRow(report: latestReport)
                    }

                    SpotsSection(place: place, selectedSpot: spot) { id in
                        withAnimation(.snappy) { spotID = id }
                        syncTime(toSpot: id, place: place)
                    }

                    LightTimelineSection(spot: spot, frames: timelineFrames, date: $date, minutes: $minutes)

                    SeasonsSection(frames: placeFrames)

                    FocalUsageSection(place: place)

                    PracticalSection(place: place)

                    ReportsSection(place: place) { showReport = true }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .background(VF.Palette.background)
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaBar(hero: hero)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(place.name) · \(place.summary)") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            if spotID == nil { spotID = initialSpotID ?? place.spots.first?.id }
            if !didInitTime {
                syncTime(toSpot: spotID ?? spot.id, place: place)
                didInitTime = true
            }
        }
        .sheet(isPresented: $showPlan) {
            if let hero { ShootPlanSheet(place: place, frame: hero) }
        }
        .sheet(isPresented: $showReport) {
            ReportComposer(place: place)
        }
        .sheet(item: $saveTarget) { frame in
            SaveToRollSheet(frame: frame)
        }
    }

    // MARK: Helpers

    private func currentSpot(_ place: Place) -> Spot {
        place.spots.first { $0.id == spotID }
            ?? place.spots.first
            ?? Spot(id: place.id, placeID: place.id, name: place.name, coordinate: place.coordinate, access: "")
    }

    /// 선택한 시간의 빛과 같은 성격으로 찍힌 사진을 대표 사진으로 (없으면 가장 대표적인 사진)
    private func heroFrame(candidates: [Frame], fallback: [Frame], spot: Spot, moment: Date) -> Frame? {
        let phase = LightClassifier.phase(at: moment, coordinate: spot.coordinate)
        return candidates.first { model.catalog.phase(of: $0).isSameKind(as: phase) }
            ?? candidates.first
            ?? fallback.first
    }

    /// 포인트를 바꾸면 그 포인트 대표 사진이 찍힌 빛의 시각으로 타임라인을 옮깁니다.
    private func syncTime(toSpot id: String, place: Place) {
        guard let primary = model.catalog.frames(atSpot: id).first ?? model.catalog.frames(atPlace: place.id).first else { return }
        let target = ShootTime.target(for: primary, on: date)
        let value = target.timeIntervalSince(Calendar.kst.startOfDay(for: date)) / 60
        withAnimation(.snappy) { minutes = min(max(value, 0), 1435) }
    }

    private func ctaBar(hero: Frame?) -> some View {
        HStack(spacing: 10) {
            if let hero {
                let saved = model.isSaved(hero.id)
                Button {
                    saveTarget = hero
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(saved ? VF.Palette.amber : VF.Palette.textPrimary)
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(VF.Palette.textPrimary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("롤에 담기")

                Button {
                    showPlan = true
                } label: {
                    Label("촬영 계획하기", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.vfPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(VF.Palette.background.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
        }
    }
}

// MARK: - Hero

struct PlaceHero: View {
    let place: Place
    let frame: Frame
    let distanceText: String
    let frameCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FramePhotoView(frame: frame)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 440)
                .id(frame.id)
                .transition(.opacity)
                .padding(.top, 104)

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(VF.Typeface.display(34))
                    .foregroundStyle(Color.white)
                Text("\(place.region) · 나에게서 \(distanceText) · 프레임 \(frameCount)장")
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(Color.white.opacity(0.65))
                Text(place.summary)
                    .font(VF.Typeface.body(15))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            ExifStrip(frame: frame)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(VF.Palette.matte)
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.3), value: frame.id)
    }
}

struct LatestReportRow: View {
    let report: FieldReport

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.kind.symbol)
                .foregroundStyle(report.kind == .closure ? VF.Palette.danger : VF.Palette.amber)
            Text(report.message)
                .font(VF.Typeface.body(14))
                .foregroundStyle(VF.Palette.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(verbatim: VFFormat.ago(report.postedAt, now: Date()))
                .font(VF.Typeface.mono(10))
                .foregroundStyle(VF.Palette.textTertiary)
        }
        .padding(12)
        .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
        .accessibilityElement(children: .combine)
    }
}
