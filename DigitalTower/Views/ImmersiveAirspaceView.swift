import RealityKit
import SwiftUI
import UIKit

struct ImmersiveAirspaceView: View {
    @EnvironmentObject private var model: DigitalTowerModel

    private let maxDetailedAircraft = 300

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "Digital Tower Scene"
            root.addChild(makeRunwayGroup())
            root.addChild(makeAircraftGroup())
            root.addChild(makeWeatherVolume())
            root.addChild(makeSafetyNotice())
            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "Digital Tower Scene" }) else { return }
            root.findEntity(named: "Weather Volume")?.isEnabled = model.mode == .weather || model.overlays.contains(.weather)
            root.findEntity(named: "Runway Group")?.isEnabled = model.mode == .tower || model.overlays.contains(.runways)

            if let aircraftGroup = root.findEntity(named: "Aircraft Group") {
                syncAircraft(in: aircraftGroup)
            }
        }
    }

    private func makeRunwayGroup() -> Entity {
        let group = Entity()
        group.name = "Runway Group"

        let runwayMaterial = SimpleMaterial(color: .init(white: 0.08, alpha: 0.86), roughness: 0.7, isMetallic: false)
        let stripeMaterial = SimpleMaterial(color: .init(white: 0.9, alpha: 0.8), roughness: 0.4, isMetallic: false)

        for index in 0..<3 {
            let runway = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.08, 0.006, 1.9)), materials: [runwayMaterial])
            runway.position = SIMD3<Float>(Float(index - 1) * 0.42, -0.45, -1.8 + Float(index) * 0.14)
            runway.orientation = simd_quatf(angle: Float.pi / 9 * Float(index - 1), axis: SIMD3<Float>(0, 1, 0))
            group.addChild(runway)

            for markerIndex in 0..<5 {
                let stripe = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.052, 0.008, 0.09)), materials: [stripeMaterial])
                stripe.position = SIMD3<Float>(0, 0.008, -0.62 + Float(markerIndex) * 0.28)
                runway.addChild(stripe)
            }
        }

        return group
    }

    private func makeAircraftGroup() -> Entity {
        let group = Entity()
        group.name = "Aircraft Group"
        return group
    }

    private func syncAircraft(in group: Entity) {
        let visibleFlights = Array(model.flights.prefix(maxDetailedAircraft))
        let validNames = Set(visibleFlights.map { entityName(for: $0) })

        for child in Array(group.children) where child.name.hasPrefix("flight-") && !validNames.contains(child.name) {
            child.removeFromParent()
        }

        for (index, flight) in visibleFlights.enumerated() {
            let name = entityName(for: flight)
            let entity = group.findEntity(named: name) ?? makeAircraftEntity()
            entity.name = name
            updateAircraft(entity, flight: flight, index: index)
            if entity.parent == nil {
                group.addChild(entity)
            }
        }

        updateAggregateMarker(in: group, hiddenCount: max(0, model.flights.count - maxDetailedAircraft))
    }

    private func makeAircraftEntity() -> Entity {
        let entity = Entity()

        let fuselage = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.04, 0.04, 0.18)))
        fuselage.name = "detail-fuselage"
        let wings = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.22, 0.012, 0.05)))
        wings.name = "detail-wings"
        let tail = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.09, 0.014, 0.035)))
        tail.name = "detail-tail"
        tail.position = SIMD3<Float>(0, 0.016, 0.075)
        let symbol = ModelEntity(mesh: .generateSphere(radius: 0.032))
        symbol.name = "symbol"
        symbol.isEnabled = false

        entity.addChild(fuselage)
        entity.addChild(wings)
        entity.addChild(tail)
        entity.addChild(symbol)

        let trail = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.012, 0.012, 0.54)))
        trail.name = "trail"
        trail.position = SIMD3<Float>(0, 0, 0.34)
        entity.addChild(trail)
        return entity
    }

    private func updateAircraft(_ entity: Entity, flight: FlightTrack, index: Int) {
        let tint = tintColor(for: flight)
        let bodyMaterial = SimpleMaterial(color: tint.withAlphaComponent(0.88), roughness: 0.38, isMetallic: true)
        let wingMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.86), roughness: 0.32, isMetallic: true)
        let trailMaterial = SimpleMaterial(color: tint.withAlphaComponent(0.30), roughness: 0.5, isMetallic: false)

        entity.position = position(for: flight, index: index)
        entity.orientation = simd_quatf(angle: Float(flight.headingDegrees) * .pi / 180, axis: SIMD3<Float>(0, 1, 0))
        entity.scale = model.selectedFlight?.id == flight.id ? SIMD3<Float>(repeating: 1.32) : SIMD3<Float>(repeating: 1)

        let useSymbolLOD = index >= 100
        for child in entity.children {
            if child.name.hasPrefix("detail") {
                child.isEnabled = !useSymbolLOD
            } else if child.name == "symbol" {
                child.isEnabled = useSymbolLOD
            }

            if let modelChild = child as? ModelEntity {
                if child.name == "detail-fuselage" || child.name == "symbol" {
                    modelChild.model?.materials = [bodyMaterial]
                } else if child.name == "trail" {
                    modelChild.model?.materials = [trailMaterial]
                } else {
                    modelChild.model?.materials = [wingMaterial]
                }
            }
        }
    }

    private func updateAggregateMarker(in group: Entity, hiddenCount: Int) {
        let name = "Aggregate Traffic"
        let aggregate = group.findEntity(named: name) ?? {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.08),
                materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.28), roughness: 0.6, isMetallic: false)]
            )
            marker.name = name
            group.addChild(marker)
            return marker
        }()

        aggregate.isEnabled = hiddenCount > 0
        aggregate.position = SIMD3<Float>(0.58, 0.42, -2.2)
        let scale = Float(min(3.0, 1.0 + Double(hiddenCount) / 500.0))
        aggregate.scale = SIMD3<Float>(repeating: scale)
    }

    private func makeWeatherVolume() -> Entity {
        let volume = Entity()
        volume.name = "Weather Volume"

        let colors: [UIColor] = [.systemGreen, .systemYellow, .systemOrange, .systemRed]
        for index in 0..<4 {
            let cell = ModelEntity(
                mesh: .generateSphere(radius: 0.18 + Float(index) * 0.035),
                materials: [SimpleMaterial(color: colors[index].withAlphaComponent(0.22), roughness: 0.8, isMetallic: false)]
            )
            cell.position = SIMD3<Float>(-0.45 + Float(index) * 0.26, 0.22 + Float(index) * 0.06, -1.8 - Float(index) * 0.12)
            volume.addChild(cell)
        }

        volume.isEnabled = false
        return volume
    }

    private func makeSafetyNotice() -> Entity {
        let material = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.78), roughness: 0.6, isMetallic: false)
        let text = ModelEntity(
            mesh: .generateText(
                "Discovery only - not for navigation, ATC, flight safety, or operations",
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.035, weight: .semibold),
                containerFrame: CGRect(x: -0.7, y: -0.08, width: 1.4, height: 0.16),
                alignment: .center,
                lineBreakMode: .byWordWrapping
            ),
            materials: [material]
        )
        text.name = "Safety Notice"
        text.position = SIMD3<Float>(-0.68, -0.18, -1.05)
        return text
    }

    private func position(for flight: FlightTrack, index: Int) -> SIMD3<Float> {
        let dx = Float((flight.longitude - model.selectedAirport.longitude) * 18)
        let dz = Float((flight.latitude - model.selectedAirport.latitude) * -18)
        let y = max(0.04, min(1.2, Float(flight.altitudeFeet) / 24_000))
        let densityOffset = Float(index % 9) * 0.012
        return SIMD3<Float>(dx + densityOffset, y - 0.45, -1.55 + dz)
    }

    private func tintColor(for flight: FlightTrack) -> UIColor {
        if model.selectedFlight?.id == flight.id {
            return .white
        }

        switch flight.category {
        case .cargo:
            return .systemYellow
        case .privateJet:
            return .systemPurple
        case .commercial:
            let palette: [UIColor] = [.systemCyan, .systemGreen, .systemOrange, .systemBlue]
            return palette[stableIndex(for: flight.id, modulo: palette.count)]
        case .unknown:
            return .systemBlue
        }
    }

    private func entityName(for flight: FlightTrack) -> String {
        "flight-\(flight.id)"
    }

    private func stableIndex(for value: String, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        let total = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return abs(total) % modulo
    }
}
