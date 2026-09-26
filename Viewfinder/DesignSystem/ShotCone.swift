import SwiftUI

/// 시야 부채꼴. 북쪽(위)을 향한 부채꼴을 그리고, 사용하는 쪽에서 방위만큼 회전시킵니다.
struct ShotCone: Shape {
    /// 수평 화각 (도)
    var fov: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let steps = 18
        var p = Path()
        p.move(to: center)
        for i in 0...steps {
            let degrees = -fov / 2 + fov * Double(i) / Double(steps)
            let angle = degrees * .pi / 180
            p.addLine(to: CGPoint(
                x: center.x + radius * CGFloat(sin(angle)),
                y: center.y - radius * CGFloat(cos(angle))
            ))
        }
        p.closeSubpath()
        return p
    }
}

/// 촬영 방향 부채꼴 (Shot Cone). 지도 마커, 촬영 카드, 빛 타임라인에서 공통으로 씁니다.
struct ShotConeGlyph: View {
    let fov: Double
    let heading: Double
    var size: CGFloat = 96
    var color: Color = VF.Palette.amber

    var body: some View {
        ShotCone(fov: fov)
            .fill(RadialGradient(
                colors: [color.opacity(0.6), color.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: size / 2
            ))
            .overlay(ShotCone(fov: fov).stroke(color.opacity(0.35), lineWidth: 0.5))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(heading))
            .allowsHitTesting(false)
    }
}
