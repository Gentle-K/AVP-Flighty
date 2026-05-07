import RealityKit
import SwiftUI
import UIKit

struct ImmersiveAirspaceView: View {
    @EnvironmentObject private var model: DigitalTowerModel
    @State private var coordinator = FlightSceneCoordinator()

    var body: some View {
        RealityView { content, attachments in
            if coordinator.root.parent == nil {
                content.add(coordinator.root)
            }
            coordinator.update(model: model)
            placeAttachments(attachments)
        } update: { _, attachments in
            coordinator.update(model: model)
            placeAttachments(attachments)
        } attachments: {
            Attachment(id: ImmersiveAttachment.status) {
                ImmersiveStatusPanel()
            }
            Attachment(id: ImmersiveAttachment.modeSwitcher) {
                ImmersiveModeSwitcher()
            }
            Attachment(id: ImmersiveAttachment.towerControls) {
                ImmersiveTowerControls()
            }
            Attachment(id: ImmersiveAttachment.flightCard) {
                ImmersiveFlightCard()
            }
            Attachment(id: ImmersiveAttachment.replayTimeline) {
                ImmersiveReplayTimeline()
            }
            Attachment(id: ImmersiveAttachment.onboarding) {
                ImmersiveOnboardingHint()
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let flightID = coordinator.flightID(from: value.entity) else { return }
                    model.selectFlight(id: flightID)
                }
        )
        .task {
            model.start()
            try? await Task.sleep(for: .seconds(7))
            model.dismissOnboardingHints()
        }
    }

    private func placeAttachments(_ attachments: RealityViewAttachments) {
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.status),
            id: .status,
            model: model
        )
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.modeSwitcher),
            id: .modeSwitcher,
            model: model
        )
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.towerControls),
            id: .towerControls,
            model: model
        )
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.flightCard),
            id: .flightCard,
            model: model
        )
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.replayTimeline),
            id: .replayTimeline,
            model: model
        )
        coordinator.place(
            attachments.entity(for: ImmersiveAttachment.onboarding),
            id: .onboarding,
            model: model
        )
    }
}

private enum ImmersiveAttachment: String, Hashable {
    case status
    case modeSwitcher
    case towerControls
    case flightCard
    case replayTimeline
    case onboarding
}

@MainActor
private final class FlightSceneCoordinator {
    let root = Entity()

    private let skyRoot = Entity()
    private let airportRoot = Entity()
    private let trafficRoot = Entity()
    private let trailRoot = Entity()
    private let weatherRoot = Entity()
    private let globeRoot = Entity()
    private let labelRoot = Entity()
    private let cinematicRoot = Entity()

    private var didInstall = false
    private var didStartCinematic = false
    private var lastAirportID: String?
    private var aircraftEntities: [String: Entity] = [:]

    private let aircraftFactory = AircraftEntityFactory()
    private let airportFactory = AirportSceneFactory()
    private let trailFactory = TrailEntityFactory()
    private let weatherFactory = WeatherLayerFactory()

    func update(model: DigitalTowerModel) {
        installIfNeeded()
        rebuildStaticSceneIfNeeded(for: model.selectedAirport)
        updateVisibility(for: model)
        syncAircraft(model: model)
        syncTrails(model: model)
        syncLabels(model: model)

        if model.isCinematicFlybyEnabled, !didStartCinematic {
            startOpeningCinematic()
        }
    }

    func place(_ entity: Entity?, id: ImmersiveAttachment, model: DigitalTowerModel) {
        guard let entity else { return }
        if entity.parent == nil {
            root.addChild(entity)
        }

        let placement = attachmentPlacement(for: id, model: model)
        entity.position = placement.position
        entity.orientation = simd_quatf(angle: placement.yaw, axis: SIMD3<Float>(0, 1, 0))
        entity.scale = SIMD3<Float>(repeating: placement.scale)
        entity.isEnabled = placement.isVisible
    }

    func flightID(from entity: Entity) -> String? {
        var current: Entity? = entity
        while let candidate = current {
            if candidate.name.hasPrefix("flight-") {
                return String(candidate.name.dropFirst("flight-".count))
            }
            current = candidate.parent
        }
        return nil
    }

    private func installIfNeeded() {
        guard !didInstall else { return }
        didInstall = true

        root.name = "Digital Tower Full Immersive Airspace"
        for child in [skyRoot, airportRoot, trailRoot, trafficRoot, weatherRoot, globeRoot, labelRoot, cinematicRoot] {
            root.addChild(child)
        }

        skyRoot.name = "Spatial Sky Dome"
        airportRoot.name = "Digital Tower Airport"
        trafficRoot.name = "Aircraft Traffic"
        trailRoot.name = "Spatial Flight Trails"
        weatherRoot.name = "Weather Atmosphere"
        globeRoot.name = "Traffic Globe"
        labelRoot.name = "Context Labels"
        cinematicRoot.name = "Opening Cinematic"

        skyRoot.addChild(AirspaceEnvironmentFactory.makeSkyEnvironment())
        globeRoot.addChild(AirspaceEnvironmentFactory.makeGlobe())
    }

