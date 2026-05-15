import Foundation

enum AirspaceMode: String, CaseIterable, Identifiable {
    case live
    case tower
    case flight
    case weather
    case replay
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "Overview"
        case .tower: "Tower"
        case .flight: "Flight"
        case .weather: "Weather"
        case .replay: "Replay"
        case .alerts: "Alerts"
        }
    }

    var subtitle: String {
        switch self {
        case .live: "Traffic overview"
        case .tower: "Airport context"
        case .flight: "Selected flight"
        case .weather: "Weather context"
        case .replay: "Traffic playback"
        case .alerts: "Events and reminders"
        }
    }

    var symbol: String {
        switch self {
        case .live: "scope"
        case .tower: "building.columns"
        case .flight: "airplane"
        case .weather: "cloud.sun"
        case .replay: "play.circle"
        case .alerts: "bell"
        }
    }
}

enum ExperienceMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case skyPortal
    case digitalTower
    case nearbySky
    case flightChase
    case globe
    case replay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skyPortal: "Sky Portal"
        case .digitalTower: "Digital Tower"
        case .nearbySky: "Nearby Sky"
        case .flightChase: "Flight Chase"
        case .globe: "Globe"
        case .replay: "Replay"
        }
    }

    var subtitle: String {
        switch self {
        case .skyPortal: "Cinematic entry airspace"
        case .digitalTower: "Airport tower environment"
        case .nearbySky: "Room-scale traffic bubble"
        case .flightChase: "Follow a selected aircraft"
        case .globe: "Global traffic arcs"
        case .replay: "Traffic playback"
        }
    }

    var symbol: String {
        switch self {
        case .skyPortal: "sparkles"
        case .digitalTower: "building.columns"
        case .nearbySky: "scope"
        case .flightChase: "airplane"
        case .globe: "globe.americas"
        case .replay: "clock.arrow.circlepath"
        }
    }

    var legacyMode: AirspaceMode {
        switch self {
        case .skyPortal, .nearbySky, .globe:
            return .live
        case .digitalTower:
            return .tower
        case .flightChase:
            return .flight
        case .replay:
            return .replay
        }
    }

    static func fromLegacyMode(_ mode: AirspaceMode) -> ExperienceMode {
        switch mode {
        case .live:
            return .nearbySky
        case .tower:
            return .digitalTower
        case .flight:
            return .flightChase
        case .weather:
            return .nearbySky
        case .replay:
            return .replay
        case .alerts:
            return .digitalTower
        }
    }
}

enum SceneScalePreset: String, CaseIterable, Identifiable, Hashable, Sendable {
    case tabletopAirport
    case roomScaleAirport
    case fullSky
    case globe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tabletopAirport: "Tabletop"
        case .roomScaleAirport: "Room"
        case .fullSky: "Full Sky"
        case .globe: "Globe"
        }
    }

    var horizontalMetersPerSceneMeter: Float {
        switch self {
        case .tabletopAirport: 5_400
        case .roomScaleAirport: 2_400
        case .fullSky: 3_200
        case .globe: 8_000
        }
    }

    var feetPerSceneMeter: Float {
        switch self {
        case .tabletopAirport: 18_000
        case .roomScaleAirport: 9_000
        case .fullSky: 11_000
        case .globe: 30_000
        }
    }

    var distanceClamp: Float {
        switch self {
        case .tabletopAirport: 1.35
        case .roomScaleAirport: 3.3
        case .fullSky: 4.8
        case .globe: 1.8
        }
    }
}

enum AircraftDensity: String, CaseIterable, Identifiable, Hashable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var visibleLimit: Int {
        switch self {
        case .low: 8
        case .medium: 8
        case .high: 8
        }
    }
}

enum LabelDensity: String, CaseIterable, Identifiable, Hashable, Sendable {
    case minimal
    case focused
    case expanded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: "Minimal"
        case .focused: "Focused"
        case .expanded: "Expanded"
        }
    }
}

struct FlightRegion: Hashable, Sendable {
    let centerLatitude: Double
    let centerLongitude: Double
    let radiusNauticalMiles: Double
    let airportCode: String?

    init(centerLatitude: Double, centerLongitude: Double, radiusNauticalMiles: Double, airportCode: String? = nil) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.radiusNauticalMiles = radiusNauticalMiles
        self.airportCode = airportCode
    }
}

struct ReplayQuery: Hashable, Sendable {
    let airportCode: String
    let from: Date
    let to: Date
}

