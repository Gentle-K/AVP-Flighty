import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DigitalTowerModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if model.isImmersiveOpen {
                Color.clear
                    .ignoresSafeArea()
            } else {
                LauncherBackdrop()
            }

            Group {
                if model.isImmersiveOpen {
                    CompactImmersiveCompanion()
                        .padding(18)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            LauncherHeader()
                            LauncherPrimaryAction()
                            ExperienceModeGrid()
                            AirportAndFlightPicker()
                            ComfortSettingsStrip()
                            DiscoveryNotice()
                        }
                        .padding(26)
                    }
                }
            }

            if model.isSafetyNoticePresented {
                SafetyNoticePanel()
                    .frame(width: 560)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .frame(
            minWidth: model.isImmersiveOpen ? 280 : 520,
            idealWidth: model.isImmersiveOpen ? 300 : 620,
            minHeight: model.isImmersiveOpen ? 96 : 520,
            idealHeight: model.isImmersiveOpen ? 132 : 720
        )
        .preferredColorScheme(.dark)
        .task {
            model.start()
            if model.hasAcceptedSafetyNotice {
                model.requestOpenImmersive()
            }
        }
        .onChange(of: model.hasAcceptedSafetyNotice) { _, accepted in
            if accepted {
                model.requestOpenImmersive()
            }
        }
        .onChange(of: model.immersiveCommand) { _, command in
            Task {
                await handleImmersiveCommand(command)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: model.experienceMode)
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

private struct CompactImmersiveCompanion: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "visionpro.fill")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.experienceMode.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(model.selectedAirport.iata) - \(model.flights.count) aircraft")
                        .font(.caption2)
                        .foregroundStyle(DTColors.secondaryText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach([ExperienceMode.skyPortal, .digitalTower, .nearbySky, .flightChase, .globe, .replay]) { mode in
                    Button {
                        model.setExperienceMode(mode)
                    } label: {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(TileButtonStyle(isSelected: model.experienceMode == mode))
                    .help(mode.title)
                }
            }

            HStack {
                Button {
                    model.requestDismissImmersive()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PillButtonStyle(isSelected: false))
                .accessibilityLabel("Close immersive space")

                Spacer()

                Text("Discovery only")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DTColors.faintText)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 260)
        .glassSurface(cornerRadius: 20, padding: 10)
    }
}

private struct LauncherBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.015, green: 0.035, blue: 0.06),
                Color(red: 0.04, green: 0.11, blue: 0.16),
                Color(red: 0.09, green: 0.13, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.cyan.opacity(0.12))
                .blur(radius: 38)
                .frame(width: 240, height: 240)
                .offset(x: 70, y: -70)
        }
    }
}

private struct LauncherHeader: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "visionpro")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Digital Tower")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                Text("A full immersive airspace launcher. Keep this window small; the real product is the space around you.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text(model.selectedAirport.iata)
                    .font(.system(size: 30, weight: .semibold))
                    .monoMetric()
                Text(model.connectionStatusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .foregroundStyle(.white)
        }
    }

    private var statusColor: Color {
        switch model.connectionStatusTitle {
        case "Authorized":
            return .green
        case "Loading":
            return .yellow
        case "Debug Sample":
            return .orange
        default:
            return .red
        }
    }
}

private struct LauncherPrimaryAction: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.experienceMode.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(model.experienceMode.subtitle)
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }

                Spacer()

                Button {
                    model.requestToggleImmersive()
                } label: {
                    Label(model.isImmersiveOpen ? "Close Space" : "Enter Full Space", systemImage: model.isImmersiveOpen ? "xmark" : "visionpro.fill")
                }
                .buttonStyle(PillButtonStyle(isSelected: !model.isImmersiveOpen))
            }

            HStack(spacing: 12) {
                MetricBlock(title: "Aircraft", value: "\(model.flights.count)", caption: "mock/live tracks", color: .cyan)
                MetricBlock(title: "Mode", value: model.sceneScalePreset.title, caption: "scene scale", color: .white)
                MetricBlock(title: "Labels", value: model.labelDensity.title, caption: "sky text policy", color: .green)
            }
        }
        .glassSurface(cornerRadius: 24, padding: 18)
    }
}

private struct ExperienceModeGrid: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experience")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ExperienceMode.allCases) { mode in
                    Button {
                        model.setExperienceMode(mode)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(mode.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(DTColors.faintText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 58)
                    }
                    .buttonStyle(RailButtonStyle(isSelected: model.experienceMode == mode))
                }
            }
        }
        .glassSurface(cornerRadius: 24, padding: 16)
    }
}

private struct AirportAndFlightPicker: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Airport")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(model.availableAirports) { airport in
                        Button("\(airport.iata) - \(airport.name)") {
                            model.loadAirport(airport)
                        }
                    }
                } label: {
                    Label("\(model.selectedAirport.iata) / \(model.selectedAirport.icao)", systemImage: "chevron.down")
                }
                .buttonStyle(PillButtonStyle(isSelected: false))
            }

            if let selectedFlight = model.selectedFlight {
                Button {
                    model.setExperienceMode(.flightChase)
                } label: {
                    HStack {
                        Image(systemName: "airplane")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedFlight.callsign)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(selectedFlight.origin) to \(selectedFlight.destination) - \(selectedFlight.aircraft)")
                                .font(.caption)
                                .foregroundStyle(DTColors.secondaryText)
                        }
                        Spacer()
                        Text("\(selectedFlight.altitudeFeet.formatted()) ft")
                            .font(.caption.weight(.semibold))
                            .monoMetric()
                    }
                }
                .buttonStyle(RailButtonStyle(isSelected: model.experienceMode == .flightChase))
            } else {
                Text("Tap any aircraft in the immersive space to start Flight Chase.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
            }
        }
        .foregroundStyle(.white)
        .glassSurface(cornerRadius: 24, padding: 16)
    }
}

private struct ComfortSettingsStrip: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Comfort")
                .font(.headline)
                .foregroundStyle(.white)

            settingRow("Aircraft density") {
                Picker("Aircraft density", selection: $model.aircraftDensity) {
                    ForEach(AircraftDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingRow("Label density") {
                Picker("Label density", selection: $model.labelDensity) {
                    ForEach(LabelDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trail length")
                    Spacer()
                    Text("\(Int(model.trailLength * 100))%")
                        .monoMetric()
                        .foregroundStyle(DTColors.secondaryText)
                }
                Slider(value: $model.trailLength, in: 0.2...1)
            }

            Toggle("Sound", isOn: $model.isSoundEnabled)
            .toggleStyle(.button)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .glassSurface(cornerRadius: 24, padding: 16)
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(DTColors.secondaryText)
            content()
        }
    }
}

private struct DiscoveryNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.yellow)
            Text("Discovery use only. Digital Tower is not a navigation, ATC, dispatch, flight safety, or operational decision tool.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
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
                    Text("This app is for aviation discovery, not operational control.")
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }
            }

            Text("Do not use Digital Tower for navigation, ATC, dispatch, flight safety, or operational decisions. The immersive scene may use mock data unless an authorized backend is configured.")
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
        .glassSurface(cornerRadius: 28, padding: 22)
        .accessibilityElement(children: .contain)
    }
}
