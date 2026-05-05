import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DigitalTowerModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AirspaceSceneView()
                .ignoresSafeArea()

            VStack {
                TopCommandBar()
                    .frame(maxWidth: 760)
                    .padding(.top, 26)
                Spacer()
            }

            HStack(alignment: .center) {
                SideRail()
                    .padding(.leading, 28)
                Spacer()
                RightInspectorView()
                    .frame(width: 354)
                    .padding(.trailing, 28)
            }

            VStack {
                Spacer()
                BottomControlDock()
                    .frame(maxWidth: model.mode == .replay ? 1_060 : 700)
                    .padding(.bottom, 28)
            }

            if model.isSettingsPresented {
                SettingsPanel()
                    .frame(width: 880)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if model.isSafetyNoticePresented {
                SafetyNoticePanel()
                    .frame(width: 620)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            model.start()
        }
        .onChange(of: model.immersiveCommand) { _, command in
            Task {
                await handleImmersiveCommand(command)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: model.mode)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: model.isSettingsPresented)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: model.isSafetyNoticePresented)
    }

    private func handleImmersiveCommand(_ command: DigitalTowerModel.ImmersiveCommand) async {
        switch command {
        case .none:
            return
        case .open:
            switch await openImmersiveSpace(id: DigitalTowerModel.immersiveSpaceID) {
            case .opened:
                model.markImmersiveOpened(true)
            default:
                model.markImmersiveOpened(false)
            }
        case .dismiss:
            await dismissImmersiveSpace()
            model.markImmersiveOpened(false)
        }
        model.completeImmersiveCommand()
    }
}

private struct SafetyNoticePanel: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discovery Use Only")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Digital Tower is not a navigation, ATC, dispatch, flight safety, or operational decision tool.")
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }
            }

            Text("Use authorized data in this app for spatial exploration and awareness during TestFlight evaluation. Always rely on certified aviation systems and official procedures for operational decisions.")
                .font(.system(size: 15))
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button {
                    model.isSafetyNoticePresented = false
                } label: {
                    Label("Review Later", systemImage: "clock")
                }
                .buttonStyle(PillButtonStyle(isSelected: false))

                Spacer()

                Button {
                    model.acceptSafetyNotice()
                } label: {
                    Label("I Understand", systemImage: "checkmark")
                }
                .buttonStyle(PillButtonStyle(isSelected: true))
            }
        }
        .foregroundStyle(.white)
        .glassSurface(cornerRadius: 32, padding: 24)
        .accessibilityElement(children: .contain)
    }
}
