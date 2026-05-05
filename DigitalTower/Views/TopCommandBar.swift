import SwiftUI

struct TopCommandBar: View {
    @EnvironmentObject private var model: DigitalTowerModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DTColors.secondaryText)

                TextField("Search flights, airports, callsigns...", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onChange(of: isSearchFocused) { _, newValue in
                        model.isSearchFocused = newValue
                    }

                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DTColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                Spacer(minLength: 12)

                statusBadge

                Text(model.dataTimestampText)
                    .font(.system(size: 14, weight: .medium))
                    .monoMetric()
                    .foregroundStyle(DTColors.secondaryText)
                    .accessibilityLabel("Data time \(model.dataTimestampText)")

                Divider()
                    .frame(height: 20)
                    .overlay(Color.white.opacity(0.24))

                airportMenu

                Button {
                    model.requestToggleImmersive()
                } label: {
                    Image(systemName: model.isImmersiveOpen ? "visionpro.fill" : "visionpro")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PillButtonStyle(isSelected: model.isImmersiveOpen))
                .accessibilityLabel(model.isImmersiveOpen ? "Close immersive airspace" : "Open immersive airspace")

                Button {
                    model.isSettingsPresented.toggle()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PillButtonStyle(isSelected: model.isSettingsPresented))
                .accessibilityLabel("More settings")
            }
            .glassSurface(cornerRadius: 28, padding: 10)

            if isSearchFocused || !model.searchText.isEmpty {
                searchResults
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var airportMenu: some View {
        Menu {
            ForEach(model.availableAirports) { airport in
                Button("\(airport.iata) - \(airport.name)") {
                    model.loadAirport(airport)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.selectedAirport.iata)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
        }
        .accessibilityLabel("Selected airport \(model.selectedAirport.iata)")
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(model.connectionStatusTitle)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .accessibilityLabel("Data status \(model.connectionStatusTitle)")
    }

    private var statusColor: Color {
        switch model.connectionStatusTitle {
        case "Authorized":
            return .green
        case "Loading":
            return .yellow
        case "Stale", "Debug Sample":
            return .orange
        default:
            return .red
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type a callsign, airport, city, or aircraft type.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else if model.searchResults.isEmpty {
                Text("No matching flights or airports.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.searchResults) { result in
                    Button {
                        model.selectSearchResult(result)
                        isSearchFocused = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: result.symbol)
                                .frame(width: 24)
                                .foregroundStyle(DTColors.secondaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(result.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(DTColors.secondaryText)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 760)
        .glassSurface(cornerRadius: 22, padding: 8)
    }
}
