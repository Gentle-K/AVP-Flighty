import Foundation

struct AppContext {
    let mode: AirspaceMode
    let airport: Airport
    let selectedFlight: FlightTrack?
    let flights: [FlightTrack]
    let weather: WeatherSnapshot?
    let alerts: [AirspaceAlert]
    let overlays: Set<AirspaceOverlay>
    let freshness: DataFreshness?
    let isAuthorizedLiveData: Bool

    static func empty(airport: Airport, isAuthorizedLiveData: Bool) -> AppContext {
        AppContext(
            mode: .live,
            airport: airport,
            selectedFlight: nil,
            flights: [],
            weather: nil,
            alerts: [],
            overlays: [.traffic, .labels],
            freshness: nil,
            isAuthorizedLiveData: isAuthorizedLiveData
        )
    }
}

struct AppActionPlan {
    let mode: AirspaceMode
    let headline: String
    let summary: String
    let scenePlan: SceneRenderPlan
    let reports: [AgentReport]
    let recommendedActions: [String]
}

struct SceneRenderPlan {
    let anchor: String
    let visibleFlightCount: Int
    let labelPolicy: String
    let lodPolicy: String
    let activeOverlays: [AirspaceOverlay]
}

struct AgentReport: Identifiable {
    enum Status: String {
        case ready = "Ready"
        case degraded = "Degraded"
        case blocked = "Blocked"
    }

    let id: String
    let name: String
    let status: Status
    let output: String
}

protocol DigitalTowerAgent {
    var name: String { get }
    func run(context: AppContext) -> AgentReport
}

struct OrchestratorAgent {
    private let agents: [DigitalTowerAgent]

    init(agents: [DigitalTowerAgent] = [
        FlightDataAgent(),
        AirportContextAgent(),
        WeatherContextAgent(),
        SpatialSceneAgent(),
        FlightInsightAgent(),
        DiscoveryAgent(),
        ComplianceAgent()
    ]) {
        self.agents = agents
    }

    func plan(for context: AppContext) -> AppActionPlan {
        let reports = agents.map { $0.run(context: context) }
        let scenePlan = SceneRenderPlan(
            anchor: context.mode == .live ? "\(context.airport.iata) traffic overview" : context.airport.icao,
            visibleFlightCount: context.flights.count,
            labelPolicy: "Priority labels first; selected aircraft always keeps a label.",
            lodPolicy: "Near field renders aircraft, mid field renders symbols, high density renders aggregated traffic.",
            activeOverlays: Array(context.overlays).sorted { $0.title < $1.title }
        )

        return AppActionPlan(
            mode: context.mode,
            headline: headline(for: context),
            summary: summary(for: context),
            scenePlan: scenePlan,
            reports: reports,
            recommendedActions: actions(for: context)
        )
    }

    private func headline(for context: AppContext) -> String {
        switch context.mode {
        case .live:
            return "\(context.airport.iata) traffic overview"
        case .tower:
            return "\(context.airport.iata) airport context"
        case .flight:
            return context.selectedFlight.map { "\($0.callsign) \($0.origin) to \($0.destination)" } ?? "Select a flight"
        case .weather:
            return "Weather context near \(context.airport.iata)"
        case .replay:
            return "Traffic replay"
        case .alerts:
            return "\(context.alerts.count) active alerts"
        }
    }

    private func summary(for context: AppContext) -> String {
        guard context.isAuthorizedLiveData else {
            return "Authorized data is required before this view can be treated as current traffic."
        }

        switch context.mode {
        case .live:
            return "\(context.flights.count) tracks are visible from the authorized provider."
        case .tower:
            return "Runway and surface information is shown as contextual discovery data."
        case .flight:
            guard let flight = context.selectedFlight else { return "Select an aircraft to inspect its route and aircraft details." }
            return "\(flight.aircraft) is in \(flight.phase.rawValue.lowercased()) at \(flight.altitudeFeet.formatted()) ft."
        case .weather:
            guard let weather = context.weather else { return "Weather context is loading." }
            return "\(weather.condition), wind \(weather.windDirection) degrees at \(weather.windSpeed) kt, delay risk \(weather.delayRisk.lowercased())."
        case .replay:
            return "Playback is an exploration view of recent traffic flow."
        case .alerts:
            return "Alerts are shown for discovery and awareness, not operational control."
        }
    }

