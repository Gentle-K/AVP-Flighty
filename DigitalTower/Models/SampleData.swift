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
        struct Template {
            let callsign: String
            let airline: String
            let aircraft: String
            let origin: String
            let destination: String
            let category: FlightTrack.Category
            let eastNM: Double
            let northNM: Double
            let altitudeFeet: Int
            let speedKnots: Int
            let headingDegrees: Int
            let phase: FlightTrack.Phase
        }

        let templates: [Template] = [
            Template(callsign: "DTX2468", airline: "Digital Tower Air", aircraft: "A321neo", origin: "ATL", destination: airport.iata, category: .commercial, eastNM: -9.4, northNM: 15.0, altitudeFeet: 4_200, speedKnots: 176, headingDegrees: 58, phase: .finalApproach),
            Template(callsign: "DTL884", airline: "Digital Tower Shuttle", aircraft: "B738", origin: "BOS", destination: airport.iata, category: .commercial, eastNM: -2.8, northNM: 3.8, altitudeFeet: 620, speedKnots: 142, headingDegrees: 44, phase: .landingFlare),
            Template(callsign: "DTO050", airline: "Digital Tower Longhaul", aircraft: "B77W", origin: "SFO", destination: airport.iata, category: .commercial, eastNM: -0.9, northNM: 0.8, altitudeFeet: 80, speedKnots: 126, headingDegrees: 43, phase: .touchdown),
            Template(callsign: "DTB789", airline: "Digital Tower Shuttle", aircraft: "A320", origin: "MIA", destination: airport.iata, category: .commercial, eastNM: 0.3, northNM: 0.2, altitudeFeet: 20, speedKnots: 86, headingDegrees: 44, phase: .rollout),
            Template(callsign: "DTA123", airline: "Digital Tower Air", aircraft: "B739", origin: airport.iata, destination: "MIA", category: .commercial, eastNM: 1.0, northNM: -0.6, altitudeFeet: 10, speedKnots: 92, headingDegrees: 224, phase: .takeoffRoll),
            Template(callsign: "SKY411", airline: "Skybridge", aircraft: "A359", origin: airport.iata, destination: "LHR", category: .commercial, eastNM: 1.9, northNM: -1.2, altitudeFeet: 220, speedKnots: 156, headingDegrees: 226, phase: .rotation),
            Template(callsign: "PAC705", airline: "Pacific Air", aircraft: "B789", origin: airport.iata, destination: "SIN", category: .commercial, eastNM: 4.7, northNM: -3.4, altitudeFeet: 1_900, speedKnots: 218, headingDegrees: 238, phase: .initialClimb),
            Template(callsign: "HLD332", airline: "Harbor Link", aircraft: "E195-E2", origin: "YYZ", destination: airport.iata, category: .commercial, eastNM: -18.0, northNM: 11.0, altitudeFeet: 8_000, speedKnots: 214, headingDegrees: 92, phase: .holding),
            Template(callsign: "GAA901", airline: "Global Atlantic", aircraft: "B763", origin: "DEN", destination: airport.iata, category: .commercial, eastNM: -6.0, northNM: 6.8, altitudeFeet: 1_600, speedKnots: 188, headingDegrees: 28, phase: .goAround),
            Template(callsign: "DTX908", airline: "Digital Tower Cargo", aircraft: "B752F", origin: "SDF", destination: airport.iata, category: .cargo, eastNM: 16.0, northNM: -16.0, altitudeFeet: 12_400, speedKnots: 386, headingDegrees: 71, phase: .descent),
            Template(callsign: "CIN612", airline: "Cinna Cargo", aircraft: "B77F", origin: airport.iata, destination: "PVG", category: .cargo, eastNM: -17.0, northNM: -20.0, altitudeFeet: 14_200, speedKnots: 390, headingDegrees: 146, phase: .climb),
            Template(callsign: "TWR777", airline: "Tower Executive", aircraft: "G650", origin: "TEB", destination: airport.iata, category: .privateJet, eastNM: -4.0, northNM: -18.0, altitudeFeet: 16_000, speedKnots: 410, headingDegrees: 96, phase: .cruise)
        ]

        let expanded = (0..<36).map { index -> FlightTrack in
            let template = templates[index % templates.count]
            let lap = index / templates.count
            let motion = Double(tick) * 0.42 * Double((index % 3) + 1)
            let heading = (template.headingDegrees + tick * (index.isMultiple(of: 2) ? 1 : -1) + lap * 11).wrappedDegrees
            let east = template.eastNM + cos((Double(heading) + motion) * .pi / 180) * Double(lap) * 4.8
            let north = template.northNM + sin((Double(heading) + motion) * .pi / 180) * Double(lap) * 4.2
            let coordinate = coordinate(from: airport, eastNM: east + motion * 0.08, northNM: north + motion * 0.06)
            let altitude = altitude(for: template.phase, base: template.altitudeFeet, lap: lap, tick: tick, index: index)
            let verticalRate = verticalRate(for: template.phase, lap: lap)
            let callsign = lap == 0 ? template.callsign : "\(template.callsign)\(lap)"

            return FlightTrack(
                id: callsign,
                callsign: callsign,
                airline: template.airline,
                aircraft: template.aircraft,
                registration: "N\(abs(callsign.hashValue % 900) + 100)DT",
                category: template.category,
                origin: template.origin,
                destination: template.destination,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                altitudeFeet: altitude,
                speedKnots: max(0, template.speedKnots + lap * 18),
                headingDegrees: heading,
                verticalRateFeet: verticalRate,
                phase: template.phase,
                progress: min(0.97, 0.16 + Double(index % 12) * 0.065 + Double(tick % 20) * 0.004),
                updatedAt: Date(),
                route: route(
                    for: template.phase,
                    callsign: callsign,
                    airport: airport,
                    origin: template.origin,
                    destination: template.destination,
                    aircraftCoordinate: coordinate
                )
            )
        }

        return expanded
    }

    private static func altitude(for phase: FlightTrack.Phase, base: Int, lap: Int, tick: Int, index: Int) -> Int {
        let pulse = ((tick + index) % 5) * 80
        switch phase {
        case .takeoffRoll, .touchdown, .rollout:
            return max(0, base + min(lap, 1) * 60)
        case .rotation:
            return base + lap * 140 + pulse
        case .landingFlare:
            return max(120, base + lap * 160 - pulse)
        case .downwind, .baseTurn, .finalApproach, .final, .goAround, .initialClimb, .departureTurn, .departureClimb:
            return max(400, base + lap * 900 + pulse)
        default:
            return max(400, base + lap * 2_200 + pulse)
        }
    }

    private static func verticalRate(for phase: FlightTrack.Phase, lap: Int) -> Int {
        switch phase {
        case .downwind, .baseTurn, .finalApproach, .final:
            return -720 - lap * 70
        case .landingFlare:
            return -180
        case .touchdown, .rollout, .takeoffRoll, .taxi, .taxiIn, .taxiOut, .lineUp, .landed:
            return 0
        case .rotation:
            return 1_100 + lap * 80
        case .initialClimb, .departureTurn, .departureClimb, .takeoff, .climb:
            return 1_800 + lap * 90
        case .holding:
            return 0
        case .descent:
            return -900 - lap * 90
        case .goAround:
            return 2_400 + lap * 110
        case .pushback, .cruise:
            return 0
        }
    }

    private static func route(
        for phase: FlightTrack.Phase,
        callsign: String,
        airport: Airport,
        origin: String,
        destination: String,
        aircraftCoordinate: (latitude: Double, longitude: Double)
    ) -> FlightRoute {
        let runwayID = airport.runways.first?.id ?? "Active Runway"
        let runway = FlightWaypoint(
            id: "\(callsign)-runway",
            name: runwayID,
            kind: .runway,
            latitude: airport.latitude,
            longitude: airport.longitude,
            altitudeFeet: 0,
            speedKnots: phase.family == .arrival ? 135 : 145,
            phaseHint: phase
        )
        let aircraftPoint = FlightWaypoint(
            id: "\(callsign)-active",
            name: phase.displayName,
            kind: waypointKind(for: phase),
            latitude: aircraftCoordinate.latitude,
            longitude: aircraftCoordinate.longitude,
            altitudeFeet: nil,
            speedKnots: nil,
            phaseHint: phase
        )
        let outerFix = FlightWaypoint(
            id: "\(callsign)-fix",
            name: phase.family == .departure ? "DEP FIX" : "ARR FIX",
            kind: phase == .holding ? .hold : .fix,
            latitude: aircraftCoordinate.latitude + (phase.family == .departure ? 0.28 : -0.22),
            longitude: aircraftCoordinate.longitude + (phase.family == .departure ? 0.22 : -0.18),
            altitudeFeet: phase.family == .departure ? 12_000 : 6_000,
            speedKnots: phase.family == .departure ? 280 : 210,
            phaseHint: phase.family == .departure ? .climb : .descent
        )

        let waypoints: [FlightWaypoint]
        switch phase.family {
        case .surface, .departure:
            waypoints = [runway, aircraftPoint, outerFix]
        case .arrival, .recovery:
            waypoints = [outerFix, aircraftPoint, runway]
        case .enroute:
            waypoints = [outerFix, aircraftPoint]
        }

        return FlightRoute(
            name: "\(origin)-\(destination)",
            activeWaypointID: aircraftPoint.id,
            waypoints: waypoints
        )
    }

    private static func waypointKind(for phase: FlightTrack.Phase) -> FlightWaypoint.Kind {
        switch phase {
        case .pushback:
            return .gate
        case .taxi, .taxiIn, .taxiOut, .lineUp, .takeoffRoll, .rollout, .landed:
            return .taxiway
        case .touchdown, .rotation:
            return .runway
        case .holding:
            return .hold
        case .goAround:
            return .vector
        default:
            return .fix
        }
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
                    for flight in SampleData.flights(for: airport, tick: tick).prefix(12) {
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