    private func rebuildStaticSceneIfNeeded(for airport: Airport) {
        guard airport.id != lastAirportID else { return }
        lastAirportID = airport.id
        airportRoot.removeAllChildren()
        weatherRoot.removeAllChildren()
        airportRoot.addChild(airportFactory.makeAirportScene(for: airport))
        weatherRoot.addChild(weatherFactory.makeWeatherScene())
    }

    private func updateVisibility(for model: DigitalTowerModel) {
        let mode = model.experienceMode
        skyRoot.isEnabled = true
        airportRoot.isEnabled = mode != .globe
        trafficRoot.isEnabled = true
        trailRoot.isEnabled = mode != .globe && model.trailLength > 0.2
        weatherRoot.isEnabled = model.overlays.contains(.weather) || model.selectedWeatherLayers.contains(.stormCells) || mode == .nearbySky
        globeRoot.isEnabled = mode == .globe
        labelRoot.isEnabled = model.overlays.contains(.labels) || model.labelDensity != .minimal || model.selectedFlight != nil

        airportRoot.transform = transformForAirport(mode: mode)
        trailRoot.transform = airportRoot.transform
        trafficRoot.transform = airportRoot.transform
        weatherRoot.transform = airportRoot.transform
    }

    private func transformForAirport(mode: ExperienceMode) -> Transform {
        switch mode {
        case .skyPortal:
            return Transform(scale: SIMD3<Float>(repeating: 0.56), translation: SIMD3<Float>(0, 0.18, -1.55))
        case .digitalTower:
            return Transform(scale: SIMD3<Float>(repeating: 1), translation: SIMD3<Float>(0, 0.05, -1.35))
        case .nearbySky:
            return Transform(scale: SIMD3<Float>(repeating: 1.1), translation: SIMD3<Float>(0, 0.08, -1.1))
        case .flightChase:
            return Transform(scale: SIMD3<Float>(repeating: 0.9), translation: SIMD3<Float>(0, 0.05, -1.2))
        case .globe:
            return Transform(scale: SIMD3<Float>(repeating: 0.7), translation: SIMD3<Float>(0, 0.18, -1.55))
        case .replay:
            return Transform(scale: SIMD3<Float>(repeating: 0.9), translation: SIMD3<Float>(0, 0.05, -1.35))
        }
    }

    private func syncAircraft(model: DigitalTowerModel) {
        let flights = Array(model.flights.prefix(model.aircraftDensity.visibleLimit))
        let validIDs = Set(flights.map(\.id))
        let selectedID = model.selectedFlight?.id
        let converter = FlightSceneCoordinateConverter(
            airport: model.selectedAirport,
            preset: model.sceneScalePreset,
            verticalExaggeration: Float(model.verticalExaggeration)
        )
        let selectedBase = selectedID.flatMap { id in
            flights.first(where: { $0.id == id }).map { converter.position(for: $0) }
        }

        for id in Array(aircraftEntities.keys) where !validIDs.contains(id) {
            aircraftEntities[id]?.removeFromParent()
            aircraftEntities[id] = nil
        }

        for (index, flight) in flights.enumerated() {
            let entity = aircraftEntities[flight.id] ?? aircraftFactory.makeAircraftEntity(id: flight.id)
            if entity.parent == nil {
                trafficRoot.addChild(entity)
            }
            aircraftEntities[flight.id] = entity

            let isSelected = flight.id == selectedID
            let position = scenePosition(
                for: flight,
                index: index,
                converter: converter,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: selectedID
            )
            let scale = aircraftScale(for: flight, mode: model.experienceMode, isSelected: isSelected)
            let rotation = simd_quatf(angle: FlightSceneCoordinateConverter.headingToYaw(degrees: flight.headingDegrees), axis: SIMD3<Float>(0, 1, 0))
            let transform = Transform(scale: SIMD3<Float>(repeating: scale), rotation: rotation, translation: position)

            aircraftFactory.update(entity, flight: flight, isSelected: isSelected, isDimmed: selectedID != nil && !isSelected && model.experienceMode == .flightChase)
            entity.move(to: transform, relativeTo: trafficRoot, duration: 0.82, timingFunction: .easeInOut)
        }
    }

    private func syncTrails(model: DigitalTowerModel) {
        trailRoot.removeAllChildren()
        guard model.trailLength > 0.21 else { return }

        let converter = FlightSceneCoordinateConverter(
            airport: model.selectedAirport,
            preset: model.sceneScalePreset,
            verticalExaggeration: Float(model.verticalExaggeration)
        )
        let flights = Array(model.flights.prefix(min(model.aircraftDensity.visibleLimit, 28)))
        let selectedBase = model.selectedFlight.flatMap { selected in converter.position(for: selected) }

        for (index, flight) in flights.enumerated() {
            let position = scenePosition(
                for: flight,
                index: index,
                converter: converter,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: model.selectedFlight?.id
            )
            let trail = trailFactory.makeTrail(
                for: flight,
                from: position,
                lengthFactor: Float(model.trailLength),
                isHighlighted: model.selectedFlight?.id == flight.id || model.experienceMode == .replay
            )
            trailRoot.addChild(trail)
        }
    }

