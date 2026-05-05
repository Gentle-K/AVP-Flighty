import SwiftUI

enum DTColors {
    static let appleBlue = Color(red: 0.19, green: 0.48, blue: 0.92)
    static let glassStroke = Color.white.opacity(0.24)
    static let glassFill = Color(red: 0.08, green: 0.16, blue: 0.23).opacity(0.42)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let faintText = Color.white.opacity(0.44)

    static func status(_ severity: AirspaceAlert.Severity) -> Color {
        switch severity {
        case .critical: .red
        case .warning: .yellow
        case .advisory: .purple
        case .info: .blue
        }
    }

    static func runway(_ status: Runway.Status) -> Color {
        switch status {
        case .active: .green
        case .standby: .yellow
        case .closed: .red
        }
    }
}

struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background {
                if reduceTransparency || contrast == .increased {
                    shape.fill(Color(red: 0.06, green: 0.11, blue: 0.16).opacity(0.88))
                } else {
                    shape.fill(DTColors.glassFill)
                }
            }
            .overlay {
                shape.stroke(DTColors.glassStroke, lineWidth: 1)
            }
            .clipShape(shape)
            .glassBackgroundEffect(in: shape)
            .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 18)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 30, padding: CGFloat = 18) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, padding: padding))
    }

    func monoMetric() -> some View {
        monospacedDigit()
            .fontDesign(.rounded)
    }
}

struct PillButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? DTColors.appleBlue.opacity(configuration.isPressed ? 0.78 : 0.92) : Color.white.opacity(configuration.isPressed ? 0.18 : 0.08))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.28 : 0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MetricBlock: View {
    let title: String
    let value: String
    let caption: String?
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DTColors.faintText)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .monoMetric()
                .foregroundStyle(color)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }
}
