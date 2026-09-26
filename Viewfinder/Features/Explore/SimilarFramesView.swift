import SwiftUI

/// 비슷한 프레임: 같은 장소가 아니라 "비슷한 사진이 나오는 다른 장소"로 이어집니다.
/// 사진에서 사진으로 흘러간 경로를 위쪽에 남겨, 몰랐던 장소에 닿는 과정을 보여줍니다.
struct SimilarFramesView: View {
    let start: Frame
    var onShowInFeed: (Frame) -> Void
    var onOpenPlace: (Frame) -> Void

    @Environment(AppModel.self) private var model
    @State private var trail: [Frame] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let path = [start] + trail
        let current = path.last ?? start
        let matches = SimilarityEngine.similar(to: current, in: model.catalog.frames, catalog: model.catalog, limit: 10)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("비슷한 프레임")
                        .font(VF.Typeface.title(22))
                        .foregroundStyle(Color.white)
                    Text("이런 느낌의 사진이 나오는 다른 곳")
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                breadcrumb(path)

                sourceCard(current)

                Text("닮은 프레임 \(matches.count)장")
                    .font(VF.Typeface.title(17))
                    .foregroundStyle(Color.white)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(matches) { match in
                        Button {
                            Haptics.tick()
                            withAnimation(.snappy) { trail.append(match.frame) }
                        } label: {
                            SimilarCell(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(VF.Palette.matte.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// 광치기해변 → 오조리 내수면 → 두물머리 …
    private func breadcrumb(_ path: [Frame]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, frame in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    Button {
                        withAnimation(.snappy) { trail = Array(trail.prefix(index)) }
                    } label: {
                        Text(model.catalog.place(frame.placeID)?.name ?? "")
                            .font(VF.Typeface.label(12))
                            .foregroundStyle(index == path.count - 1 ? VF.Palette.amber : Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func sourceCard(_ frame: Frame) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FramePhotoView(frame: frame)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .viewfinderCorners(VF.Palette.amber.opacity(0.8), length: 12, lineWidth: 1.5, outset: 6)
                .id(frame.id)
                .transition(.opacity)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.catalog.place(frame.placeID)?.name ?? "")
                    .font(VF.Typeface.display(24))
                    .foregroundStyle(Color.white)
                Text(frame.caption)
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            HStack(spacing: 10) {
                Button("피드에서 보기") { onShowInFeed(frame) }
                    .buttonStyle(.vfSecondary)
                Button("장소 보기") { onOpenPlace(frame) }
                    .buttonStyle(.vfPrimary)
            }
        }
    }
}

struct SimilarCell: View {
    let match: SimilarityMatch

    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.white.opacity(0.04)
                FramePhotoView(frame: match.frame)
                    .padding(6)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            Text(model.catalog.place(match.frame.placeID)?.name ?? "")
                .font(VF.Typeface.label(14, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Text(verbatim: match.reasons.joined(separator: " · "))
                .font(VF.Typeface.mono(10))
                .foregroundStyle(VF.Palette.amber)
                .lineLimit(1)
            Text(verbatim: VFFormat.distance(GeoMath.distance(location.reference, match.frame.coordinate)))
                .font(VF.Typeface.mono(10))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }
}