    private func syncLabels(model: DigitalTowerModel) {
        labelRoot.removeAllChildren()
        guard labelRoot.isEnabled else { return }

        let converter = FlightSceneCoordinateConverter(
            airport: model.selectedAirport,
            preset: model.sceneScalePreset,
            verticalExaggeration: Float(model.verticalExaggeration)
        )
        let selectedID = model.selectedFlight?.id
        let selectedBase = selectedID.flatMap { id in
            model.flights.first(where: { $0.id == id }).map { converter.position(for: $0) }
        }
        let limit: Int
        switch model.labelDensity {
        case .minimal:
            limit = selectedID == nil ? 0 : 1
        case .focused:
            limit = 8
        case .expanded:
            limit = 18
        }

        let labeledFlights = Array(model.flights.prefix(limit)).filter { model.labelDensity != .minimal || $0.id == selectedID }
        let selectedExtra = model.selectedFlight.map { [$0] } ?? []
        let uniqueFlights = Array((labeledFlights + selectedExtra).reduce(into: [String: FlightTrack]()) { result, flight in
            result[flight.id] = flight
        }.values)

        for (index, flight) in uniqueFlights.enumerated() {
            let isSelected = flight.id == selectedID
            let position = scenePosition(
                for: flight,
                index: index,
                converter: converter,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: selectedID
            )
            let text = isSelected ? "\(flight.callsign)\n\(flight.altitudeFeet.formatted()) ft  \(flight.speedKnots) kt" : "\(flight.callsign)\n\(flight.altitudeFeet.formatted()) ft"
            let label = AirspaceEnvironmentFactory.makeTextPanel(
                text,
                width: 0.72,
                fontSize: isSelected ? 0.043 : 0.032,
                color: isSelected ? .white : UIColor.white.withAlphaComponent(0.86),
                backing: isSelected ? UIColor.systemCyan.withAlphaComponent(0.18) : UIColor.black.withAlphaComponent(0.14)
            )
            label.position = position + SIMD3<Float>(0.07, isSelected ? 0.18 : 0.11, 0.02)
            labelRoot.addChild(label)
        }
    }

    private func scenePosition(
        for flight: FlightTrack,
        index: Int,
        converter: FlightSceneCoordinateConverter,
        selectedBase: SIMD3<Float>?,
        mode: ExperienceMode,
        selectedID: String?
    ) -> SIMD3<Float> {
        let base = converter.position(for: flight)
        switch mode {
        case .skyPortal:
            return SIMD3<Float>(base.x * 0.58, base.y * 0.72 + 0.12, base.z * 0.58)
        case .digitalTower:
            return base
        case .nearbySky:
            let offset = Float(index % 5) * 0.035
            return SIMD3<Float>(base.x * 1.08 + offset, base.y + 0.18, base.z * 1.08)
        case .flightChase:
            guard let selectedBase else { return base }
            if flight.id == selectedID {
                return SIMD3<Float>(0, 0.98, -0.42)
            }
            let relative = base - selectedBase
            return SIMD3<Float>(
                max(-2.4, min(2.4, relative.x * 0.72)),
                max(0.18, min(1.9, 0.98 + relative.y * 0.55)),
                max(-2.8, min(1.2, -0.42 + relative.z * 0.72))
            )
        case .globe:
            let latitude = Float(flight.latitude * .pi / 180)
            let longitude = Float(flight.longitude * .pi / 180)
            let radius: Float = 0.78 + Float(index % 4) * 0.025
            return SIMD3<Float>(
                cos(latitude) * sin(longitude) * radius,
                1.1 + sin(latitude) * 0.42,
                -1.55 + cos(latitude) * cos(longitude) * radius * 0.45
            )
        case .replay:
            return SIMD3<Float>(base.x, base.y, base.z)
        }
    }

    private func aircraftScale(for flight: FlightTrack, mode: ExperienceMode, isSelected: Bool) -> Float {
        if isSelected { return mode == .flightChase ? 2.4 : 1.45 }
        switch mode {
        case .skyPortal: return 0.86
        case .digitalTower: return flight.phase == .final ? 1.15 : 1
        case .nearbySky: return 1.24
        case .flightChase: return 0.78
        case .globe: return 0.55
        case .replay: return 0.95
        }
    }

