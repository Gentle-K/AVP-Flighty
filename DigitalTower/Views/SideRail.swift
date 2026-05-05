import SwiftUI

struct SideRail: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.columns")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(height: 60)

            DividerLine()
                .padding(.vertical, 8)

            ForEach(AirspaceMode.allCases) { mode in
                Button {
                    model.setMode(mode)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(mode.subtitle)
                                .font(.caption2)
                                .foregroundStyle(DTColors.faintText)
                        }
                        Spacer()
                        if mode == .alerts {
                            Text("\(model.alerts.count)")
                                .font(.caption.weight(.bold))
                                .monoMetric()
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.18), in: Circle())
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 206, alignment: .leading)
                }
                .buttonStyle(RailButtonStyle(isSelected: model.mode == mode))
                .accessibilityLabel(mode.title)
                .accessibilityValue(model.mode == mode ? "Selected" : "")
            }
        }
        .glassSurface(cornerRadius: 34, padding: 14)
    }
}

struct RailButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(configuration.isPressed ? 0.09 : 0.001))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : .clear, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
