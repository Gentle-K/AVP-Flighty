import Foundation

#if DEBUG
enum SampleData {
    static let airport = AirportCatalog.fallbackAirport

    static var freshness: DataFreshness {
        DataFreshness(
            sourceName: "Debug spatial sample provider",
            serverTime: Date(),
            receivedAt: Date(),
            expiresAt: Date().addingTimeInterval(300),
            isAuthorizedLive: false
        )
    }

    static let weather = WeatherSnapshot(
        condition: "Layered Clouds",
        temperature: 72,
        windDirection: 180,
        windSpeed: 12,
        visibilityMiles: 10,
        ceilingFeet: 3_200,
        delayRisk: "Low",
        delayRiskValue: 0.12,
        runwayContext: "Active arrival corridor with light crosswind context",
        updatedAt: "Debug"
    )

    static let alerts: [AirspaceAlert] = [
        AirspaceAlert(
            id: "surface-context",
            severity: .advisory,
            title: "Discovery Advisory",
            location: "Airport Surface",
            time: "Now",
            impact: "Runway and traffic flow are mock spatial context",
            affectedFlights: 18
        ),
        AirspaceAlert(
            id: "weather-cell",
            severity: .warning,
            title: "Weather Layer Nearby",
            location: "Arrival Corridor",
            time: "Now",
            impact: "Volumetric weather layer visible in immersive mode",
            affectedFlights: 6
        )
    ]

    static let replayEvents: [ReplayEvent] = [
        ReplayEvent(id: "e1", time: "10:32", kind: .arrival, label: "Arrival stream builds"),
        ReplayEvent(id: "e2", time: "10:47", kind: .departure, label: "Departure wave"),
        ReplayEvent(id: "e3", time: "11:05", kind: .overflight, label: "Overflight traffic"),
        ReplayEvent(id: "e4", time: "11:18", kind: .alert, label: "Weather layer enters corridor"),
        ReplayEvent(id: "e5", time: "11:24", kind: .arrival, label: "Close approach moment")
    ]

    static let flights: [FlightTrack] = flights(for: airport)

    static func snapshot(for airport: Airport = airport) -> AviationSnapshot {
        AviationSnapshot(
            airport: airport,
            flights: flights(for: airport),
            weather: weather,
            alerts: alerts,
            replayEvents: replayEvents,
            freshness: freshness
        )
    }