    private func actions(for context: AppContext) -> [String] {
        switch context.mode {
        case .live:
            return ["Open Airport Context", "Follow selected aircraft", "Show altitude bands"]
        case .tower:
            return ["Switch viewpoint", "Show runway context", "Track arrivals"]
        case .flight:
            return ["Follow aircraft", "View route weather", "Add to watchlist"]
        case .weather:
            return ["Show storm cells", "View wind context", "Track affected flights"]
        case .replay:
            return ["Compare window", "Jump to alert", "Export clip"]
        case .alerts:
            return ["View Impact", "Track Affected Flights", "Share Alert"]
        }
    }
}

struct FlightDataAgent: DigitalTowerAgent {
    let name = "Flight Data Agent"

    func run(context: AppContext) -> AgentReport {
        guard context.isAuthorizedLiveData else {
            return AgentReport(
                id: "flight-data",
                name: name,
                status: .blocked,
                output: "Authorized backend data is not active for this build."
            )
        }

        return AgentReport(
            id: "flight-data",
            name: name,
            status: context.freshness?.isStale == true ? .degraded : .ready,
            output: "Provider source: \(context.freshness?.sourceName ?? "Unknown"). Visible tracks: \(context.flights.count)."
        )
    }
}

struct AirportContextAgent: DigitalTowerAgent {
    let name = "Airport Context Agent"

    func run(context: AppContext) -> AgentReport {
        let active = context.airport.runways.filter { $0.status == .active }.map(\.id).joined(separator: ", ")
        return AgentReport(
            id: "airport-context",
            name: name,
            status: active.isEmpty ? .degraded : .ready,
            output: active.isEmpty ? "No runway context is available." : "Contextual runway set: \(active)."
        )
    }
}

struct WeatherContextAgent: DigitalTowerAgent {
    let name = "Weather Context Agent"

    func run(context: AppContext) -> AgentReport {
        guard let weather = context.weather else {
            return AgentReport(id: "weather", name: name, status: .degraded, output: "Weather context is not loaded.")
        }

        return AgentReport(
            id: "weather",
            name: name,
            status: .ready,
            output: "Wind \(weather.windDirection) degrees \(weather.windSpeed) kt, visibility \(weather.visibilityMiles) sm, runway context \(weather.runwayContext)."
        )
    }
}

struct SpatialSceneAgent: DigitalTowerAgent {
    let name = "Spatial Scene Agent"

    func run(context: AppContext) -> AgentReport {
        AgentReport(
            id: "spatial-scene",
            name: name,
            status: .ready,
            output: "RealityKit scene syncs model flights, runway context, weather volume, and density-based LOD."
        )
    }
}

struct FlightInsightAgent: DigitalTowerAgent {
    let name = "Flight Insight Agent"

    func run(context: AppContext) -> AgentReport {
        guard let flight = context.selectedFlight else {
            return AgentReport(id: "flight-insight", name: name, status: .degraded, output: "No selected aircraft.")
        }

        return AgentReport(
            id: "flight-insight",
            name: name,
            status: .ready,
            output: "\(flight.callsign) is \(flight.phase.rawValue.lowercased()); vertical rate \(flight.verticalRateFeet) ft/min explains the current altitude trend."
        )
    }
}

struct DiscoveryAgent: DigitalTowerAgent {
    let name = "Discovery Agent"

    func run(context: AppContext) -> AgentReport {
        let cargo = context.flights.first { $0.category == .cargo }
        return AgentReport(
            id: "discovery",
            name: name,
            status: context.flights.isEmpty ? .degraded : .ready,
            output: cargo.map { "Worth watching: \($0.callsign), a cargo flight near \(context.airport.iata)." } ?? "No highlighted aircraft found."
        )
    }
}

struct ComplianceAgent: DigitalTowerAgent {
    let name = "Compliance Agent"

    func run(context: AppContext) -> AgentReport {
        AgentReport(
            id: "compliance",
            name: name,
            status: context.isAuthorizedLiveData ? .ready : .blocked,
            output: "UI copy is constrained to discovery language and avoids navigation, ATC, flight safety, and operational decision claims."
        )
    }
}
