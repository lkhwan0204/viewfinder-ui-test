import UIKit

enum Haptics {
    /// 셔터처럼 짧고 단단한 두 번의 진동 (찰-칵)
    static func shutter() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
    }

    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
