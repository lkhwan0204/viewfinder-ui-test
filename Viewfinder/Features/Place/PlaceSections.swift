import SwiftUI

// MARK: - 03 사계절

/// 같은 포인트를 계절별로 좌우 스와이프. "지금 가면 어떤 모습일까"에 답합니다.
struct SeasonsSection: View {
    let frames: [Frame]
    @State private var season: Season = Season.of(month: Calendar.kst.component(.month, from: Date()))

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "03", title: "사계절", subtitle: "같은 자리, 다른 계절 — 지금 가면 어떤 모습일까요?")

            Picker("계절", selection: $season) {
                ForEach(Season.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            TabView(selection: $season) {
                ForEach(Season.allCases) { item in
                    page(item).tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 240)
        }
    }

    @ViewBuilder
    private func page(_ item: Season) -> some View {
        let items = frames.filter { $0.season == item }
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(VF.Palette.amber)
                Text("아직 \(item.title)의 프레임이 없어요")
                    .font(VF.Typeface.label(14, weight: .semibold))
                    .foregroundStyle(VF.Palette.textPrimary)
                Text("이 계절에 가게 되면 첫 번째로 기록해 보세요")
                    .font(VF.Typeface.body(12))
                    .foregroundStyle(VF.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: VF.Metric.corner)
                    .stroke(VF.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
            .padding(.horizontal, 1)
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { frame in
                        let width = 190 * CGFloat(frame.aspectRatio)
                        VStack(alignment: .leading, spacing: 6) {
                            FramePhotoView(frame: frame)
                                .frame(width: width, height: 190)
                            Text(verbatim: "\(VFFormat.monthPart(frame.capturedAt)) · \(frame.caption)")
                                .font(VF.Typeface.body(12))
                                .foregroundStyle(VF.Palette.textSecondary)
                                .lineLimit(1)
                                .frame(width: width, alignment: .leading)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - 04 초점거리

/// "광각이 필요한 곳인지, 망원이 필요한 곳인지" — 장비를 챙기는 판단에 직접 쓰이는 정보
struct FocalUsageSection: View {
    let place: Place

    private let buckets = [14, 24, 35, 50, 85, 135, 200]

    var body: some View {
        let counts = buckets.map { place.focalUsage[$0] ?? 0 }
        let maxCount = max(counts.max() ?? 1, 1)
        let peakIndex = counts.firstIndex(of: counts.max() ?? 0) ?? 0

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "04", title: "사람들이 쓴 초점거리", subtitle: insight(counts: counts, peakIndex: peakIndex))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { index, mm in
                    VStack(spacing: 6) {
                        Text(verbatim: "\(counts[index])")
                            .font(VF.Typeface.mono(9))
                            .foregroundStyle(VF.Palette.textTertiary)
                        Rectangle()
                            .fill(index == peakIndex ? VF.Palette.amber : VF.Palette.textTertiary.opacity(0.45))
                            .frame(height: max(3, 96 * CGFloat(counts[index]) / CGFloat(maxCount)))
                        Text(verbatim: mm == 200 ? "200+" : "\(mm)")
                            .font(VF.Typeface.mono(10))
                            .foregroundStyle(index == peakIndex ? VF.Palette.amber : VF.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 136, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(insight(counts: counts, peakIndex: peakIndex))
        }
    }

    private func insight(counts: [Int], peakIndex: Int) -> String {
        let total = max(counts.reduce(0, +), 1)
        let wide = counts[0] + counts[1] + counts[2]
        let tele = counts[4] + counts[5] + counts[6]
        let peak = buckets[peakIndex]
        if Double(wide) / Double(total) > 0.6 {
            return "대부분 \(peak)mm 안팎의 광각으로 찍어요. 광각 렌즈를 챙기세요."
        }
        if Double(tele) / Double(total) > 0.5 {
            return "망원이 많이 쓰이는 곳이에요. \(peak)mm 전후를 챙기세요."
        }
        return "표준 화각(\(peak)mm)이 가장 많아요. 줌 렌즈 하나면 충분해요."
    }
}

// MARK: - 05 가기 전에

/// 리뷰 텍스트 대신 구조화된 실용 정보. 사진가에게는 별점보다 "삼각대 펼 수 있나"가 중요합니다.
struct PracticalSection: View {
    let place: Place
    @Environment(\.openURL) private var openURL

    var body: some View {
        let info = place.practical
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "05", title: "가기 전에", subtitle: "별점 대신, 사진가에게 필요한 정보만")

            VStack(spacing: 0) {
                row("parkingsign.circle", "주차", info.parking)
                row("wonsign.circle", "입장료", info.fee)
                row("camera", "삼각대", "\(info.tripod.title) · \(info.tripodNote)", tint: color(info.tripod))
                row("airplane", "드론", "\(info.drone.title) · \(info.droneNote)", tint: color(info.drone))
                row("person.2", "혼잡", info.crowd)
                row("figure.walk", "접근", info.walk)
                if let tide = info.tide {
                    row("water.waves", "물때", tide)
                }
            }

            if !place.etiquette.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("지켜주세요", systemImage: "hand.raised")
                        .font(VF.Typeface.label(13, weight: .semibold))
                        .foregroundStyle(VF.Palette.amber)
                    ForEach(place.etiquette, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(verbatim: "·")
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(VF.Palette.textSecondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
            }

            Button {
                let c = place.coordinate
                if let url = URL(string: "https://maps.apple.com/?daddr=\(c.latitude),\(c.longitude)&dirflg=d") {
                    openURL(url)
                }
            } label: {
                Label("Apple 지도로 길찾기", systemImage: "arrow.triangle.turn.up.right.diamond")
            }
            .buttonStyle(.vfSecondary)
        }
    }

    private func color(_ permission: Permission) -> Color {
        switch permission {
        case .allowed: return VF.Palette.textPrimary
        case .limited: return VF.Palette.amber
        case .prohibited: return VF.Palette.danger
        }
    }

    private func row(_ symbol: String, _ title: String, _ value: String, tint: Color = VF.Palette.textPrimary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(VF.Palette.textSecondary)
                .frame(width: 22)
            Text(title)
                .font(VF.Typeface.label(13))
                .foregroundStyle(VF.Palette.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(VF.Typeface.body(14))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 06 현장 업데이트

/// 오래된 정보가 가장 큰 불만 요소 — 최근 방문자가 짧은 상태를 남깁니다.
struct ReportsSection: View {
    let place: Place
    var onCompose: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let reports = model.catalog.reports(for: place.id)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(index: "06", title: "현장 업데이트", subtitle: "최근 방문자가 남긴 지금의 상태")

            if reports.isEmpty {
                Text("아직 업데이트가 없어요. 다녀오면 첫 소식을 남겨주세요.")
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(VF.Palette.textSecondary)
            }

            ForEach(reports) { report in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: report.kind.symbol)
                        .foregroundStyle(report.kind == .closure ? VF.Palette.danger : VF.Palette.amber)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(report.message)
                            .font(VF.Typeface.body(14))
                            .foregroundStyle(VF.Palette.textPrimary)
                        Text(verbatim: "\(report.kind.title) · \(VFFormat.ago(report.postedAt, now: Date()))")
                            .font(VF.Typeface.mono(10))
                            .foregroundStyle(VF.Palette.textTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Button(action: onCompose) {
                Label("지금 상태 알리기", systemImage: "plus.bubble")
            }
            .buttonStyle(.vfSecondary)
        }
    }
}

struct ReportComposer: View {
    let place: Place

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: FieldReport.Kind = .condition
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("무엇을 알릴까요?") {
                    Picker("종류", selection: $kind) {
                        ForEach(FieldReport.Kind.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("짧게 적어주세요") {
                    TextField("예: 벚꽃 70% 개화, 주차장 만차", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("올리기") {
                        model.addReport(placeID: place.id, kind: kind, message: message)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
