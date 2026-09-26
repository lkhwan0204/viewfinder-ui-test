import SwiftUI

@main
struct ViewfinderApp: App {
    @State private var model = AppModel()
    @State private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(location)
                .preferredColorScheme(model.appearance.colorScheme)
                .tint(VF.Palette.amber)
        }
    }
}