enum AirspaceOverlay: String, CaseIterable, Identifiable, Hashable, Sendable {
    case traffic
    case runways
    case weather
    case labels
    case altitudeBands
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traffic: "Traffic"
        case .runways: "Runways"
        case .weather: "Weather"
        case .labels: "Labels"
        case .altitudeBands: "Altitude"
        case .alerts: "Alerts"
        }
    }

    var symbol: String {
        switch self {
        case .traffic: "airplane"
        case .runways: "road.lanes"
        case .weather: "cloud.rain"
        case .labels: "tag"
        case .altitudeBands: "square.3.layers.3d"
        case .alerts: "exclamationmark.triangle"
        }
    }
}

enum WeatherLayer: String, CaseIterable, Identifiable, Hashable, Sendable {
    case metar
    case taf
    case wind
    case visibility
    case stormCells
    case deicing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metar: "METAR"
        case .taf: "TAF"
        case .wind: "Wind"
        case .visibility: "Visibility"
        case .stormCells: "Storm Cells"
        case .deicing: "De-icing"
        }
    }

    var symbol: String {
        switch self {
        case .metar: "cloud"
        case .taf: "cloud.sun"
        case .wind: "wind"
        case .visibility: "eye"
        case .stormCells: "cloud.bolt.rain"
        case .deicing: "snowflake"
        }
    }
}

enum TowerViewpoint: String, CaseIterable, Identifiable, Hashable, Sendable {
    case tower
    case runway
    case arrivalCorridor
    case departureCorridor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tower: "Tower"
        case .runway: "Runway"
        case .arrivalCorridor: "Arrivals"
        case .departureCorridor: "Departures"
        }
    }

    var symbol: String {
        switch self {
        case .tower: "binoculars"
        case .runway: "road.lanes"
        case .arrivalCorridor: "arrow.down.forward"
        case .departureCorridor: "arrow.up.forward"
        }
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case account
    case dataSources
    case display
    case spatialLayout
    case notifications
    case accessibility
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "Account"
        case .dataSources: "Data Sources"
        case .display: "Display"
        case .spatialLayout: "Spatial Layout"
        case .notifications: "Notifications"
        case .accessibility: "Accessibility"
        case .privacy: "Privacy"
        }
    }

    var symbol: String {
        switch self {
        case .account: "person.crop.circle"
        case .dataSources: "externaldrive.connected.to.line.below"
        case .display: "display"
        case .spatialLayout: "cube.transparent"
        case .notifications: "bell"
        case .accessibility: "accessibility"
        case .privacy: "lock.shield"
        }
    }
}

struct Airport: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let iata: String
    let icao: String
    let name: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
    let runways: [Runway]
}

struct Runway: Identifiable, Hashable, Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case active = "Active"
        case standby = "Standby"
        case closed = "Closed"
    }

    let id: String
    let usage: String
    let status: Status
    let condition: String
}

struct FlightTrack: Identifiable, Hashable, Codable, Sendable {
    enum Category: String, Codable, Sendable {
        case commercial = "Commercial"
        case cargo = "Cargo"
        case privateJet = "Private"
        case unknown = "Unknown"
    }

    enum Phase: String, Codable, Sendable {
        case pushback = "Pushback"
        case taxi = "Taxi"
        case takeoffRoll = "Takeoff Roll"
        case rotation = "Rotation"
        case takeoff = "Takeoff"
        case initialClimb = "Initial Climb"
        case climb = "Climb"
        case cruise = "Cruise"
        case holding = "Holding"
        case descent = "Descent"
        case downwind = "Downwind"
        case baseTurn = "Base Turn"
        case finalApproach = "Final Approach"
        case final = "Final"
        case landingFlare = "Landing Flare"
        case touchdown = "Touchdown"
        case rollout = "Rollout"
        case taxiIn = "Taxi In"
        case taxiOut = "Taxi Out"
        case lineUp = "Line Up"
        case landed = "Landed"
        case departureTurn = "Departure Turn"
        case departureClimb = "Departure Climb"
        case goAround = "Go-Around"

        enum Family: String, Codable, Sendable {
            case surface
            case departure
            case enroute
            case arrival
            case recovery
        }

        var displayName: String {
            switch self {
            case .final, .finalApproach:
                return "Final Approach"
            case .goAround:
                return "Go-Around"
            default:
                return rawValue
            }
        }

