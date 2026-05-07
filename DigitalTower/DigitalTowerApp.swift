import SwiftUI

@main
struct DigitalTowerApp: App {
    @StateObject private var model = DigitalTowerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 620, height: 720)
        .windowResizability(.contentSize)
        .windowStyle(.plain)

        ImmersiveSpace(id: DigitalTowerModel.immersiveSpaceID) {
            ImmersiveAirspaceView()
                .environmentObject(model)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
