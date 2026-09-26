import SwiftUI

/// 장소 상세의 "촬영 계획하기": 고른 날짜에 이 프레임과 같은 빛을 만나는 시각과 조건 예보
struct ShootPlanSheet: View {
    let place: Place
    let frame: Frame

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var day: Date = DiscoveryEngine.weekendDays(from: Date()).first ?? Date()
    @State private var showSave = false

    private struct TimelineEvent: Identifiable {
        let id: String
        let time: Date
        let title: String
        let isTarget: Bool
    }

    var body: some View {
        let target = ShootTime.target(for: frame, on: day)
        let times = SunCalculator.times(on: day, coordinate: frame.coordinate)
        let outlook = model.forecast.outlook(for: place, on: day)
        let month = Calendar.kst.component(.month, from: day)
        let chance = outlook.likelihood(for: frame.conditions, month: month, bestMonths: place.bestMonths)
        let relation = SunCalculator.relation(of: frame.capturedAt, at: frame.coordinate)
        let events = timeline(times: times, target: target, relation: relation)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        FrameThumbnail(frame: frame, size: 72, fill: false)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                                .font(VF.Typeface.title(18))
                                .foregroundStyle(VF.Palette.textPrimary)
                            Text(frame.caption)
                                .font(VF.Typeface.body(13))
                                .foregroundStyle(VF.Palette.textSecondary)
                        }
                    }

                    DatePicker("촬영 날짜", selection: $day, in: Calendar.kst.startOfDay(for: Date())..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("이 프레임의 조건")
                                .font(VF.Typeface.label(13))
                                .foregroundStyle(VF.Palette.textSecondary)
                            Spacer()
                            Text(verbatim: "\(chance)%")
                                .font(VF.Typeface.mono(28, weight: .light))
                                .foregroundStyle(chance >= 60 ? VF.Palette.amber : VF.Palette.textPrimary)
                        }
                        Text(verbatim: outlook.summary)
                            .font(VF.Typeface.mono(11))
                            .foregroundStyle(VF.Palette.textSecondary)
                        Text("샘플 예보예요. 실제 서비스에서는 WeatherKit과 물때 정보로 바뀝니다.")
                            .font(VF.Typeface.body(11))
                            .foregroundStyle(VF.Palette.textTertiary)
                    }
                    .padding(14)
                    .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("그날의 빛")
                            .font(VF.Typeface.title(16))
                            .foregroundStyle(VF.Palette.textPrimary)
                            .padding(.bottom, 8)
                        ForEach(events) { event in
                            HStack(spacing: 14) {
                                Text(verbatim: VFFormat.time(event.time))
                                    .font(VF.Typeface.mono(15, weight: event.isTarget ? .semibold : .regular))
                                    .foregroundStyle(event.isTarget ? VF.Palette.amber : VF.Palette.textSecondary)
                                    .frame(width: 56, alignment: .leading)
                                Circle()
                                    .fill(event.isTarget ? VF.Palette.amber : VF.Palette.textTertiary)
                                    .frame(width: event.isTarget ? 10 : 6, height: event.isTarget ? 10 : 6)
                                Text(event.title)
                                    .font(VF.Typeface.body(14))
                                    .foregroundStyle(event.isTarget ? VF.Palette.textPrimary : VF.Palette.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, 9)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            showSave = true
                        } label: {
                            Label("롤에 담기", systemImage: "bookmark")
                        }
                        .buttonStyle(.vfSecondary)
                        Button {
                            dismiss()
                            model.openInField(frame.id)
                        } label: {
                            Label("필드 모드로", systemImage: "scope")
                        }
                        .buttonStyle(.vfPrimary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("촬영 계획")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showSave) {
            SaveToRollSheet(frame: frame)
        }
    }

    private func timeline(times: SunTimes, target: Date, relation: SunRelation) -> [TimelineEvent] {
        let candidates: [(String, Date?)] = [
            ("새벽 블루아워 시작", times.dawn),
            ("아침 골든아워 시작", times.blueMorningEnd),
            ("일출", times.sunrise),
            ("아침 골든아워 끝", times.goldenMorningEnd),
            ("저녁 골든아워 시작", times.goldenEveningStart),
            ("일몰", times.sunset),
            ("저녁 블루아워 시작", times.blueEveningStart),
            ("블루아워 끝", times.dusk)
        ]
        var events = candidates.compactMap { item -> TimelineEvent? in
            guard let time = item.1 else { return nil }
            return TimelineEvent(id: item.0, time: time, title: item.0, isTarget: false)
        }
        events.append(TimelineEvent(id: "target", time: target, title: "이 프레임의 빛 · \(relation.text)", isTarget: true))
        return events.sorted { $0.time < $1.time }
    }
}
