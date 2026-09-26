import SwiftUI

/// 하루 동안의 하늘빛을 태양 고도로 계산해 한 줄 그라데이션으로 보여줍니다.
/// 밤(남색) → 블루아워(파랑) → 골든아워(앰버) → 낮(하늘색)
struct SkyBand: View {
    let coordinate: GeoPoint
    let date: Date
    var marker: Date? = nil

    var body: some View {
        let start = Calendar.kst.startOfDay(for: date)
        let stops: [Gradient.Stop] = (0...48).map { index in
            let moment = start.addingTimeInterval(Double(index) * 1800)
            let altitude = SunCalculator.position(at: moment, coordinate: coordinate).altitude
            return Gradient.Stop(color: SkyBand.color(forAltitude: altitude), location: CGFloat(index) / 48)
        }
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
                ForEach([6, 12, 18], id: \.self) { hour in
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 0.5)
                        .offset(x: geo.size.width * CGFloat(hour) / 24)
                }
                if let marker {
                    let x = geo.size.width * CGFloat(min(max(marker.timeIntervalSince(start) / 86_400, 0), 1))
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: x - 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .accessibilityHidden(true)
    }

    static func color(forAltitude altitude: Double) -> Color {
        switch altitude {
        case ..<(-18): return Color(hex: 0x05070D)
        case ..<(-6): return Color(hex: 0x111B38)
        case ..<(-4): return Color(hex: 0x2B4C8C)
        case ..<6: return Color(hex: 0xF2A93B)
        case ..<20: return Color(hex: 0xE9CFA0)
        default: return Color(hex: 0x9CC3E6)
        }
    }
}