        var shortLabel: String {
            switch self {
            case .pushback: "PUSH"
            case .taxi: "TAXI"
            case .takeoffRoll: "ROLL"
            case .rotation: "ROT"
            case .takeoff: "TO"
            case .initialClimb: "ICL"
            case .climb: "CLB"
            case .cruise: "CRZ"
            case .holding: "HOLD"
            case .descent: "DES"
            case .downwind: "DW"
            case .baseTurn: "BASE"
            case .finalApproach: "FINAL"
            case .final: "FINAL"
            case .landingFlare: "FLARE"
            case .touchdown: "TD"
            case .rollout: "RLO"
            case .taxiIn: "TXI"
            case .taxiOut: "TXO"
            case .lineUp: "LINE"
            case .landed: "LND"
            case .departureTurn: "DTURN"
            case .departureClimb: "DCLB"
            case .goAround: "GA"
            }
        }

        var family: Family {
            switch self {
            case .pushback, .taxi, .taxiIn, .taxiOut, .lineUp, .landed:
                return .surface
            case .takeoffRoll, .rotation, .takeoff, .initialClimb, .departureTurn, .departureClimb, .climb:
                return .departure
            case .cruise:
                return .enroute
            case .holding, .descent, .downwind, .baseTurn, .finalApproach, .final, .landingFlare, .touchdown, .rollout:
                return .arrival
            case .goAround:
                return .recovery
            }
        }

        var displayColor: AviationColorToken {
            switch family {
            case .surface:
                return AviationColorToken(name: "Surface", hex: "#A7B0BA")
            case .departure:
                return AviationColorToken(name: "Departure", hex: "#FFB44C")
            case .enroute:
                return AviationColorToken(name: "Enroute", hex: "#68B7FF")
            case .arrival:
                return AviationColorToken(name: "Arrival", hex: "#50D8FF")
            case .recovery:
                return AviationColorToken(name: "Recovery", hex: "#FF6A3D")
            }
        }

        var trailStyle: FlightTrailStyle {
            switch self {
            case .pushback, .taxi, .taxiIn, .taxiOut, .lineUp, .landed:
                return FlightTrailStyle(color: displayColor, opacity: 0.18, width: 0.6, pattern: .shortDash)
            case .takeoffRoll, .rotation, .touchdown, .rollout:
                return FlightTrailStyle(color: displayColor, opacity: 0.36, width: 0.95, pattern: .solid)
            case .downwind, .baseTurn, .finalApproach, .final, .landingFlare, .goAround:
                return FlightTrailStyle(color: displayColor, opacity: 0.42, width: 1.15, pattern: .solid)
            case .holding:
                return FlightTrailStyle(color: displayColor, opacity: 0.3, width: 0.85, pattern: .loop)
            case .departureTurn, .departureClimb:
                return FlightTrailStyle(color: displayColor, opacity: 0.34, width: 0.9, pattern: .solid)
            default:
                return FlightTrailStyle(color: displayColor, opacity: 0.26, width: 0.75, pattern: .solid)
            }
        }

        var priority: Int {
            switch self {
            case .goAround:
                return 100
            case .landingFlare, .touchdown:
                return 90
            case .finalApproach, .final, .takeoffRoll, .rotation, .departureTurn:
                return 80
            case .downwind, .baseTurn, .initialClimb, .departureClimb, .rollout, .holding:
                return 65
            case .takeoff, .climb, .descent:
                return 50
            case .pushback, .taxi, .taxiIn, .taxiOut, .lineUp, .cruise, .landed:
                return 30
            }
        }

        var soundCue: FlightSoundCue {
            switch self {
            case .goAround:
                return FlightSoundCue(id: "phase.go-around", intensity: .critical)
            case .landingFlare, .touchdown:
                return FlightSoundCue(id: "phase.landing-close", intensity: .prominent)
            case .takeoffRoll, .rotation:
                return FlightSoundCue(id: "phase.departure-roll", intensity: .prominent)
            case .finalApproach, .final, .holding:
                return FlightSoundCue(id: "phase.arrival-monitor", intensity: .ambient)
            case .departureTurn, .departureClimb, .initialClimb:
                return FlightSoundCue(id: "phase.departure-climb", intensity: .ambient)
            default:
                return FlightSoundCue(id: "phase.standard", intensity: .subtle)
            }
        }
    }

    let id: String
    let callsign: String
    let airline: String
    let aircraft: String
    let registration: String
    let category: Category
    let origin: String
    let destination: String
    let latitude: Double
    let longitude: Double
    let altitudeFeet: Int
    let speedKnots: Int
    let headingDegrees: Int
    let verticalRateFeet: Int
    let phase: Phase
    let progress: Double
    let updatedAt: Date?
    let route: FlightRoute?

