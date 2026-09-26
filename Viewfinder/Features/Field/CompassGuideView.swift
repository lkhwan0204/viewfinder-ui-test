import SwiftUI

/// 나침반 가이드. 다이얼은 실제 방위에 고정되고(기기 방향만큼 회전),
/// 걸어갈 방향 화살표와 촬영 방향 부채꼴이 그 위에 놓입니다. 방향이 맞으면 햅틱으로 알려줍니다.
struct CompassGuideView: View {
    let deviceHeading: Double
    /// 포인트로 걸어갈 방위 (nil이면 도착)
    let walkBearing: Double?
    let shootHeading: Double
    let fov: Double
    /// 시뮬레이터처럼 나침반이 없는 기기
    let isSimulated: Bool
    @Binding var simulatedHeading: Double

    @State private var wasAligned = false

    var body: some View {
        let target = walkBearing ?? shootHeading
        let delta = GeoMath.signedDelta(from: deviceHeading, to: target)
        let aligned = abs(delta) < 4

        VStack(spacing: 14) {
            ZStack {
                CompassDial()
                    .rotationEffect(.degrees(-deviceHeading))

                ShotConeGlyph(fov: fov, heading: shootHeading - deviceHeading, size: 232, color: VF.Palette.amber)
                    .opacity(walkBearing == nil ? 1 : 0.3)

                if let walkBearing {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(VF.Palette.amber)
                        .offset(y: -92)
                        .rotationEffect(.degrees(walkBearing - deviceHeading))
                }

                // 기기가 향한 방향 (항상 화면 위쪽)
                VStack {
                    Rectangle()
                        .fill(aligned ? VF.Palette.amber : Color.white)
                        .frame(width: 3, height: 24)
                    Spacer()
                }
                .frame(height: 262)

                VStack(spacing: 2) {
                    Text(verbatim: "\(Int(GeoMath.normalize(deviceHeading).rounded()))°")
                        .font(VF.Typeface.mono(30, weight: .light))
                        .foregroundStyle(Color.white)
                    Text(VFFormat.compass(deviceHeading))
                        .font(VF.Typeface.label(12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(width: 262, height: 262)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(guidance(delta: delta, aligned: aligned))

            Text(guidance(delta: delta, aligned: aligned))
                .font(VF.Typeface.body(15))
                .foregroundStyle(aligned ? VF.Palette.amber : Color.white)
                .multilineTextAlignment(.center)

            if isSimulated {
                VStack(spacing: 4) {
                    Slider(value: $simulatedHeading, in: 0...359, step: 1)
                        .tint(VF.Palette.amber)
                    Text("나침반이 없는 기기예요 · 슬라이더로 방향을 돌려보세요")
                        .font(VF.Typeface.mono(10))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: aligned) { _, isAligned in
            if isAligned && !wasAligned { Haptics.success() }
            wasAligned = isAligned
        }
    }

    private func guidance(delta: Double, aligned: Bool) -> String {
        let amount = Int(abs(delta).rounded())
        if walkBearing != nil {
            if aligned { return "이 방향으로 걸어가세요" }
            return delta > 0 ? "오른쪽으로 \(amount)° 돌아서 걸어가세요" : "왼쪽으로 \(amount)° 돌아서 걸어가세요"
        }
        if aligned { return "구도 방향이 맞았어요 · 셔터를 누르세요" }
        return delta > 0 ? "카메라를 오른쪽으로 \(amount)° 돌리세요" : "카메라를 왼쪽으로 \(amount)° 돌리세요"
    }
}

/// 5° 눈금 + 방위 글자
struct CompassDial: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
            ForEach(0..<72, id: \.self) { index in
                let major = index % 6 == 0
                Rectangle()
                    .fill(Color.white.opacity(major ? 0.8 : 0.3))
                    .frame(width: major ? 2 : 1, height: major ? 12 : 6)
                    .offset(y: -124)
                    .rotationEffect(.degrees(Double(index) * 5))
            }
            ForEach([0, 90, 180, 270], id: \.self) { degrees in
                Text(verbatim: label(degrees))
                    .font(VF.Typeface.mono(13, weight: .semibold))
                    .foregroundStyle(degrees == 0 ? VF.Palette.amber : Color.white)
                    .offset(y: -102)
                    .rotationEffect(.degrees(Double(degrees)))
            }
        }
        .frame(width: 262, height: 262)
    }

    private func label(_ degrees: Int) -> String {
        switch degrees {
        case 0: return "N"
        case 90: return "E"
        case 180: return "S"
        default: return "W"
        }
    }
}
