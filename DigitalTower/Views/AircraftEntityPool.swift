import RealityKit

@MainActor
final class AircraftEntityPool {
    private var aircraftEntities: [String: Entity] = [:]
    private let factory: AircraftModelFactory

    init(factory: AircraftModelFactory) {
        self.factory = factory
    }

    func entity(for flight: FlightTrack) -> Entity? {
        if let entity = aircraftEntities[flight.id] {
            return entity
        }
        guard let entity = factory.makeAircraftEntity(for: flight) else {
            return nil
        }
        aircraftEntities[flight.id] = entity
        return entity
    }

    func entity(id: String) -> Entity? {
        if let entity = aircraftEntities[id] {
            return entity
        }
        guard let entity = factory.makeAircraftEntity(id: id) else {
            return nil
        }
        aircraftEntities[id] = entity
        return entity
    }

    func removeEntities(excluding validIDs: Set<String>) {
        for id in Array(aircraftEntities.keys) where !validIDs.contains(id) {
            aircraftEntities[id]?.removeFromParent()
            aircraftEntities[id] = nil
        }
    }

    func isEntityVisible(id: String) -> Bool {
        aircraftEntities[id]?.isEnabled ?? false
    }

    func removeAll() {
        for entity in aircraftEntities.values {
            entity.removeFromParent()
        }
        aircraftEntities.removeAll()
    }
}
