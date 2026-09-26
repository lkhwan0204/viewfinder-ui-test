import SwiftUI

/// 첫 실행: "어떤 사진을 찍으세요?" 체크박스 대신 끌리는 사진을 고르게 합니다.
/// 고른 사진이 첫 피드의 시드가 됩니다. 위치 권한은 여기서 묻지 않습니다.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: [String] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)
    private let minimum = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(model.catalog.frames) { frame in
                            cell(frame)
                        }
                    }
                }
                .padding(.bottom, 190)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(VF.Palette.matte.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(VF.Palette.amber)
                Text(verbatim: "Viewfinder")
                    .font(VF.Typeface.display(24))
                    .foregroundStyle(.white)
            }
            Text("끌리는 장면을\n골라주세요")
                .font(VF.Typeface.display(34))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("장르를 고르는 대신 사진으로 취향을 알려주세요.\n고른 사진이 첫 피드의 출발점이 돼요.")
                .font(VF.Typeface.body(15))
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
    }

    private func cell(_ frame: Frame) -> some View {
        let order = selected.firstIndex(of: frame.id).map { $0 + 1 }
        return Button {
            toggle(frame.id)
        } label: {
            ZStack {
                VF.Palette.matte
                FramePhotoView(frame: frame)
                    .padding(order == nil ? 5 : 12)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text(verbatim: "\(order)")
                        .font(VF.Typeface.mono(12, weight: .semibold))
                        .foregroundStyle(VF.Palette.onAmber)
                        .frame(width: 22, height: 22)
                        .background(VF.Palette.amber)
                        .padding(6)
                }
            }
            .focusLock(order != nil)
            .opacity(!selected.isEmpty && order == nil ? 0.55 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: order)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(frame.caption)
        .accessibilityAddTraits(order != nil ? .isSelected : [])
    }

    private var bottomBar: some View {
        let status: String = selected.count < minimum
            ? "\(minimum)장 이상 골라주세요 · \(selected.count)장 선택"
            : "\(selected.count)장 선택됨 · 이 느낌으로 시작할게요"
        return VStack(spacing: 12) {
            Text(status)
                .font(VF.Typeface.mono(12))
                .foregroundStyle(Color.white.opacity(0.7))
            Button("탐색 시작") {
                Haptics.shutter()
                model.completeOnboarding(with: selected)
            }
            .buttonStyle(.vfPrimary)
            .disabled(selected.count < minimum)

            Button("건너뛰기") {
                model.completeOnboarding(with: [])
            }
            .buttonStyle(.plain)
            .font(VF.Typeface.label(13))
            .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [VF.Palette.matte.opacity(0), VF.Palette.matte, VF.Palette.matte], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func toggle(_ id: String) {
        Haptics.tick()
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else {
            selected.append(id)
        }
    }
}
