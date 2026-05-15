import RealityKit
import UIKit
import simd

@MainActor
struct AircraftModelFactory {
    private let resolver: AircraftAssetResolver

    init(resolver: AircraftAssetResolver = .shared) {
        self.resolver = resolver
    }

    func makeAircraftEntity(for flight: FlightTrack) -> Entity? {
        makeAircraftEntity(id: flight.id)
    }

    func makeAircraftEntity(id: String) -> Entity? {
        let entity = Entity()
        entity.name = "Aircraft_\(id)"

        if let asset = resolver.makeAircraftClone() {
            entity.addChild(asset)
        } else {
            return nil
        }

        addAircraftEffects(to: entity)
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.3, 0.12, 0.3))]))
        return entity
    }

    func update(_ entity: Entity, flight: FlightTrack, isSelected: Bool, isDimmed: Bool) {
        let alpha: CGFloat = isDimmed ? 0.26 : 0.92

        for child in entity.children {
            guard let model = child as? ModelEntity else { continue }
            switch child.name {
            case "asset-nav-left":
                model.model?.materials = [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(alpha), roughness: 0.2, isMetallic: false)]
            case "asset-nav-right":
                model.model?.materials = [SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(alpha), roughness: 0.2, isMetallic: false)]
            default:
                break
            }
        }
    }

    private func addAircraftEffects(to entity: Entity) {
        let leftLight = ModelEntity(
            mesh: .generateSphere(radius: 0.005),
            materials: [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(0.94), roughness: 0.18, isMetallic: false)]
        )
        leftLight.name = "asset-nav-left"
        leftLight.position = SIMD3<Float>(-0.11, 0.006, -0.01)
        entity.addChild(leftLight)

        let rightLight = ModelEntity(
            mesh: .generateSphere(radius: 0.005),
            materials: [SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(0.94), roughness: 0.18, isMetallic: false)]
        )
        rightLight.name = "asset-nav-right"
        rightLight.position = SIMD3<Float>(0.11, 0.006, -0.01)
        entity.addChild(rightLight)

    }
}