    private func startOpeningCinematic() {
        didStartCinematic = true
        cinematicRoot.removeAllChildren()
        let hero = aircraftFactory.makeDetailedAircraftEntity(id: "hero-flyby")
        hero.name = "hero-cinematic-aircraft"
        hero.scale = SIMD3<Float>(repeating: 4.2)
        hero.position = SIMD3<Float>(-2.2, 1.04, -1.55)
        hero.orientation = simd_quatf(angle: .pi * 0.54, axis: SIMD3<Float>(0, 1, 0))
        aircraftFactory.updateHero(hero)
        cinematicRoot.addChild(hero)

        let title = AirspaceEnvironmentFactory.makeTextPanel(
            "Digital Tower\nFull Immersive Airspace",
            width: 1.2,
            fontSize: 0.052,
            color: .white,
            backing: UIColor.black.withAlphaComponent(0.12)
        )
        title.position = SIMD3<Float>(-0.58, 1.34, -1.18)
        cinematicRoot.addChild(title)

        let wave = AirspaceEnvironmentFactory.makeLine(
            from: SIMD3<Float>(-1.9, 0.92, -1.36),
            to: SIMD3<Float>(-0.7, 0.96, -1.2),
            thickness: 0.018,
            color: UIColor.systemCyan.withAlphaComponent(0.18),
            name: "engine-wave-placeholder"
        )
        cinematicRoot.addChild(wave)

        var target = hero.transform
        target.translation = SIMD3<Float>(2.25, 0.96, -1.05)
        target.rotation = simd_quatf(angle: .pi * 0.38, axis: SIMD3<Float>(0, 1, 0))
        hero.move(to: target, relativeTo: cinematicRoot, duration: 8.5, timingFunction: .easeInOut)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(13))
            cinematicRoot.isEnabled = false
        }
    }

    private func attachmentPlacement(for id: ImmersiveAttachment, model: DigitalTowerModel) -> (position: SIMD3<Float>, yaw: Float, scale: Float, isVisible: Bool) {
        switch id {
        case .status:
            return (SIMD3<Float>(-0.78, 1.35, -1.18), 0.10, 1, true)
        case .modeSwitcher:
            return (SIMD3<Float>(0, 0.34, -1.05), 0, 1, true)
        case .towerControls:
            return (SIMD3<Float>(0.82, 1.03, -1.25), -0.18, 1, model.experienceMode == .digitalTower)
        case .flightCard:
            return (SIMD3<Float>(0.84, 1.16, -1.18), -0.2, 1, model.selectedFlight != nil)
        case .replayTimeline:
            return (SIMD3<Float>(0, 0.58, -1.08), 0, 1, model.experienceMode == .replay)
        case .onboarding:
            return (SIMD3<Float>(0, 1.55, -1.2), 0, 1, model.shouldShowOnboardingHints)
        }
    }
}

private struct FlightSceneCoordinateConverter {
    let airport: Airport
    let preset: SceneScalePreset
    let verticalExaggeration: Float

    func position(for flight: FlightTrack) -> SIMD3<Float> {
        let originLatitudeRadians = airport.latitude * .pi / 180
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = 111_320.0 * max(0.18, cos(originLatitudeRadians))
        let eastMeters = (flight.longitude - airport.longitude) * metersPerDegreeLongitude
        let northMeters = (flight.latitude - airport.latitude) * metersPerDegreeLatitude

        var x = Float(eastMeters) / preset.horizontalMetersPerSceneMeter
        var z = -Float(northMeters) / preset.horizontalMetersPerSceneMeter
        let horizontalDistance = max(0.001, sqrt(x * x + z * z))
        if horizontalDistance > preset.distanceClamp {
            let scale = preset.distanceClamp / horizontalDistance
            x *= scale
            z *= scale
        }

        let y = max(0.04, Float(flight.altitudeFeet) / preset.feetPerSceneMeter * verticalExaggeration)
        return SIMD3<Float>(x, y, z)
    }

    static func headingToYaw(degrees: Int) -> Float {
        Float(degrees) * .pi / 180
    }
}

