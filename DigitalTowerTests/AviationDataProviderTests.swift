import XCTest
@testable import DigitalTower

final class AviationDataProviderTests: XCTestCase {
    func testDecodesFlightUpsertEvent() throws {
        let json = """
        {
          "flight": {
            "id": "DTX1",
            "callsign": "DTX1",
            "airline": "Digital Tower",
            "aircraft": "A320",
            "registration": "N100DT",
            "category": "Commercial",
            "origin": "BOS",
            "destination": "JFK",
            "latitude": 40.70,
            "longitude": -73.80,
            "altitudeFeet": 3200,
            "speedKnots": 210,
            "headingDegrees": 180,
            "verticalRateFeet": -600,
            "phase": "Final",
            "progress": 0.82,
            "updatedAt": "2026-05-05T05:24:00Z"
          }
        }
        """

        let event = try AviationDataEvent.decode(named: "flight.upsert", data: Data(json.utf8))

        guard case .flightUpsert(let flight) = event else {
            return XCTFail("Expected flight upsert event")
        }
        XCTAssertEqual(flight.callsign, "DTX1")
        XCTAssertEqual(flight.destination, "JFK")
    }

    func testServerSentEventParserEmitsOnBlankLine() throws {
        var parser = ServerSentEventParser()
        XCTAssertNil(try parser.consume("event: alert.delete"))
        XCTAssertNil(try parser.consume("data: {\"id\":\"alert-1\"}"))
        let event = try parser.consume("")

        XCTAssertEqual(event, .alertDelete("alert-1"))
    }

    func testUnavailableProviderDoesNotReturnSampleData() async {
        let provider = UnavailableAviationDataProvider(message: "Missing config")

        do {
            _ = try await provider.bootstrap(airportCode: "KJFK")
            XCTFail("Expected provider to fail without config")
        } catch {
            XCTAssertEqual((error as? AviationDataError), .unavailable("Missing config"))
        }
    }
}
