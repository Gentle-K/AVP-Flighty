import SwiftUI

struct SettingsPanel: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 18) {
            settingsList
            layoutPreview
            detailPanel
        }
        .glassSurface(cornerRadius: 36, padding: 24)
    }

    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold))
                Spacer()
                Button {
                    model.isSettingsPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PillButtonStyle(isSelected: false))
                .accessibilityLabel("Close settings")
            }

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    model.selectedSettingsCategory = category
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 22))
                            .frame(width: 30)
                            .foregroundStyle(DTColors.secondaryText)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(subtitle(for: category))
                                .font(.caption)
                                .foregroundStyle(DTColors.secondaryText)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 10)
                    .background(
                        model.selectedSettingsCategory == category ? Color.white.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selectedSettingsCategory == category ? .isSelected : [])
            }
        }
        .frame(width: 270)
    }

    private var layoutPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Workspace Layout")
                .font(.system(size: 20, weight: .semibold))
            Text("Panels keep the sky, routes, and runway context unobstructed. Reset restores the default TestFlight layout.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
            Spacer()
            ZStack {
                PerspectiveGrid()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                HStack(spacing: 18) {
                    previewPanel(width: 76, height: 132)
                        .rotation3DEffect(.degrees(14), axis: (x: 0, y: 1, z: 0))
                    previewPanel(width: 190, height: 118)
                    previewPanel(width: 86, height: 142)
                        .rotation3DEffect(.degrees(-14), axis: (x: 0, y: 1, z: 0))
                }
            }
            .frame(height: 190)
            Spacer()
            Button {
                model.resetLayout()
            } label: {
                Label("Reset Layout", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PillButtonStyle(isSelected: false))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundStyle(.white)
        .frame(width: 300)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.selectedSettingsCategory.title)
                .font(.system(size: 20, weight: .semibold))

            switch model.selectedSettingsCategory {
            case .account:
                detailText("TestFlight account features are evaluated through Apple TestFlight. Subscription UI is intentionally disabled for this build.")
            case .dataSources:
                DataSourceDetail()
            case .display:
                detailText("Active overlays: \(model.overlays.map(\.title).sorted().joined(separator: ", ")). Weather layers: \(model.selectedWeatherLayers.map(\.title).sorted().joined(separator: ", ")).")
            case .spatialLayout:
                detailText("Immersive status: \(model.isImmersiveOpen ? "Open" : "Closed"). Enter immersive space explicitly from the top command bar.")
            case .notifications:
                detailText("Notifications are not enabled in v1 TestFlight. Alerts remain in-app discovery items only.")
            case .accessibility:
                detailText("Reduce Motion and Reduce Transparency are respected by core controls and glass surfaces.")
            case .privacy:
                PrivacyDetail()
            }

            Spacer()
        }
        .foregroundStyle(.white)
        .frame(width: 250)
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(DTColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitle(for category: SettingsCategory) -> String {
        switch category {
        case .account: "TestFlight identity"
        case .dataSources: "Backend and freshness"
        case .display: "Units, labels, overlays"
        case .spatialLayout: "Window behavior in space"
        case .notifications: "In-app alert behavior"
        case .accessibility: "Motion, contrast, focus"
        case .privacy: "Data usage and policy"
        }
    }

    private func previewPanel(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .frame(width: width, height: height)
    }
}

private struct DataSourceDetail: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow("Status", model.connectionStatusTitle)
            statusRow("Airport", model.selectedAirport.icao)
            statusRow("Source", model.currentSnapshot?.freshness.sourceName ?? "Not connected")
            statusRow("Data Time", model.dataTimestampText)
            Text(model.releaseReview.summary)
                .font(.caption2)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DTColors.secondaryText)
            Spacer()
            Text(value)
                .monoMetric()
        }
        .font(.caption)
    }
}

private struct PrivacyDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This build does not request location, camera, microphone, sensor, or background permissions. Aviation provider credentials remain on the backend; the app only uses the configured backend bearer token.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("A privacy policy URL and support URL must be supplied in App Store Connect before wider distribution.")
                .font(.caption2)
                .foregroundStyle(DTColors.faintText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PerspectiveGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let vanishing = CGPoint(x: rect.midX, y: rect.minY + 18)

        for index in 0...8 {
            let x = rect.minX + rect.width * CGFloat(index) / 8
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: vanishing)
        }

        for index in 0...5 {
            let y = rect.maxY - rect.height * CGFloat(index) / 5
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}