    init(
        id: String,
        callsign: String,
        airline: String,
        aircraft: String,
        registration: String,
        category: Category,
        origin: String,
        destination: String,
        latitude: Double,
        longitude: Double,
        altitudeFeet: Int,
        speedKnots: Int,
        headingDegrees: Int,
        verticalRateFeet: Int,
        phase: Phase,
        progress: Double,
        updatedAt: Date?,
        route: FlightRoute? = nil
    ) {
        self.id = id
        self.callsign = callsign
        self.airline = airline
        self.aircraft = aircraft
        self.registration = registration
        self.category = category
        self.origin = origin
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeFeet = altitudeFeet
        self.speedKnots = speedKnots
        self.headingDegrees = headingDegrees
        self.verticalRateFeet = verticalRateFeet
        self.phase = phase
        self.progress = progress
        self.updatedAt = updatedAt
        self.route = route
    }
}

struct AviationColorToken: Hashable, Codable, Sendable {
    let name: String
    let hex: String
}

struct FlightTrailStyle: Hashable, Codable, Sendable {
    enum Pattern: String, Codable, Sendable {
        case solid
        case shortDash
        case loop
    }

    let color: AviationColorToken
    let opacity: Double
    let width: Double
    let pattern: Pattern
}

struct FlightSoundCue: Hashable, Codable, Sendable {
    enum Intensity: String, Codable, Sendable {
        case subtle
        case ambient
        case prominent
        case critical
    }

    let id: String
    let intensity: Intensity
}

struct FlightRoute: Hashable, Codable, Sendable {
    let name: String
    let activeWaypointID: String?
    let waypoints: [FlightWaypoint]
}

struct FlightWaypoint: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case gate
        case runway
        case taxiway
        case fix
        case hold
        case vector
    }

    let id: String
    let name: String
    let kind: Kind
    let latitude: Double
    let longitude: Double
    let altitudeFeet: Int?
    let speedKnots: Int?
    let phaseHint: FlightTrack.Phase?
}

struct WeatherSnapshot: Hashable, Codable, Sendable {
    let condition: String
    let temperature: Int
    let windDirection: Int
    let windSpeed: Int
    let visibilityMiles: Int
    let ceilingFeet: Int
    let delayRisk: String
    let delayRiskValue: Double
    let runwayContext: String
    let updatedAt: String
}

struct AirspaceAlert: Identifiable, Hashable, Codable, Sendable {
    enum Severity: String, Codable, Sendable {
        case critical = "Critical"
        case warning = "Warning"
        case advisory = "Advisory"
        case info = "Info"
    }

    let id: String
    let severity: Severity
    let title: String
    let location: String
    let time: String
    let impact: String
    let affectedFlights: Int
}

struct ReplayEvent: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case arrival = "Arrivals"
        case departure = "Departures"
        case overflight = "Overflights"
        case alert = "Alerts"
    }

    let id: String
    let time: String
    let kind: Kind
    let label: String
}

struct DataFreshness: Hashable, Codable, Sendable {
    let sourceName: String
    let serverTime: Date
    let receivedAt: Date
    let expiresAt: Date
    let isAuthorizedLive: Bool

    var isStale: Bool {
        Date() > expiresAt
    }
}

struct AviationSnapshot: Hashable, Codable, Sendable {
    let airport: Airport
    let flights: [FlightTrack]
    let weather: WeatherSnapshot
    let alerts: [AirspaceAlert]
    let replayEvents: [ReplayEvent]
    let freshness: DataFreshness

    var hasTraffic: Bool {
        !flights.isEmpty
    }
}

enum DataState<Value: Sendable>: Sendable {
    case idle
    case loading(previous: Value?)
    case loaded(Value)
    case empty(reason: String, freshness: DataFreshness?)
    case failed(message: String, previous: Value?)
    case stale(Value, message: String)