@MainActor
private struct AircraftEntityFactory {
    func makeDetailedAircraftEntity(id: String) -> Entity {
        let wrapper = Entity()
        wrapper.name = "flight-\(id)"

        if let asset = loadAircraftAsset() {
            asset.entity.name = "asset-airbus-a380"
            asset.entity.scale = SIMD3<Float>(repeating: asset.scale)
            asset.entity.position = SIMD3<Float>(0, 0, 0)
            wrapper.addChild(asset.entity)
        } else {
            let fallback = makeAircraftEntity(id: id)
            for child in Array(fallback.children) {
                child.removeFromParent()
                wrapper.addChild(child)
            }
        }

        let leftLight = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(0.94), roughness: 0.18, isMetallic: false)]
        )
        leftLight.name = "asset-nav-left"
        leftLight.position = SIMD3<Float>(-0.72, 0.02, -0.02)
        wrapper.addChild(leftLight)

        let rightLight = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(0.94), roughness: 0.18, isMetallic: false)]
        )
        rightLight.name = "asset-nav-right"
        rightLight.position = SIMD3<Float>(0.72, 0.02, -0.02)
        wrapper.addChild(rightLight)

        let wake = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.055, 0.03, 1.05)),
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.28), roughness: 0.7, isMetallic: false)]
        )
        wake.name = "asset-engine-wake"
        wake.position = SIMD3<Float>(0, -0.01, 0.72)
        wrapper.addChild(wake)

        wrapper.components.set(InputTargetComponent())
        wrapper.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.8, 0.52, 2.2))]))
        return wrapper
    }

    func makeAircraftEntity(id: String) -> Entity {
        let entity = Entity()
        entity.name = "flight-\(id)"

        let body = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.055, 0.055, 0.24)))
        body.name = "aircraft-fuselage"
        body.position = SIMD3<Float>(0, 0, 0)

        let nose = ModelEntity(mesh: .generateSphere(radius: 0.036))
        nose.name = "aircraft-nose"
        nose.position = SIMD3<Float>(0, 0.003, -0.125)

        let wings = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.33, 0.014, 0.055)))
        wings.name = "aircraft-wings"
        wings.position = SIMD3<Float>(0, 0, -0.015)

        let tail = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.13, 0.016, 0.04)))
        tail.name = "aircraft-tailplane"
        tail.position = SIMD3<Float>(0, 0.018, 0.11)

        let verticalTail = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.032, 0.1, 0.045)))
        verticalTail.name = "aircraft-tail"
        verticalTail.position = SIMD3<Float>(0, 0.048, 0.105)

        let leftLight = ModelEntity(mesh: .generateSphere(radius: 0.015))
        leftLight.name = "nav-left"
        leftLight.position = SIMD3<Float>(-0.18, 0, -0.02)

        let rightLight = ModelEntity(mesh: .generateSphere(radius: 0.015))
        rightLight.name = "nav-right"
        rightLight.position = SIMD3<Float>(0.18, 0, -0.02)

        let contrail = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.028, 0.018, 0.62)))
        contrail.name = "aircraft-contrail"
        contrail.position = SIMD3<Float>(0, 0, 0.42)

        for child in [body, nose, wings, tail, verticalTail, leftLight, rightLight, contrail] {
            entity.addChild(child)
        }

        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.42, 0.18, 0.9))]))
        return entity
    }

    func update(_ entity: Entity, flight: FlightTrack, isSelected: Bool, isDimmed: Bool) {
        let tint = tintColor(for: flight, isSelected: isSelected)
        let alpha: CGFloat = isDimmed ? 0.28 : 0.92
        let bodyMaterial = SimpleMaterial(color: tint.withAlphaComponent(alpha), roughness: 0.32, isMetallic: true)
        let wingMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(isDimmed ? 0.25 : 0.84), roughness: 0.28, isMetallic: true)
        let trailMaterial = SimpleMaterial(color: tint.withAlphaComponent(isDimmed ? 0.06 : 0.24), roughness: 0.62, isMetallic: false)

        for child in entity.children {
            guard let model = child as? ModelEntity else { continue }
            switch child.name {
            case "aircraft-fuselage", "aircraft-nose":
                model.model?.materials = [bodyMaterial]
            case "nav-left":
                model.model?.materials = [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(alpha), roughness: 0.2, isMetallic: false)]
            case "nav-right":
                model.model?.materials = [SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(alpha), roughness: 0.2, isMetallic: false)]
            case "aircraft-contrail":
                model.model?.materials = [trailMaterial]
            default:
                model.model?.materials = [wingMaterial]
            }
        }
    }

    func updateHero(_ entity: Entity) {
        for child in Array(entity.children) {
            guard let model = child as? ModelEntity else { continue }
            if child.name == "aircraft-contrail" {
                model.model?.materials = [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.34), roughness: 0.6, isMetallic: false)]
            } else if child.name.contains("nav") {
                model.model?.materials = [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.92), roughness: 0.2, isMetallic: false)]
            } else {
                model.model?.materials = [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.96), roughness: 0.22, isMetallic: true)]
            }
        }
    }

    private func loadAircraftAsset() -> (entity: Entity, scale: Float)? {
        if let glbURL = Bundle.main.url(forResource: "airbus_a380full_interior_hd", withExtension: "glb"),
           let entity = try? Entity.load(contentsOf: glbURL) {
            return (entity, 0.012)
        }

        if let glbURL = Bundle.main.url(forResource: "airbus_a380full_interior_hd", withExtension: "glb", subdirectory: "Models"),
           let entity = try? Entity.load(contentsOf: glbURL) {
            return (entity, 0.012)
        }

        if let usdzURL = Bundle.main.url(forResource: "A380ExteriorLite", withExtension: "usdz"),
           let entity = try? Entity.load(contentsOf: usdzURL) {
            return (entity, 0.84)
        }

        if let usdzURL = Bundle.main.url(forResource: "A380ExteriorLite", withExtension: "usdz", subdirectory: "Models"),
           let entity = try? Entity.load(contentsOf: usdzURL) {
            return (entity, 0.84)
        }

        return nil
    }

    private func tintColor(for flight: FlightTrack, isSelected: Bool) -> UIColor {
        if isSelected { return .white }
        switch flight.category {
        case .cargo:
            return .systemYellow
        case .privateJet:
            return .systemPurple
        case .commercial:
            let palette: [UIColor] = [.systemCyan, .systemGreen, .systemOrange, .systemBlue]
            return palette[abs(flight.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % palette.count]
        case .unknown:
            return .systemBlue
        }
    }
}

@MainActor
private struct TrailEntityFactory {
    func makeTrail(for flight: FlightTrack, from position: SIMD3<Float>, lengthFactor: Float, isHighlighted: Bool) -> Entity {
        let group = Entity()
        group.name = "trail-\(flight.id)"

        let yaw = FlightSceneCoordinateConverter.headingToYaw(degrees: flight.headingDegrees)
        let behind = SIMD3<Float>(-sin(yaw), -0.02, cos(yaw))
        let color = (isHighlighted ? UIColor.white : UIColor.systemCyan).withAlphaComponent(isHighlighted ? 0.38 : 0.18)
        let segmentCount = isHighlighted ? 5 : 3

        for segment in 0..<segmentCount {
            let startDistance = Float(segment) * 0.18 * lengthFactor
            let endDistance = startDistance + 0.14 * lengthFactor
            let from = position + behind * startDistance
            let to = position + behind * endDistance + SIMD3<Float>(0, -Float(segment) * 0.01, 0)
            group.addChild(AirspaceEnvironmentFactory.makeLine(from: from, to: to, thickness: isHighlighted ? 0.014 : 0.009, color: color, name: "trail-segment"))
        }

        return group
    }
}

