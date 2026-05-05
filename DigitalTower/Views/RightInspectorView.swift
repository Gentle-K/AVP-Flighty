import SwiftUI

struct RightInspectorView: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            DataStatusBanner()
            DividerLine()

            ScrollView(showsIndicators: false) {
                switch model.mode {
                case .live:
                    LiveInspector()
                case .tower:
                    TowerInspector()
                case .flight:
                    FlightInspector()
                case .weather:
                    WeatherInspector()
                case .replay:
                    ReplayInspector()
                case .alerts:
                    AlertsInspector()
                }
            }
        }
        .glassSurface(cornerRadius: 34, padding: 22)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.agentPlan.headline)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(model.selectedAirport.city + ", " + model.selectedAirport.country)
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }
                Spacer()
                Text(model.selectedAirport.iata)
                    .font(.system(size: 34, weight: .semibold))
                    .monoMetric()
                    .foregroundStyle(.white)
            }

            Text(model.agentPlan.summary)
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DataStatusBanner: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        if let message = model.dataState.userMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: model.dataState.isLoading ? "arrow.clockwise" : "exclamationmark.triangle")
                    .foregroundStyle(model.dataState.isLoading ? .yellow : .orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct LiveInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Airspace Insights")
            HStack(spacing: 16) {
                MetricBlock(title: "In View", value: "\(model.metrics.visibleFlights)", caption: "Visible flights")
                MetricBlock(title: "Congestion", value: model.metrics.congestionLabel, caption: "\(Int(model.metrics.congestionValue * 100))% density", color: congestionColor)
            }
            congestionScale
            routeList(title: "Inbound Flow", flights: model.flights.filter { $0.destination == model.selectedAirport.iata })
            routeList(title: "Outbound Flow", flights: model.flights.filter { $0.origin == model.selectedAirport.iata })
        }
    }

    private var congestionColor: Color {
        model.metrics.congestionValue > 0.72 ? .red : model.metrics.congestionValue > 0.35 ? .yellow : .green
    }

    private var congestionScale: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Congestion")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DTColors.secondaryText)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(.linearGradient(colors: [.green, .yellow, .red, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * model.metrics.congestionValue)
                }
            }
            .frame(height: 7)
            HStack {
                Text("Light")
                Spacer()
                Text("Moderate")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundStyle(DTColors.faintText)
        }
    }

    private func routeList(title: String, flights: [FlightTrack]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            if flights.isEmpty {
                Text("No tracks in this group.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
            } else {
                ForEach(flights.prefix(4)) { flight in
                    HStack {
                        Image(systemName: "airplane")
                            .font(.caption)
                            .foregroundStyle(DTColors.secondaryText)
                        Text(flight.callsign)
                        Spacer()
                        Text("\(flight.altitudeFeet.formatted()) ft")
                            .monoMetric()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct TowerInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Runway Context")
            Text("Viewpoint: \(model.selectedTowerViewpoint.title)")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
            ForEach(model.selectedAirport.runways) { runway in
                HStack {
                    Text(runway.id)
                        .font(.system(size: 14, weight: .semibold))
                    Text(runway.usage)
                        .foregroundStyle(DTColors.secondaryText)
                    Spacer()
                    Text(runway.status.rawValue)
                        .foregroundStyle(DTColors.runway(runway.status))
                    Text(runway.condition)
                        .foregroundStyle(DTColors.faintText)
                }
                .font(.caption)
            }
            DividerLine()
            flightFlow(title: "Outbound Flow", flights: model.flights.filter { $0.origin == model.selectedAirport.iata })
            flightFlow(title: "Inbound Flow", flights: model.flights.filter { $0.destination == model.selectedAirport.iata })
        }
    }

    private func flightFlow(title: String, flights: [FlightTrack]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(title)
            if flights.isEmpty {
                Text("No tracks currently visible.")
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
            } else {
                ForEach(flights.prefix(5)) { flight in
                    HStack {
                        Text(flight.callsign).frame(width: 76, alignment: .leading)
                        Text(flight.aircraft).foregroundStyle(DTColors.secondaryText)
                        Spacer()
                        Text(flight.phase.rawValue)
                            .foregroundStyle(DTColors.secondaryText)
                    }
                    .font(.caption)
                    .monoMetric()
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct FlightInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel
    @State private var tab = "Overview"
    private let tabs = ["Overview", "Timeline", "Aircraft", "History"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { item in
                    Button(item) {
                        tab = item
                    }
                    .buttonStyle(PillButtonStyle(isSelected: tab == item))
                }
            }

            if let flight = model.selectedFlight {
                switch tab {
                case "Timeline":
                    timeline(for: flight)
                case "Aircraft":
                    aircraft(for: flight)
                case "History":
                    history(for: flight)
                default:
                    overview(for: flight)
                }
            } else {
                EmptyInspectorState(symbol: "airplane.circle", title: "No Flight Selected", message: "Select an aircraft in the scene or search results.")
            }
        }
    }

    private func overview(for flight: FlightTrack) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text(flight.origin)
                        .font(.system(size: 30, weight: .semibold))
                    Text("Origin")
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }
                Image(systemName: "arrow.right")
                    .foregroundStyle(DTColors.secondaryText)
                VStack(alignment: .leading) {
                    Text(flight.destination)
                        .font(.system(size: 30, weight: .semibold))
                    Text("Destination")
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                }
            }
            .foregroundStyle(.white)

            detailRow("Ground Speed", "\(flight.speedKnots) kt")
            detailRow("Altitude", "\(flight.altitudeFeet.formatted()) ft")
            detailRow("Heading", "\(flight.headingDegrees) degrees")
            detailRow("Vertical Rate", "\(flight.verticalRateFeet) ft/min")

            DividerLine()
            sectionTitle("Insight")
            Text(model.agentPlan.reports.first { $0.id == "flight-insight" }?.output ?? "Select an aircraft for insight.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func timeline(for flight: FlightTrack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Flight Progress")
            progressRow("Route progress", value: flight.progress, color: .green)
            detailRow("Current phase", flight.phase.rawValue)
            detailRow("Last update", flight.updatedAt?.formatted(date: .omitted, time: .standard) ?? "Unknown")
        }
    }

    private func aircraft(for flight: FlightTrack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Aircraft")
            detailRow("Type", flight.aircraft)
            detailRow("Registration", flight.registration)
            detailRow("Category", flight.category.rawValue)
            detailRow("Provider ID", flight.id)
        }
    }

    private func history(for flight: FlightTrack) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Data History")
            Text("Historical tracks are loaded from the authorized backend when available. This TestFlight build does not infer operational history from unavailable data.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            detailRow("Source", model.currentSnapshot?.freshness.sourceName ?? "Unknown")
            detailRow("Data time", model.dataTimestampText)
            detailRow("Callsign", flight.callsign)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DTColors.secondaryText)
            Spacer()
            Text(value)
                .monoMetric()
                .foregroundStyle(.white)
        }
        .font(.system(size: 14, weight: .medium))
    }

    private func progressRow(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%")
            }
            .font(.caption)
            .monoMetric()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(color).frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 5)
        }
        .foregroundStyle(.white)
    }
}

