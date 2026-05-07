import XCTest
@testable import DigitalTower

@MainActor
final class DigitalTowerModelTests: XCTestCase {
    func testDebugSampleProviderLoadsAndSearchesFlights() async throws {
        let model = DigitalTowerModel(provider: SampleAviationDataProvider(latency: .milliseconds(1)))
        model.start()
        try await waitForFlights(in: model)

        XCTAssertFalse(model.flights.isEmpty)
        XCTAssertFalse(model.isAuthorizedLiveData)

        model.searchText = "DTX"
        XCTAssertTrue(model.searchResults.contains { result in
            if case .flight(let flight) = result {
                return flight.callsign == "DTX2468"
            }
            return false
        })
    }

    func testAirportSwitchClearsSelectedFlightAndLoadsNewAirport() async throws {
        let model = DigitalTowerModel(provider: SampleAviationDataProvider(latency: .milliseconds(1)))
        model.start()
        try await waitForFlights(in: model)

        let flight = try XCTUnwrap(model.flights.first)
        model.selectFlight(flight)
        XCTAssertNotNil(model.selectedFlight)

        let nextAirport = try XCTUnwrap(model.availableAirports.first { $0.icao == "KLAX" })
        model.loadAirport(nextAirport)
        XCTAssertNil(model.selectedFlight)
        try await waitForFlights(in: model)

        XCTAssertEqual(model.selectedAirport.icao, "KLAX")
    }

    func testReleaseGateBlocksWithoutAuthorizedData() {
        let context = AppContext.empty(airport: AirportCatalog.fallbackAirport, isAuthorizedLiveData: false)
        let result = FinalReleaseReviewAgent().review(context: context)

        XCTAssertEqual(result.state, .blocked)
        XCTAssertTrue(result.issues.contains { $0.id == "authorized-live-data" })
    }

    private func waitForFlights(
        in model: DigitalTowerModel,
        timeout: Duration = .seconds(2),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while model.flights.isEmpty && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(model.flights.isEmpty, "Expected sample flights to load before timeout.", file: file, line: line)
    }
}