@MainActor
private struct AirportSceneFactory {
    func makeAirportScene(for airport: Airport) -> Entity {
        let group = Entity()
        group.name = "airport-\(airport.icao)"

        let ground = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(3.2, 0.018, 1.85)),
            materials: [SimpleMaterial(color: UIColor(red: 0.05, green: 0.14, blue: 0.11, alpha: 0.72), roughness: 0.82, isMetallic: false)]
        )
        ground.name = "airport-ground"
        ground.position = SIMD3<Float>(0, -0.035, 0)
        group.addChild(ground)

        let towerBase = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.12, 0.56, 0.12)),
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.2), roughness: 0.4, isMetallic: true)]
        )
        towerBase.position = SIMD3<Float>(-1.25, 0.25, 0.55)
        group.addChild(towerBase)

        let towerCab = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.38, 0.16, 0.26)),
            materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.34), roughness: 0.22, isMetallic: true)]
        )
        towerCab.position = SIMD3<Float>(-1.25, 0.6, 0.55)
        group.addChild(towerCab)

        for (index, runway) in airport.runways.prefix(4).enumerated() {
            let x = -0.54 + Float(index % 2) * 1.05
            let z = -0.48 + Float(index / 2) * 0.65
            let angle = index.isMultiple(of: 2) ? Float.pi / 9 : -Float.pi / 7
            let runwayEntity = makeRunway(id: runway.id, position: SIMD3<Float>(x, 0, z), angle: angle, isActive: runway.status == .active)
            group.addChild(runwayEntity)
        }

        group.addChild(makeTrafficCorridors())
        group.addChild(makeAltitudeRings())
        return group
    }

    private func makeRunway(id: String, position: SIMD3<Float>, angle: Float, isActive: Bool) -> Entity {
        let group = Entity()
        group.position = position
        group.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

        let runway = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.12, 0.014, 1.38)),
            materials: [SimpleMaterial(color: UIColor(white: 0.06, alpha: 0.92), roughness: 0.7, isMetallic: false)]
        )
        group.addChild(runway)

        for marker in 0..<7 {
            let stripe = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.07, 0.018, 0.06)),
                materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.76), roughness: 0.4, isMetallic: false)]
            )
            stripe.position = SIMD3<Float>(0, 0.014, -0.48 + Float(marker) * 0.16)
            group.addChild(stripe)
        }

        for light in 0..<16 {
            let z = -0.66 + Float(light) * 0.088
            for side: Float in [-0.085, 0.085] {
                let beacon = ModelEntity(
                    mesh: .generateSphere(radius: 0.012),
                    materials: [SimpleMaterial(color: (isActive ? UIColor.systemGreen : UIColor.systemYellow).withAlphaComponent(0.78), roughness: 0.2, isMetallic: false)]
                )
                beacon.position = SIMD3<Float>(side, 0.025, z)
                group.addChild(beacon)
            }
        }

        let text = AirspaceEnvironmentFactory.makeText(id, size: 0.032, color: UIColor.white.withAlphaComponent(0.7), width: 0.32)
        text.position = SIMD3<Float>(-0.18, 0.035, -0.04)
        text.orientation = simd_quatf(angle: -angle, axis: SIMD3<Float>(0, 1, 0))
        group.addChild(text)
        return group
    }

    private func makeTrafficCorridors() -> Entity {
        let group = Entity()
        group.name = "approach-and-departure-corridors"
        let arrivals = [
            (SIMD3<Float>(-1.45, 0.62, -1.65), SIMD3<Float>(-0.42, 0.08, -0.42)),
            (SIMD3<Float>(1.35, 0.7, -1.55), SIMD3<Float>(0.48, 0.08, -0.18))
        ]
        let departures = [
            (SIMD3<Float>(-0.48, 0.08, 0.22), SIMD3<Float>(-1.6, 0.84, 1.6)),
            (SIMD3<Float>(0.54, 0.08, 0.36), SIMD3<Float>(1.65, 0.9, 1.45))
        ]

        for pair in arrivals {
            group.addChild(AirspaceEnvironmentFactory.makeLine(from: pair.0, to: pair.1, thickness: 0.018, color: UIColor.systemGreen.withAlphaComponent(0.24), name: "arrival-corridor"))
        }

        for pair in departures {
            group.addChild(AirspaceEnvironmentFactory.makeLine(from: pair.0, to: pair.1, thickness: 0.018, color: UIColor.systemBlue.withAlphaComponent(0.24), name: "departure-corridor"))
        }

        return group
    }

    private func makeAltitudeRings() -> Entity {
        let group = Entity()
        group.name = "altitude-rings"
        for index in 0..<4 {
            let y = 0.3 + Float(index) * 0.28
            let radius = 0.78 + Float(index) * 0.38
            var previous: SIMD3<Float>?
            for step in 0...40 {
                let angle = Float(step) / 40 * Float.pi * 2
                let current = SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
                if let previous {
                    group.addChild(AirspaceEnvironmentFactory.makeLine(from: previous, to: current, thickness: 0.004, color: UIColor.white.withAlphaComponent(0.08), name: "altitude-ring"))
                }
                previous = current
            }
        }
        return group
    }
}

