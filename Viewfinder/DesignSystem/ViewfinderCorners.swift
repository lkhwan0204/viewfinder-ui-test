import SwiftUI

/// 뷰파인더 코너 마크 (⌐ ¬). 선택, 포커스, 로딩 상태에 반복해서 쓰는 Viewfinder의 시각 언어입니다.
struct ViewfinderCorners: Shape {
    var length: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let l = min(length, rect.width / 2, rect.height / 2)
        var p = Path()
        // 왼쪽 위
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // 오른쪽 위
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // 오른쪽 아래
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // 왼쪽 아래
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

extension View {
    /// 뷰 바깥쪽에 코너 마크를 그립니다.
    func viewfinderCorners(_ color: Color = Color.white.opacity(0.85), length: CGFloat = 14, lineWidth: CGFloat = 1.5, outset: CGFloat = 6) -> some View {
        overlay(
            ViewfinderCorners(length: length)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                .padding(-outset)
                .allowsHitTesting(false)
        )
    }

    /// 선택되면 초점이 맞듯 코너가 조여 들어옵니다.
    func focusLock(_ active: Bool, color: Color = VF.Palette.amber) -> some View {
        modifier(FocusLockModifier(active: active, color: color))
    }
}

private struct FocusLockModifier: ViewModifier {
    let active: Bool
    let color: Color

    func body(content: Content) -> some View {
        content.overlay(
            ViewfinderCorners(length: 12)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                .padding(active ? -3 : -12)
                .opacity(active ? 1 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: active)
                .allowsHitTesting(false)
        )
    }
}