private struct WeatherInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let weather = model.weather {
                HStack {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 32))
                    VStack(alignment: .leading) {
                        Text("\(weather.temperature) degrees F")
                            .font(.system(size: 28, weight: .semibold))
                            .monoMetric()
                        Text(weather.condition)
                            .font(.caption)
                            .foregroundStyle(DTColors.secondaryText)
                    }
                    Spacer()
                    Text(weather.delayRisk)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(delayColor(weather.delayRiskValue))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(delayColor(weather.delayRiskValue).opacity(0.14), in: Capsule())
                }
                .foregroundStyle(.white)

                detail("Wind", "\(weather.windDirection) degrees \(weather.windSpeed) kt")
                detail("Visibility", "\(weather.visibilityMiles) sm")
                detail("Ceiling", "\(weather.ceilingFeet.formatted()) ft")
                DividerLine()
                MetricBlock(title: "Runway Context", value: weather.runwayContext, caption: "Context only, not operational guidance", color: .green)
                MetricBlock(title: "Delay Risk", value: weather.delayRisk, caption: "\(Int(weather.delayRiskValue * 100))% route weather impact", color: delayColor(weather.delayRiskValue))
            } else {
                EmptyInspectorState(symbol: "cloud.slash", title: "Weather Loading", message: "Weather context will appear when the authorized source responds.")
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DTColors.secondaryText)
            Spacer()
            Text(value)
                .monoMetric()
                .foregroundStyle(.white)
        }
        .font(.system(size: 15, weight: .medium))
    }

    private func delayColor(_ value: Double) -> Color {
        value > 0.65 ? .red : value > 0.3 ? .yellow : .green
    }
}

private struct ReplayInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                MetricBlock(title: "Visible Flights", value: "\(model.flights.count)", caption: "Current data window")
                MetricBlock(title: "Progress", value: "\(Int(model.replayProgress * 100))%", caption: model.isReplayPlaying ? "Playing" : "Paused")
            }
            MetricBlock(title: "High Priority Alerts", value: "\(model.metrics.highPriorityAlerts)", caption: "Critical and warning", color: .yellow)
            DividerLine()
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Replay Events")
                if model.replayEvents.isEmpty {
                    Text("No replay events are available from the current source.")
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                } else {
                    ForEach(model.replayEvents) { event in
                        HStack {
                            Circle()
                                .fill(color(for: event.kind))
                                .frame(width: 8, height: 8)
                            Text(event.time)
                                .monoMetric()
                            Text(event.label)
                                .foregroundStyle(DTColors.secondaryText)
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                    }
                }
            }
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

private struct AlertsInspector: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                severityTile("Critical", count: count(.critical), color: .red)
                severityTile("Warning", count: count(.warning), color: .yellow)
                severityTile("Advisory", count: count(.advisory), color: .purple)
            }

            if model.alerts.isEmpty {
                EmptyInspectorState(symbol: "bell.slash", title: "No Active Alerts", message: "Alerts from the authorized source will appear here.")
            } else {
                ForEach(model.alerts) { alert in
                    alertRow(alert)
                }
            }

            DividerLine()
            Text("Actions are viewing actions only: View Impact, Track Affected Flights, Share Alert.")
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
        }
    }

    private func count(_ severity: AirspaceAlert.Severity) -> Int {
        model.alerts.filter { $0.severity == severity }.count
    }

    private func severityTile(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monoMetric()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func alertRow(_ alert: AirspaceAlert) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DTColors.status(alert.severity))
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(alert.location)  \(alert.time)")
                    .font(.caption2)
                    .foregroundStyle(DTColors.secondaryText)
                Text(alert.impact)
                    .font(.caption)
                    .foregroundStyle(DTColors.secondaryText)
            }
            Spacer()
            Text("\(alert.affectedFlights)")
                .font(.caption.weight(.bold))
                .monoMetric()
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }
}

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.caption2.weight(.bold))
        .foregroundStyle(DTColors.faintText)
}

private struct EmptyInspectorState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(DTColors.secondaryText)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(DTColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
    }
}
