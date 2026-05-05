import Foundation

#if DEBUG
enum SampleData {
    static let airport = AirportCatalog.fallbackAirport

    static let freshness = DataFreshness(
        sourceName: "Debug sample provider",
        serverTime: Date(timeIntervalSinceReferenceDate: 800_000_000),
        receivedAt: Date(),
        expiresAt: Date().addingTimeInterval(300),
        isAuthorizedLive: false
    )

    static let flights: [FlightTrack] = [
        FlightTrack(
            id: "DTX2468",
            callsign: "DTX2468",
            airline: "Digital Tower Air",
            aircraft: "A321",
            registration: "N321DT",
            category: .commercial,
            origin: "ATL",
            destination: "JFK",
            latitude: 40.58,
            longitude: -73.95,
            altitudeFeet: 4_200,
            speedKnots: 276,
            headingDegrees: 58,
            verticalRateFeet: -1_100,
            phase: .final,
            progress: 0.82,
            updatedAt: Date()
        ),
        FlightTrack(
            id: "DTA123",
            callsign: "DTA123",
            airline: "Digital Tower Air",
            aircraft: "B738",
            registration: "N923DT",
            category: .commercial,
            origin: "JFK",
            destination: "MIA",
            latitude: 40.72,
            longitude: -73.63,
            altitudeFeet: 2_800,
            speedKnots: 238,
            headingDegrees: 192,
            verticalRateFeet: 900,
            phase: .climb,
            progress: 0.23,
            updatedAt: Date()
        ),
        FlightTrack(
            id: "DTO050",
            callsign: "DTO050",
            airline: "Digital Tower Longhaul",
            aircraft: "B77W",
            registration: "N274DT",
            category: .commercial,
            origin: "SFO",
            destination: "JFK",
            latitude: 40.77,
            longitude: -74.22,
            altitudeFeet: 3_500,
            speedKnots: 265,
            headingDegrees: 88,
            verticalRateFeet: -1_500,
            phase: .final,
            progress: 0.9,
            updatedAt: Date()
        ),
        FlightTrack(
            id: "DTB789",
            callsign: "DTB789",
            airline: "Digital Tower Shuttle",
            aircraft: "A320",
            registration: "N789DT",
            category: .commercial,
            origin: "BOS",
            destination: "JFK",
            latitude: 40.66,
            longitude: -74.08,
            altitudeFeet: 2_100,
            speedKnots: 181,
            headingDegrees: 226,
            verticalRateFeet: -700,
            phase: .taxi,
            progress: 0.72,
            updatedAt: Date()
        ),
        FlightTrack(
            id: "DTF234",
            callsign: "DTF234",
            airline: "Digital Tower Frontier",
            aircraft: "B763",
            registration: "N763DT",
            category: .commercial,
            origin: "DEN",
            destination: "JFK",
            latitude: 40.43,
            longitude: -73.58,
            altitudeFeet: 6_000,
            speedKnots: 302,
            headingDegrees: 112,
            verticalRateFeet: -800,
            phase: .descent,
            progress: 0.65,
            updatedAt: Date()
        ),
        FlightTrack(
            id: "DTX908",
            callsign: "DTX908",
            airline: "Digital Tower Cargo",
            aircraft: "B752F",
            registration: "N441DT",
            category: .cargo,
            origin: "SDF",
            destination: "JFK",
            latitude: 40.49,
            longitude: -73.44,
            altitudeFeet: 12_400,
            speedKnots: 386,
            headingDegrees: 71,
            verticalRateFeet: -500,
            phase: .descent,
            progress: 0.54,
            updatedAt: Date()
        )
    ]

    static let weather = WeatherSnapshot(
        condition: "Scattered Clouds",
        temperature: 72,
        windDirection: 180,
        windSpeed: 12,
        visibilityMiles: 10,
        ceilingFeet: 3_200,
        delayRisk: "Low",
        delayRiskValue: 0.12,
        runwayContext: "22L wind context",
        updatedAt: "11:24 AM EDT"
    )

    static let alerts: [AirspaceAlert] = [
        AirspaceAlert(
            id: "surface-context",
            severity: .critical,
            title: "Surface Flow Advisory",
            location: "JFK",
            time: "11:22 AM",
            impact: "Traffic exploration impact",
            affectedFlights: 68
        ),
        AirspaceAlert(
            id: "weather-cell",
            severity: .critical,
            title: "Convective Weather Nearby",
            location: "JFK Airspace North",
            time: "11:20 AM",
            impact: "Weather cell near arrival paths",
            affectedFlights: 32
        ),
        AirspaceAlert(
            id: "ground-delay",
            severity: .warning,
            title: "Delay Program Context",
            location: "JFK",
            time: "11:18 AM",
            impact: "Average delay 45-90 min",
            affectedFlights: 45
        ),
        AirspaceAlert(
            id: "high-wind",
            severity: .advisory,
            title: "High Wind Context",
            location: "Approach Corridor",
            time: "11:15 AM",
            impact: "Crosswind monitoring context",
            affectedFlights: 12
        )
    ]

    static let replayEvents: [ReplayEvent] = [
        ReplayEvent(id: "e1", time: "10:32", kind: .arrival, label: "Arrival flow builds"),
        ReplayEvent(id: "e2", time: "10:47", kind: .departure, label: "Departure flow wave"),
        ReplayEvent(id: "e3", time: "11:05", kind: .overflight, label: "Overflight traffic"),
        ReplayEvent(id: "e4", time: "11:18", kind: .alert, label: "Delay context"),
        ReplayEvent(id: "e5", time: "11:24", kind: .arrival, label: "Arrival flow peak")
    ]

    static func snapshot(for airport: Airport = airport) -> AviationSnapshot {
        AviationSnapshot(
            airport: airport,
            flights: flights,
            weather: weather,
            alerts: alerts,
            replayEvents: replayEvents,
            freshness: freshness
        )
    }
}

struct SampleAviationDataProvider: FlightDataProvider {
    let latency: Duration

    init(latency: Duration = .milliseconds(250)) {
        self.latency = latency
    }

    var isAuthorizedLiveProvider: Bool { false }

    func bootstrap(airportCode: String) async throws -> AviationSnapshot {
        try await Task.sleep(for: latency)
        let airport = AirportCatalog.airports.first { $0.icao == airportCode || $0.iata == airportCode } ?? AirportCatalog.fallbackAirport
        return SampleData.snapshot(for: airport)
    }

    func events(airportCode: String) -> AsyncThrowingStream<AviationDataEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.heartbeat(Date()))
        }
    }
}
#endif
