import SwiftUI

/// 롤 → 촬영 계획. 가까운 프레임끼리 하루로 묶고, 각 포인트의 빛 시각 순서로 동선을 제안합니다.
/// 예) 06:10 오조리 일출 → 06:38 광치기해변 → 18:18 섭지코지 일몰
struct PlanView: View {
    let rollID: UUID

    @Environment(AppModel.self) private var model
    @State private var startDay: Date = DiscoveryEngine.weekendDays(from: Date()).first ?? Date()

    var body: some View {
        let roll = model.roll(rollID)
        let frames = roll.map { model.frames(in: $0) } ?? []
        let plan = PlanBuilder.build(frames: frames, catalog: model.catalog, startDay: startDay)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("각 포인트의 빛 시간에 맞춰 동선을 짰어요")
                        .font(VF.Typeface.body(14))
                        .foregroundStyle(VF.Palette.textSecondary)
                    DatePicker("시작 날짜", selection: $startDay, in: Calendar.kst.startOfDay(for: Date())..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                if plan.isEmpty {
                    EmptyStateView(symbol: "calendar", title: "계획할 프레임이 없어요", message: "롤에 프레임을 먼저 담아주세요.")
                }

                ForEach(plan.days) { day in
                    PlanDayCard(day: day)
                }

                Text("다음 단계: 계획을 시작하면 Live Activity로 잠금 화면과 Dynamic Island에 \"일몰까지 23분\"을 띄울 수 있어요 (위젯 익스텐션 필요).")
                    .font(VF.Typeface.body(11))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
            .padding(20)
        }
        .background(VF.Palette.background)
        .navigationTitle(roll?.name ?? "촬영 계획")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlanDayCard: View {
    let day: PlanDay
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(VFFormat.dateLabel(day.date))
                    .font(VF.Typeface.title(18))
                    .foregroundStyle(VF.Palette.textPrimary)
                Text(day.regionName)
                    .font(VF.Typeface.mono(11, weight: .medium))
                    .foregroundStyle(VF.Palette.amber)
                Spacer()
                Text(verbatim: "\(day.stops.count) STOPS")
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
            .padding(.bottom, 10)

            ForEach(day.stops) { stop in
                if let travel = stop.travel {
                    HStack(spacing: 6) {
                        Image(systemName: travel.byAir ? "airplane" : "car")
                        Text(verbatim: travel.text)
                        if let warning = stop.warning {
                            Text(verbatim: "· \(warning)")
                                .foregroundStyle(VF.Palette.amber)
                        }
                    }
                    .font(VF.Typeface.mono(10))
                    .foregroundStyle(VF.Palette.textTertiary)
                    .padding(.leading, 70)
                    .padding(.vertical, 4)
                }
                HStack(alignment: .top, spacing: 12) {
                    Text(verbatim: VFFormat.time(stop.time))
                        .font(VF.Typeface.mono(18, weight: .medium))
                        .foregroundStyle(VF.Palette.textPrimary)
                        .frame(width: 58, alignment: .trailing)
                    Circle()
                        .fill(VF.Palette.amber)
                        .frame(width: 8, height: 8)
                        .padding(.top, 7)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.placeName)
                            .font(VF.Typeface.label(15, weight: .semibold))
                            .foregroundStyle(VF.Palette.textPrimary)
                        Text("\(stop.spotName) · \(stop.relationText)")
                            .font(VF.Typeface.body(12))
                            .foregroundStyle(VF.Palette.textSecondary)
                    }
                    Spacer()
                    FrameThumbnail(frame: stop.frame, size: 52, fill: false)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        model.openInField(stop.frame.id)
                    } label: {
                        Label("필드 모드로", systemImage: "scope")
                    }
                }
            }
        }
        .padding(16)
        .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
    }
}
