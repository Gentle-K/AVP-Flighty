import SwiftUI

struct BottomControlDock: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        Group {
            switch model.mode {
            case .replay:
                ReplayTimelineDock()
            case .tower:
                TowerControlDock()
            case .weather:
                WeatherLayerDock()
            default:
                CoreModeDock()
            }
        }
        .glassSurface(cornerRadius: 30, padding: 12)
    }
}

private struct CoreModeDock: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach([AirspaceMode.live, .tower, .flight, .weather, .alerts, .replay]) { mode in
                Button {
                    model.setMode(mode)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 24, weight: .medium))
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(width: 88, height: 78)
                }
                .buttonStyle(TileButtonStyle(isSelected: model.mode == mode))
            }
        }
    }
}

private struct TowerControlDock: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Viewpoints".uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DTColors.faintText)
                HStack(spacing: 8) {
                    ForEach(TowerViewpoint.allCases) { viewpoint in
                        Button(viewpoint.title) {
                            model.setTowerViewpoint(viewpoint)
                        }
                        .buttonStyle(PillButtonStyle(isSelected: model.selectedTowerViewpoint == viewpoint))
                    }
                }
            }

            Divider()
                .frame(height: 70)
                .overlay(Color.white.opacity(0.18))

            overlayButtons([.traffic, .runways, .weather, .labels])
        }
    }

    private func overlayButtons(_ overlays: [AirspaceOverlay]) -> some View {
        HStack(spacing: 10) {
            ForEach(overlays) { overlay in
                OverlayButton(overlay: overlay, isSelected: model.overlays.contains(overlay)) {
                    model.toggleOverlay(overlay)
                }
            }
        }
    }
}

private struct WeatherLayerDock: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(WeatherLayer.allCases) { layer in
                Button {
                    model.toggleWeatherLayer(layer)
                } label: {
                    Label(layer.title, systemImage: layer.symbol)
                }
                .buttonStyle(PillButtonStyle(isSelected: model.selectedWeatherLayers.contains(layer)))
                .accessibilityValue(model.selectedWeatherLayers.contains(layer) ? "Selected" : "")
            }
        }
    }
}

private struct ReplayTimelineDock: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 24) {
            Button {
                model.toggleReplayPlayback()
            } label: {
                Image(systemName: model.isReplayPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(TileButtonStyle(isSelected: model.isReplayPlaying))
            .accessibilityLabel(model.isReplayPlaying ? "Pause replay" : "Play replay")

            VStack(spacing: 12) {
                HStack {
                    Text("10:32:48 AM")
                    Spacer()
                    Text("12:00:00 PM")
                }
                .font(.caption)
                .monoMetric()
                .foregroundStyle(DTColors.secondaryText)

                Slider(value: $model.replayProgress, in: 0...1)

                HStack(spacing: 13) {
                    ForEach(model.replayEvents) { event in
                        Circle()
                            .fill(color(for: event.kind))
                            .frame(width: 10, height: 10)
                            .accessibilityLabel(event.label)
                    }
                }
            }

            Button("15s") {
                model.jumpReplay(by: -0.08)
            }
                .buttonStyle(PillButtonStyle(isSelected: false))
                .accessibilityLabel("Jump replay back 15 seconds")
            Button(model.playbackSpeed) {
                model.cyclePlaybackSpeed()
            }
            .buttonStyle(PillButtonStyle(isSelected: true))
            Button {
                model.setMode(.alerts)
            } label: {
                Label("Events", systemImage: "calendar")
            }
            .buttonStyle(PillButtonStyle(isSelected: false))
        }
    }

    private func color(for kind: ReplayEvent.Kind) -> Color {
        switch kind {
        case .arrival: .green
        case .departure: .blue
        case .overflight: .purple
        case .alert: .orange
        }
    }
}

private struct OverlayButton: View {
    let overlay: AirspaceOverlay
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: overlay.symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(overlay.title)
                    .font(.caption2.weight(.medium))
            }
            .frame(width: 72, height: 66)
        }
        .buttonStyle(TileButtonStyle(isSelected: isSelected))
    }
}

struct TileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? DTColors.appleBlue.opacity(configuration.isPressed ? 0.72 : 0.92) : Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.28 : 0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
