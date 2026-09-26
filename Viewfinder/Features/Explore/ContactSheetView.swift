import SwiftUI

/// 필름 밀착 인화지처럼 작은 사진을 촘촘하게. 여러 장을 빠르게 훑고 비교하는 단계입니다.
/// 각 셀의 화면 위치를 기록해 두었다가, 지도로 넘어갈 때 사진이 "제자리로 흩어지는" 출발점으로 씁니다.
struct ContactSheetView: View {
    let frames: [Frame]
    let focusedID: String?
    var onSelect: (String) -> Void
    var onSimilar: (Frame) -> Void
    @Binding var cellFrames: [String: CGRect]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                            ContactCell(frame: frame, number: index + 1, isFocused: frame.id == focusedID)
                                .id(frame.id)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(key: CellFrameKey.self, value: [frame.id: geo.frame(in: .global)])
                                    }
                                )
                                .onTapGesture {
                                    Haptics.tick()
                                    onSelect(frame.id)
                                }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    Haptics.soft()
                                    onSimilar(frame)
                                }
                                .accessibilityLabel(frame.caption)
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
                .padding(.top, 104)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onPreferenceChange(CellFrameKey.self) { value in
                cellFrames = value
            }
            .onAppear {
                if let id = focusedID { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .background(VF.Palette.matte)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "▸ VIEWFINDER 400    \(frames.count) FRAMES")
                .font(VF.Typeface.mono(10, weight: .medium))
                .foregroundStyle(VF.Palette.amber)
            Text("두 손가락을 모으면 사진들이 지도 위 제자리로 흩어져요")
                .font(VF.Typeface.body(12))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
    }
}

private struct CellFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 밀착 인화 한 칸. 사진은 크롭하지 않고 칸 안에 맞춰 넣습니다.
struct ContactCell: View {
    let frame: Frame
    let number: Int
    let isFocused: Bool

    var body: some View {
        ZStack {
            Color.white.opacity(0.03)
            FramePhotoView(frame: frame)
                .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: String(format: "%02d", number))
                .font(VF.Typeface.mono(9, weight: .medium))
                .foregroundStyle(VF.Palette.amber.opacity(0.85))
                .padding(4)
        }
        .overlay {
            if isFocused {
                ViewfinderCorners(length: 10)
                    .stroke(VF.Palette.amber, style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                    .padding(3)
            }
        }
        .contentShape(Rectangle())
    }
}
