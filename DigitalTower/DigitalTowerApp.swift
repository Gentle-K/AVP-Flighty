import SwiftUI

@main
struct DigitalTowerApp: App {
    @StateObject private var model = DigitalTowerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1_672, height: 941)

        ImmersiveSpace(id: DigitalTowerModel.immersiveSpaceID) {
            ImmersiveAirspaceView()
                .environmentObject(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .progressive, .full)
    }
}