    static func flights(for airport: Airport, tick: Int = 0) -> [FlightTrack] {
        let templates: [(String, String, String, String, String, FlightTrack.Category, Double, Double, Int, Int, Int, FlightTrack.Phase)] = [
            ("DTX2468", "Digital Tower Air", "A321", "ATL", airport.iata, .commercial, -9.4, 15.0, 4_200, 276, 58, .final),
            ("DTA123", "Digital Tower Air", "B738", airport.iata, "MIA", .commercial, 8.8, -8.0, 2_800, 238, 192, .climb),
            ("DTO050", "Digital Tower Longhaul", "B77W", "SFO", airport.iata, .commercial, -13.0, -5.5, 3_500, 265, 88, .final),
            ("DTB789", "Digital Tower Shuttle", "A320", "BOS", airport.iata, .commercial, -2.2, 2.8, 2_100, 181, 226, .taxi),
            ("DTF234", "Digital Tower Frontier", "B763", "DEN", airport.iata, .commercial, 12.0, 13.0, 6_000, 302, 112, .descent),
            ("DTX908", "Digital Tower Cargo", "B752F", "SDF", airport.iata, .cargo, 16.0, -16.0, 12_400, 386, 71, .descent),
            ("SKY411", "Skybridge", "A359", airport.iata, "LHR", .commercial, -20.0, 5.0, 18_500, 430, 34, .climb),
            ("PAC705", "Pacific Air", "B789", "SIN", airport.iata, .commercial, 23.0, 18.0, 22_000, 445, 242, .descent),
            ("CIN612", "Cinna Cargo", "B77F", airport.iata, "PVG", .cargo, -17.0, -20.0, 14_200, 390, 146, .climb),
            ("NGB208", "Ningbo Connect", "E190", "NGB", airport.iata, .commercial, 6.0, 20.0, 7_500, 310, 278, .descent),
            ("GLB331", "Global Link", "A21N", airport.iata, "JFK", .commercial, 19.0, -4.0, 10_800, 352, 308, .climb),
            ("TWR777", "Tower Executive", "G650", "TEB", airport.iata, .privateJet, -4.0, -18.0, 16_000, 410, 96, .cruise)
        ]

        let expanded = (0..<36).map { index -> FlightTrack in
            let template = templates[index % templates.count]
            let lap = index / templates.count
            let motion = Double(tick) * 0.42 * Double((index % 3) + 1)
            let heading = (template.10 + tick * (index.isMultiple(of: 2) ? 1 : -1) + lap * 11).wrappedDegrees
            let east = template.6 + cos((Double(heading) + motion) * .pi / 180) * Double(lap) * 4.8
            let north = template.7 + sin((Double(heading) + motion) * .pi / 180) * Double(lap) * 4.2
            let coordinate = coordinate(from: airport, eastNM: east + motion * 0.08, northNM: north + motion * 0.06)
            let altitude = max(400, template.8 + lap * 2_200 + ((tick + index) % 5) * 120)
            let verticalRate = template.11 == .descent || template.11 == .final ? -700 - lap * 90 : 650 + lap * 80
            let callsign = lap == 0 ? template.0 : "\(template.0)\(lap)"

            return FlightTrack(
                id: callsign,
                callsign: callsign,
                airline: template.1,
                aircraft: template.2,
                registration: "N\(abs(callsign.hashValue % 900) + 100)DT",
                category: template.5,
                origin: template.3,
                destination: template.4,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                altitudeFeet: altitude,
                speedKnots: template.9 + lap * 18,
                headingDegrees: heading,
                verticalRateFeet: verticalRate,
                phase: template.11,
                progress: min(0.97, 0.16 + Double(index % 12) * 0.065 + Double(tick % 20) * 0.004),
                updatedAt: Date()
            )
        }

        return expanded
    }

    private static func coordinate(from airport: Airport, eastNM: Double, northNM: Double) -> (latitude: Double, longitude: Double) {
        let latitude = airport.latitude + northNM / 60.0
        let longitudeScale = max(0.18, cos(airport.latitude * .pi / 180))
        let longitude = airport.longitude + eastNM / (60.0 * longitudeScale)
        return (latitude, longitude)
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
        let airport = airport(for: airportCode)
        return SampleData.snapshot(for: airport)
    }

    func events(airportCode: String) -> AsyncThrowingStream<AviationDataEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let airport = airport(for: airportCode)
                var tick = 0
                continuation.yield(.heartbeat(Date()))

                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(900))
                    tick += 1
                    for flight in SampleData.flights(for: airport, tick: tick).prefix(18) {
                        continuation.yield(.flightUpsert(flight))
                    }
                    continuation.yield(.heartbeat(Date()))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func fetchFlights(region: FlightRegion) async throws -> [FlightTrack] {
        let airport = region.airportCode.map(airport(for:)) ?? AirportCatalog.fallbackAirport
        return SampleData.flights(for: airport)
    }

    func fetchFlightDetail(flightId: String) async throws -> FlightTrack? {
        SampleData.flights.first { $0.id == flightId }
    }

    private func airport(for code: String) -> Airport {
        AirportCatalog.airports.first { airport in
            airport.icao.caseInsensitiveCompare(code) == .orderedSame
                || airport.iata.caseInsensitiveCompare(code) == .orderedSame
                || airport.id.caseInsensitiveCompare(code) == .orderedSame
        } ?? AirportCatalog.fallbackAirport
    }
}

private extension Int {
    var wrappedDegrees: Int {
        let value = self % 360
        return value < 0 ? value + 360 : value
    }
}
#endif
