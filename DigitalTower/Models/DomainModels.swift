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
        case .low: 14
        case .medium: 28
        case .high: 48
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
        case takeoff = "Takeoff"
        case climb = "Climb"
        case cruise = "Cruise"
        case descent = "Descent"
        case final = "Final"
        case landed = "Landed"
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