@MainActor
private struct WeatherLayerFactory {
    func makeWeatherScene() -> Entity {
        let group = Entity()
        group.name = "weather-layers"
        let colors: [UIColor] = [.systemGreen, .systemYellow, .systemOrange, .systemRed]
        for index in 0..<9 {
            let cell = ModelEntity(
                mesh: .generateSphere(radius: 0.18 + Float(index % 3) * 0.06),
                materials: [SimpleMaterial(color: colors[index % colors.count].withAlphaComponent(0.13), roughness: 0.86, isMetallic: false)]
            )
            cell.position = SIMD3<Float>(-1.15 + Float(index % 3) * 0.55, 0.42 + Float(index / 3) * 0.24, -1.05 + Float(index / 3) * 0.38)
            cell.scale = SIMD3<Float>(1.6, 0.36, 0.78)
            group.addChild(cell)
        }
        return group
    }
}

@MainActor
private enum AirspaceEnvironmentFactory {
    static func makeSkyEnvironment() -> Entity {
        let group = Entity()
        group.name = "sky-horizon-environment"

        let dome = ModelEntity(
            mesh: .generateSphere(radius: 5.4),
            materials: [SimpleMaterial(color: UIColor(red: 0.03, green: 0.13, blue: 0.22, alpha: 0.26), roughness: 1, isMetallic: false)]
        )
        dome.position = SIMD3<Float>(0, 1.05, 0)
        dome.scale = SIMD3<Float>(1, 0.46, 1)
        group.addChild(dome)

        for index in 0..<36 {
            let angleA = Float(index) / 36 * Float.pi * 2
            let angleB = Float(index + 1) / 36 * Float.pi * 2
            let radius: Float = 4.4
            let a = SIMD3<Float>(cos(angleA) * radius, -0.16, sin(angleA) * radius)
            let b = SIMD3<Float>(cos(angleB) * radius, -0.16, sin(angleB) * radius)
            group.addChild(makeLine(from: a, to: b, thickness: 0.01, color: UIColor.white.withAlphaComponent(0.16), name: "curved-horizon"))
        }

        for index in 0..<14 {
            let cloud = ModelEntity(
                mesh: .generateSphere(radius: 0.22 + Float(index % 4) * 0.03),
                materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.10), roughness: 1, isMetallic: false)]
            )
            let angle = Float(index) / 14 * Float.pi * 2
            cloud.position = SIMD3<Float>(cos(angle) * 2.8, 0.82 + Float(index % 3) * 0.18, sin(angle) * 2.3 - 0.55)
            cloud.scale = SIMD3<Float>(2.0, 0.24, 0.75)
            group.addChild(cloud)
        }

        for index in 0..<22 {
            let glow = ModelEntity(
                mesh: .generateSphere(radius: 0.018 + Float(index % 3) * 0.007),
                materials: [SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.42), roughness: 0.4, isMetallic: false)]
            )
            let angle = Float(index) / 22 * Float.pi * 2
            glow.position = SIMD3<Float>(cos(angle) * 3.4, -0.1 + Float(index % 2) * 0.04, sin(angle) * 3.4)
            group.addChild(glow)
        }

        return group
    }

    static func makeGlobe() -> Entity {
        let group = Entity()
        group.name = "regional-traffic-globe"
        group.position = SIMD3<Float>(0, 0.06, 0)

        let earth = ModelEntity(
            mesh: .generateSphere(radius: 0.62),
            materials: [SimpleMaterial(color: UIColor(red: 0.03, green: 0.27, blue: 0.35, alpha: 0.88), roughness: 0.66, isMetallic: false)]
        )
        earth.position = SIMD3<Float>(0, 1.05, -1.55)
        group.addChild(earth)

        for (index, airport) in AirportCatalog.airports.enumerated() {
            let lat = Float(airport.latitude * .pi / 180)
            let lon = Float(airport.longitude * .pi / 180)
            let point = SIMD3<Float>(
                cos(lat) * sin(lon) * 0.68,
                1.05 + sin(lat) * 0.38,
                -1.55 + cos(lat) * cos(lon) * 0.32
            )
            let node = ModelEntity(
                mesh: .generateSphere(radius: index == 0 ? 0.032 : 0.022),
                materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.86), roughness: 0.3, isMetallic: false)]
            )
            node.position = point
            group.addChild(node)

            if index > 0 {
                group.addChild(makeLine(from: SIMD3<Float>(0, 1.08, -1.55), to: point, thickness: 0.006, color: UIColor.systemCyan.withAlphaComponent(0.22), name: "global-traffic-arc"))
            }
        }

        return group
    }

    static func makeLine(from: SIMD3<Float>, to: SIMD3<Float>, thickness: Float, color: UIColor, name: String) -> Entity {
        let direction = to - from
        let length = max(0.001, simd_length(direction))
        let line = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(thickness, thickness, length)),
            materials: [SimpleMaterial(color: color, roughness: 0.72, isMetallic: false)]
        )
        line.name = name
        line.position = (from + to) / 2
        line.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction / length)
        return line
    }

    static func makeText(_ text: String, size: CGFloat, color: UIColor, width: CGFloat) -> ModelEntity {
        ModelEntity(
            mesh: .generateText(
                text,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: size, weight: .semibold),
                containerFrame: CGRect(x: -width / 2, y: -0.08, width: width, height: 0.18),
                alignment: .center,
                lineBreakMode: .byWordWrapping
            ),
            materials: [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
        )
    }

    static func makeTextPanel(_ text: String, width: Float, fontSize: CGFloat, color: UIColor, backing: UIColor) -> Entity {
        let group = Entity()
        let lines = max(1, text.split(separator: "\n").count)
        let height = Float(lines) * 0.09 + 0.08
        let panel = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(width, height, 0.012)),
            materials: [SimpleMaterial(color: backing, roughness: 0.55, isMetallic: false)]
        )
        panel.position = SIMD3<Float>(0, 0, -0.008)
        group.addChild(panel)

        let textEntity = makeText(text, size: fontSize, color: color, width: CGFloat(width - 0.06))
        textEntity.position = SIMD3<Float>(0, -height * 0.28, 0.004)
        group.addChild(textEntity)
        return group
    }
}