    var value: Value? {
        switch self {
        case .idle, .empty:
            return nil
        case .loading(let previous), .failed(_, let previous):
            return previous
        case .loaded(let value), .stale(let value, _):
            return value
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var userMessage: String? {
        switch self {
        case .idle, .loaded:
            return nil
        case .loading:
            return "Loading authorized aviation data"
        case .empty(let reason, _):
            return reason
        case .failed(let message, _), .stale(_, let message):
            return message
        }
    }
}

extension DataState: Equatable where Value: Equatable {}

enum SearchResult: Identifiable, Hashable, Sendable {
    case flight(FlightTrack)
    case airport(Airport)

    var id: String {
        switch self {
        case .flight(let flight): "flight-\(flight.id)"
        case .airport(let airport): "airport-\(airport.id)"
        }
    }

    var title: String {
        switch self {
        case .flight(let flight): flight.callsign
        case .airport(let airport): "\(airport.iata) - \(airport.name)"
        }
    }

    var subtitle: String {
        switch self {
        case .flight(let flight): "\(flight.origin) to \(flight.destination) - \(flight.aircraft)"
        case .airport(let airport): "\(airport.city), \(airport.country)"
        }
    }

    var symbol: String {
        switch self {
        case .flight: "airplane"
        case .airport: "building.columns"
        }
    }
}

struct AirspaceMetrics: Hashable, Sendable {
    let visibleFlights: Int
    let arrivals: Int
    let departures: Int
    let highPriorityAlerts: Int
    let congestionLabel: String
    let congestionValue: Double
}

enum AirportCatalog {
    static let airports: [Airport] = [
        Airport(
            id: "KJFK",
            iata: "JFK",
            icao: "KJFK",
            name: "John F. Kennedy Intl.",
            city: "New York",
            country: "USA",
            latitude: 40.6413,
            longitude: -73.7781,
            runways: [
                Runway(id: "04L / 22R", usage: "Traffic flow", status: .active, condition: "IFR"),
                Runway(id: "04R / 22L", usage: "Traffic flow", status: .active, condition: "IFR"),
                Runway(id: "13L / 31R", usage: "Crosswind context", status: .standby, condition: "VFR"),
                Runway(id: "13R / 31L", usage: "Unavailable context", status: .closed, condition: "-")
            ]
        ),
        Airport(
            id: "KLAX",
            iata: "LAX",
            icao: "KLAX",
            name: "Los Angeles Intl.",
            city: "Los Angeles",
            country: "USA",
            latitude: 33.9416,
            longitude: -118.4085,
            runways: [
                Runway(id: "06L / 24R", usage: "Traffic flow", status: .active, condition: "VFR"),
                Runway(id: "06R / 24L", usage: "Traffic flow", status: .active, condition: "VFR")
            ]
        ),
        Airport(
            id: "EGLL",
            iata: "LHR",
            icao: "EGLL",
            name: "Heathrow",
            city: "London",
            country: "UK",
            latitude: 51.4700,
            longitude: -0.4543,
            runways: [
                Runway(id: "09L / 27R", usage: "Traffic flow", status: .active, condition: "VFR"),
                Runway(id: "09R / 27L", usage: "Traffic flow", status: .standby, condition: "VFR")
            ]
        ),
        Airport(
            id: "WSSS",
            iata: "SIN",
            icao: "WSSS",
            name: "Changi",
            city: "Singapore",
            country: "Singapore",
            latitude: 1.3644,
            longitude: 103.9915,
            runways: [
                Runway(id: "02L / 20R", usage: "Arrival flow", status: .active, condition: "VFR"),
                Runway(id: "02C / 20C", usage: "Departure flow", status: .active, condition: "VFR"),
                Runway(id: "02R / 20L", usage: "Standby context", status: .standby, condition: "VFR")
            ]
        ),
        Airport(
            id: "ZSPD",
            iata: "PVG",
            icao: "ZSPD",
            name: "Shanghai Pudong",
            city: "Shanghai",
            country: "China",
            latitude: 31.1443,
            longitude: 121.8083,
            runways: [
                Runway(id: "16L / 34R", usage: "Arrival flow", status: .active, condition: "IFR"),
                Runway(id: "16R / 34L", usage: "Departure flow", status: .active, condition: "IFR"),
                Runway(id: "17L / 35R", usage: "Cargo flow", status: .active, condition: "IFR"),
                Runway(id: "17R / 35L", usage: "Standby context", status: .standby, condition: "IFR")
            ]
        ),
        Airport(
            id: "ZSNB",
            iata: "NGB",
            icao: "ZSNB",
            name: "Ningbo Lishe",
            city: "Ningbo",
            country: "China",
            latitude: 29.8267,
            longitude: 121.4619,
            runways: [
                Runway(id: "13 / 31", usage: "Mixed flow", status: .active, condition: "VFR")
            ]
        )
    ]

    static let fallbackAirport = airports[0]
}