@MainActor
private extension Entity {
    func removeAllChildren() {
        for child in Array(children) {
            child.removeFromParent()
        }
    }
}

private extension FlightTrack {
    var shortSummary: String {
        "\(origin) to \(destination) - \(aircraft)"
    }
}

private struct ImmersiveStatusPanel: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "visionpro.fill")
                    .foregroundStyle(.cyan)
                Text("Digital Tower")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(model.selectedAirport.iata)
                    .font(.system(size: 18, weight: .semibold))
                    .monoMetric()
            }
            Text(model.experienceMode.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DTColors.secondaryText)
            Text("\(model.flights.count) aircraft - \(model.connectionStatusTitle) - discovery only")
                .font(.caption2)
                .foregroundStyle(DTColors.faintText)
        }
        .foregroundStyle(.white)
        .frame(width: 300, alignment: .leading)
        .glassSurface(cornerRadius: 20, padding: 14)
    }
}

private struct ImmersiveModeSwitcher: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ExperienceMode.allCases) { mode in
                Button {
                    model.setExperienceMode(mode)
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 34)
                }
                .buttonStyle(TileButtonStyle(isSelected: model.experienceMode == mode))
                .help(mode.title)
            }
        }
        .glassSurface(cornerRadius: 24, padding: 8)
    }
}

private struct ImmersiveTowerControls: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tower View")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DTColors.secondaryText)
            ForEach(TowerViewpoint.allCases) { viewpoint in
                Button {
                    model.setTowerViewpoint(viewpoint)
                } label: {
                    Label(viewpoint.title, systemImage: viewpoint.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PillButtonStyle(isSelected: model.selectedTowerViewpoint == viewpoint))
            }
        }
        .frame(width: 210)
        .foregroundStyle(.white)
        .glassSurface(cornerRadius: 22, padding: 12)
    }
}

private struct ImmersiveFlightCard: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        Group {
            if let flight = model.selectedFlight {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "airplane")
                            .foregroundStyle(.cyan)
                        Text(flight.callsign)
                            .font(.system(size: 21, weight: .semibold))
                        Spacer()
                    }
                    Text(flight.shortSummary)
                        .font(.caption)
                        .foregroundStyle(DTColors.secondaryText)
                    DividerLine()
                    detailRow("Altitude", "\(flight.altitudeFeet.formatted()) ft")
                    detailRow("Speed", "\(flight.speedKnots) kt")
                    detailRow("Heading", "\(flight.headingDegrees) degrees")
                    detailRow("Vertical", "\(flight.verticalRateFeet) ft/min")
                    Text("Discovery only. Not for navigation or operational control.")
                        .font(.caption2)
                        .foregroundStyle(DTColors.faintText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 300)
                .foregroundStyle(.white)
                .glassSurface(cornerRadius: 24, padding: 16)
            } else {
                EmptyView()
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DTColors.secondaryText)
            Spacer()
            Text(value)
                .monoMetric()
        }
        .font(.caption)
    }
}

private struct ImmersiveReplayTimeline: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleReplayPlayback()
            } label: {
                Image(systemName: model.isReplayPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(TileButtonStyle(isSelected: model.isReplayPlaying))

            Slider(value: $model.replayProgress, in: 0...1)
                .frame(width: 240)

            Button(model.playbackSpeed) {
                model.cyclePlaybackSpeed()
            }
            .buttonStyle(PillButtonStyle(isSelected: true))
        }
        .glassSurface(cornerRadius: 22, padding: 10)
    }
}

private struct ImmersiveOnboardingHint: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.cyan)
            Text("Tap an aircraft to inspect. Use the mode rail below to move between tower, nearby sky, chase, globe, and replay.")
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .frame(width: 420)
        .glassSurface(cornerRadius: 22, padding: 14)
    }
}
