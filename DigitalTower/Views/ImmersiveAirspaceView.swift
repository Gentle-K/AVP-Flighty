import RealityKit
import SwiftUI
import UIKit
import simd

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
    private let orientationTestRoot = Entity()

    private var didInstall = false
    private var didBuildOrientationTestScene = false
    private var lastAirportID: String?
    private var lastTrailSceneSignature: String?
    private var lastSpawnValidationSignature: String?
    private var trailEntities: [String: Entity] = [:]
    private var trailHistories: [String: [SIMD3<Float>]] = [:]
    private let sceneStartDate = Date()

    private let aircraftFactory = AircraftModelFactory()
    private lazy var aircraftPool = AircraftEntityPool(factory: aircraftFactory)
    private let airportFactory = AirportSceneFactory()
    private let trailFactory = TrailEntityFactory()
    private let weatherFactory = WeatherLayerFactory()
    private let routeEngine = FlightRouteEngine()

    private struct AircraftSceneUpdate {
        let flight: FlightTrack
        let entity: Entity
        let position: SIMD3<Float>
        let yaw: Float
        let scale: Float
        let isSelected: Bool
    }

    func update(model: DigitalTowerModel) {
        installIfNeeded()
        if model.isAircraftOrientationTestSceneEnabled {
            updateForOrientationTestScene()
            return
        }
        orientationTestRoot.isEnabled = false
        rebuildStaticSceneIfNeeded(for: model.selectedAirport)
        updateVisibility(for: model)
        syncAircraft(model: model)
        syncTrails(model: model)
        syncLabels(model: model)

        if !cinematicRoot.children.isEmpty {
            cinematicRoot.isEnabled = false
            cinematicRoot.removeAllChildren()
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
            if candidate.name.hasPrefix("Aircraft_") {
                return String(candidate.name.dropFirst("Aircraft_".count))
            }
            current = candidate.parent
        }
        return nil
    }

    private func installIfNeeded() {
        guard !didInstall else { return }
        didInstall = true

        root.name = "Digital Tower Full Immersive Airspace"
        for child in [skyRoot, airportRoot, trailRoot, trafficRoot, weatherRoot, globeRoot, labelRoot, cinematicRoot, orientationTestRoot] {
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
        orientationTestRoot.name = "AircraftOrientationTestScene"
        orientationTestRoot.isEnabled = false

        skyRoot.addChild(AirspaceEnvironmentFactory.makeSkyEnvironment())
        globeRoot.addChild(AirspaceEnvironmentFactory.makeGlobe())
    }

    private func rebuildStaticSceneIfNeeded(for airport: Airport) {
        guard airport.id != lastAirportID else { return }
        lastAirportID = airport.id
        airportRoot.removeAllChildren()
        weatherRoot.removeAllChildren()
        trailRoot.removeAllChildren()
        trafficRoot.removeAllChildren()
        aircraftPool.removeAll()
        trailEntities.removeAll()
        trailHistories.removeAll()
        lastTrailSceneSignature = nil
        lastSpawnValidationSignature = nil
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
        labelRoot.transform = airportRoot.transform
    }

    private func updateForOrientationTestScene() {
        skyRoot.isEnabled = true
        airportRoot.isEnabled = false
        trafficRoot.isEnabled = false
        trailRoot.isEnabled = false
        weatherRoot.isEnabled = false
        globeRoot.isEnabled = false
        labelRoot.isEnabled = false
        cinematicRoot.isEnabled = false
        orientationTestRoot.isEnabled = true

        guard !didBuildOrientationTestScene else { return }
        didBuildOrientationTestScene = true
        orientationTestRoot.removeAllChildren()
        if let scene = AircraftOrientationTestScene(factory: aircraftFactory).makeScene() {
            orientationTestRoot.addChild(scene)
        }
    }

    private func transformForAirport(mode: ExperienceMode) -> Transform {
        switch mode {
        case .skyPortal:
            return Transform(
                scale: SIMD3<Float>(repeating: 0.74),
                rotation: simd_quatf(angle: -0.22, axis: SIMD3<Float>(0, 1, 0)),
                translation: SIMD3<Float>(0, 0.24, -1.28)
            )
        case .digitalTower:
            return Transform(
                scale: SIMD3<Float>(repeating: 1.1),
                rotation: simd_quatf(angle: -0.34, axis: SIMD3<Float>(0, 1, 0)),
                translation: SIMD3<Float>(0.02, 0.38, -1.22)
            )
        case .nearbySky:
            return Transform(scale: SIMD3<Float>(repeating: 1.1), translation: SIMD3<Float>(0, 0.28, -1.1))
        case .flightChase:
            return Transform(scale: SIMD3<Float>(repeating: 0.9), translation: SIMD3<Float>(0, 0.24, -1.2))
        case .globe:
            return Transform(scale: SIMD3<Float>(repeating: 0.7), translation: SIMD3<Float>(0, 0.18, -1.55))
        case .replay:
            return Transform(scale: SIMD3<Float>(repeating: 0.95), translation: SIMD3<Float>(0, 0.28, -1.35))
        }
    }

    private func syncAircraft(model: DigitalTowerModel) {
        let flights = visibleFlights(from: model, limit: model.aircraftDensity.visibleLimit)
        let validIDs = Set(flights.map(\.id))
        let selectedID = model.selectedFlight?.id
        let elapsed = Date().timeIntervalSince(sceneStartDate)
        let selectedBase = selectedID.flatMap { id in
            flights.firstIndex { $0.id == id }.map { routeEngine.state(for: flights[$0], index: $0, elapsed: elapsed).position }
        }

        aircraftPool.removeEntities(excluding: validIDs)

        var updates: [AircraftSceneUpdate] = []
        updates.reserveCapacity(flights.count)

        for (index, flight) in flights.enumerated() {
            guard let entity = aircraftPool.entity(for: flight) else { continue }
            if entity.parent == nil {
                trafficRoot.addChild(entity)
            }

            let isSelected = flight.id == selectedID
            let routeState = routeEngine.state(for: flight, index: index, elapsed: elapsed)
            let position = scenePosition(
                for: flight,
                index: index,
                base: routeState.position,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: selectedID
            )
            let scale = aircraftScale(for: flight, mode: model.experienceMode, isSelected: isSelected)
            let yaw = model.experienceMode == .globe
                ? FlightSceneCoordinateConverter.headingToYaw(degrees: flight.headingDegrees)
                : routeState.yaw

            aircraftFactory.update(entity, flight: flight, isSelected: isSelected || flight.phase.isDemoHighlighted, isDimmed: selectedID != nil && !isSelected && model.experienceMode == .flightChase)
            updates.append(AircraftSceneUpdate(flight: flight, entity: entity, position: position, yaw: yaw, scale: scale, isSelected: isSelected))
        }

        let separatedUpdates = separatedAircraftUpdates(updates)
        let visibleIDs = Set(separatedUpdates.map { $0.flight.id })
        for update in updates {
            update.entity.isEnabled = visibleIDs.contains(update.flight.id)
        }
        validateSpawnSeparationIfNeeded(updates: separatedUpdates, model: model)

        for update in separatedUpdates {
            let transform = AircraftRuntimeTransform.makeTransform(
                position: update.position,
                yaw: update.yaw,
                scale: update.scale
            )
            update.entity.move(to: transform, relativeTo: trafficRoot, duration: 0.74, timingFunction: .easeInOut)
        }
    }

    private func separatedAircraftUpdates(_ updates: [AircraftSceneUpdate]) -> [AircraftSceneUpdate] {
        var accepted: [AircraftSceneUpdate] = []
        accepted.reserveCapacity(updates.count)

        for update in updates {
            let minimumDistance = minimumSpawnDistance(for: update)
            let isSeparated = accepted.allSatisfy { other in
                horizontalDistance(update.position, other.position) >= max(minimumDistance, minimumSpawnDistance(for: other))
            }

            if isSeparated {
                accepted.append(update)
            }
        }

        return Array(accepted.prefix(8))
    }

    private func minimumSpawnDistance(for update: AircraftSceneUpdate) -> Float {
        update.flight.phase.isRunwayCritical ? 2.0 : 1.5
    }

    private func horizontalDistance(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
        let delta = SIMD2<Float>(lhs.x - rhs.x, lhs.z - rhs.z)
        return simd_length(delta)
    }

    private func validateSpawnSeparationIfNeeded(updates: [AircraftSceneUpdate], model: DigitalTowerModel) {
        let signature = ([model.selectedAirport.id, model.experienceMode.rawValue] + updates.map { $0.flight.id }).joined(separator: "|")
        guard signature != lastSpawnValidationSignature else { return }
        lastSpawnValidationSignature = signature

        var hasOverlap = false
        for firstIndex in updates.indices {
            for secondIndex in updates.indices where secondIndex > firstIndex {
                let required = max(minimumSpawnDistance(for: updates[firstIndex]), minimumSpawnDistance(for: updates[secondIndex]))
                if horizontalDistance(updates[firstIndex].position, updates[secondIndex].position) < required {
                    hasOverlap = true
                }
            }
        }

        if hasOverlap {
            print("Spawn validation adjusted: \(updates.count) aircraft visible after overlap filtering")
        } else {
            print("Spawn validation passed: \(updates.count) aircraft, no overlaps")
        }
    }

    private func syncTrails(model: DigitalTowerModel) {
        guard model.trailLength > 0.21 else {
            for entity in trailEntities.values {
                entity.isEnabled = false
            }
            return
        }

        let flights = visibleFlights(from: model, limit: model.aircraftDensity.visibleLimit)
            .filter { aircraftPool.isEntityVisible(id: $0.id) }
        let validIDs = Set(flights.map(\.id))
        let elapsed = Date().timeIntervalSince(sceneStartDate)
        let selectedBase = model.selectedFlight.flatMap { selected in
            flights.firstIndex { $0.id == selected.id }.map { routeEngine.state(for: flights[$0], index: $0, elapsed: elapsed).position }
        }
        let sceneSignature = [
            model.selectedAirport.id,
            model.sceneScalePreset.rawValue,
            model.experienceMode.rawValue,
            String(format: "%.2f", model.verticalExaggeration),
            model.selectedFlight?.id ?? "none"
        ].joined(separator: "|")

        if lastTrailSceneSignature != sceneSignature {
            trailHistories.removeAll()
            lastTrailSceneSignature = sceneSignature
        }

        for id in Array(trailEntities.keys) where !validIDs.contains(id) {
            trailEntities[id]?.removeFromParent()
            trailEntities[id] = nil
            trailHistories[id] = nil
        }

        for (index, flight) in flights.enumerated() {
            let routeState = routeEngine.state(for: flight, index: index, elapsed: elapsed)
            let position = scenePosition(
                for: flight,
                index: index,
                base: routeState.position,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: model.selectedFlight?.id
            )
            var history = trailHistories[flight.id] ?? []
            if let last = history.last {
                if simd_distance(last, position) > 0.018 {
                    history.append(position)
                } else {
                    history[history.count - 1] = position
                }
            } else {
                history.append(position)
            }
            let maxHistory = flight.phase.trailPointLimit
            if history.count > maxHistory {
                history.removeFirst(history.count - maxHistory)
            }
            trailHistories[flight.id] = history

            let trail = trailEntities[flight.id] ?? trailFactory.makeTrailEntity(id: flight.id)
            if trail.parent == nil {
                trailRoot.addChild(trail)
            }
            trailEntities[flight.id] = trail
            trailFactory.updateTrail(
                trail,
                for: flight,
                history: history,
                futurePath: routeEngine.futureSamples(for: flight, index: index, elapsed: elapsed, count: flight.phase.futureSampleCount),
                lengthFactor: Float(model.trailLength),
                isHighlighted: model.selectedFlight?.id == flight.id || flight.phase.isDemoHighlighted || model.experienceMode == .replay,
                showFuturePath: model.selectedFlight?.id == flight.id || flight.phase.isDemoHighlighted || index < 5
            )
        }
    }

    private func syncLabels(model: DigitalTowerModel) {
        labelRoot.removeAllChildren()
        guard labelRoot.isEnabled else { return }

        let elapsed = Date().timeIntervalSince(sceneStartDate)
        let selectedID = model.selectedFlight?.id
        let visibleFlights = visibleFlights(from: model, limit: model.aircraftDensity.visibleLimit)
            .filter { aircraftPool.isEntityVisible(id: $0.id) || $0.id == selectedID }
        let selectedBase = selectedID.flatMap { id in
            visibleFlights.firstIndex { $0.id == id }.map { routeEngine.state(for: visibleFlights[$0], index: $0, elapsed: elapsed).position }
        }
        var roleLabels: [FlightTrack] = []
        var usedRoles = Set<DefaultLabelRole>()
        for flight in visibleFlights {
            guard let role = flight.phase.defaultLabelRole, !usedRoles.contains(role) else { continue }
            roleLabels.append(flight)
            usedRoles.insert(role)
        }
        let selectedExtra = model.selectedFlight.map { [$0] } ?? []
        let uniqueFlights = Array((roleLabels + selectedExtra).reduce(into: [String: FlightTrack]()) { result, flight in
            result[flight.id] = flight
        }.values)
            .filter { $0.id == selectedID || $0.phase.defaultLabelRole != nil }
            .sorted { $0.phase.priority > $1.phase.priority }
            .prefix(5)

        for (index, flight) in uniqueFlights.enumerated() {
            let isSelected = flight.id == selectedID
            let routeIndex = visibleFlights.firstIndex { $0.id == flight.id } ?? index
            let routeState = routeEngine.state(for: flight, index: routeIndex, elapsed: elapsed)
            let position = scenePosition(
                for: flight,
                index: routeIndex,
                base: routeState.position,
                selectedBase: selectedBase,
                mode: model.experienceMode,
                selectedID: selectedID
            )
            let text = "\(flight.callsign)  \(flight.phase.phaseBadge)\n\(routeState.altitudeFeet.formatted()) ft  \(routeState.speedKnots) kt"
            let label = AirspaceEnvironmentFactory.makeTextPanel(
                text,
                width: isSelected ? 0.64 : 0.48,
                fontSize: isSelected ? 0.03 : 0.024,
                color: isSelected ? .white : UIColor.white.withAlphaComponent(0.86),
                backing: flight.phase.sceneColor.withAlphaComponent(isSelected ? 0.30 : 0.22)
            )
            label.position = position + labelOffset(for: flight.phase, isSelected: isSelected)
            label.orientation = billboardYaw(for: label.position)
            labelRoot.addChild(label)
        }
    }

    private func labelOffset(for phase: FlightTrack.Phase, isSelected: Bool) -> SIMD3<Float> {
        let lift: Float = isSelected ? 0.18 : 0.13
        switch phase.defaultLabelRole {
        case .landing:
            return SIMD3<Float>(-0.34, lift, 0.03)
        case .takeoff:
            return SIMD3<Float>(0.34, lift, 0.04)
        case .holding:
            return SIMD3<Float>(-0.18, lift, 0.08)
        case .goAround:
            return SIMD3<Float>(-0.30, lift, 0.02)
        case .none:
            return SIMD3<Float>(0.22, lift, 0.04)
        }
    }

    private func scenePosition(
        for flight: FlightTrack,
        index: Int,
        base: SIMD3<Float>,
        selectedBase: SIMD3<Float>?,
        mode: ExperienceMode,
        selectedID: String?
    ) -> SIMD3<Float> {
        switch mode {
        case .skyPortal:
            return SIMD3<Float>(base.x * 0.72, base.y * 0.78 + 0.08, base.z * 0.72)
        case .digitalTower:
            return base
        case .nearbySky:
            let offset = Float(index % 5) * 0.035
            return SIMD3<Float>(base.x * 1.04 + offset, base.y + 0.12, base.z * 1.04)
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
        if isSelected { return mode == .flightChase ? 1.85 : 1.18 }
        let typeScale: Float = 1
        let phaseBoost: Float = flight.phase.isDemoHighlighted ? 1.08 : 0.82
        switch mode {
        case .skyPortal: return 0.78 * typeScale * phaseBoost
        case .digitalTower: return 0.86 * typeScale * phaseBoost
        case .nearbySky: return 1.0 * typeScale * phaseBoost
        case .flightChase: return 0.66 * typeScale
        case .globe: return 0.42 * typeScale
        case .replay: return 0.82 * typeScale * phaseBoost
        }
    }

    private func billboardYaw(for position: SIMD3<Float>) -> simd_quatf {
        let direction = SIMD3<Float>(-position.x, 0, -1.2 - position.z)
        let yaw = atan2(direction.x, direction.z) + .pi
        return simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    }

    private func visibleFlights(from model: DigitalTowerModel, limit: Int) -> [FlightTrack] {
        let targetLimit = min(max(limit, 1), 8)
        let rolePhaseGroups: [[FlightTrack.Phase]] = [
            [.finalApproach, .final, .landingFlare],
            [.takeoffRoll, .rotation, .takeoff, .initialClimb],
            [.goAround],
            [.holding]
        ]
        let backgroundPhaseGroups: [[FlightTrack.Phase]] = [
            [.descent, .downwind, .baseTurn],
            [.departureClimb, .climb],
            [.cruise],
            [.cruise]
        ]
        var selected: [FlightTrack] = []
        var usedIDs = Set<String>()

        for group in rolePhaseGroups {
            guard let flight = firstAvailableFlight(from: model.flights, phases: group, usedIDs: usedIDs) else { continue }
            selected.append(flight)
            usedIDs.insert(flight.id)
        }

        if let selectedFlight = model.selectedFlight, !usedIDs.contains(selectedFlight.id) {
            selected.insert(selectedFlight, at: 0)
            usedIDs.insert(selectedFlight.id)
        }

        for group in backgroundPhaseGroups where selected.count < targetLimit {
            guard let flight = firstAvailableFlight(from: model.flights, phases: group, usedIDs: usedIDs) else { continue }
            selected.append(flight)
            usedIDs.insert(flight.id)
        }

        for flight in model.flights where selected.count < targetLimit && !usedIDs.contains(flight.id) && !flight.phase.isRunwayCritical {
            selected.append(flight)
            usedIDs.insert(flight.id)
        }

        return Array(selected.prefix(targetLimit))
    }

    private func firstAvailableFlight(from flights: [FlightTrack], phases: [FlightTrack.Phase], usedIDs: Set<String>) -> FlightTrack? {
        for phase in phases {
            if let flight = flights.first(where: { $0.phase == phase && !usedIDs.contains($0.id) }) {
                return flight
            }
        }
        return nil
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

private enum AircraftRuntimeTransform {
    static func levelYawOrientation(_ yaw: Float) -> simd_quatf {
        simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    }

    static func makeTransform(position: SIMD3<Float>, yaw: Float, scale: Float) -> Transform {
        Transform(
            scale: SIMD3<Float>(repeating: scale),
            rotation: levelYawOrientation(yaw),
            translation: position
        )
    }
}

@MainActor
private struct AircraftOrientationTestScene {
    let factory: AircraftModelFactory

    func makeScene() -> Entity? {
        let scene = Entity()
        scene.name = "AircraftOrientationTestSceneRoot"

        let placements: [(id: String, label: String, position: SIMD3<Float>, headingDegrees: Float)] = [
            ("orientation-north", "NORTH 0 deg", SIMD3<Float>(-3, 1, 0), 0),
            ("orientation-east", "EAST 90 deg", SIMD3<Float>(0, 1, -3), 90),
            ("orientation-south", "SOUTH 180 deg", SIMD3<Float>(3, 1, 0), 180),
            ("orientation-west", "WEST 270 deg", SIMD3<Float>(0, 1, 3), 270)
        ]

        for placement in placements {
            guard let aircraft = factory.makeAircraftEntity(id: placement.id) else {
                return nil
            }
            aircraft.position = placement.position
            aircraft.orientation = AircraftRuntimeTransform.levelYawOrientation(placement.headingDegrees * .pi / 180)
            aircraft.scale = SIMD3<Float>(repeating: 1)
            scene.addChild(aircraft)

            let label = AirspaceEnvironmentFactory.makeTextPanel(
                placement.label,
                width: 0.34,
                fontSize: 0.024,
                color: .white,
                backing: UIColor.black.withAlphaComponent(0.2)
            )
            label.name = "orientation-label-\(placement.id)"
            label.position = placement.position + SIMD3<Float>(0, 0.22, 0)
            scene.addChild(label)
        }

        return scene
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

private struct RunwaySceneLayout {
    let runwayStartZ: Float
    let runwayEndZ: Float
    let runwayY: Float
    let touchdownZ: Float
    let holdCenter: SIMD3<Float>

    static let standard = RunwaySceneLayout(
        runwayStartZ: -0.82,
        runwayEndZ: 0.82,
        runwayY: 0.018,
        touchdownZ: -0.34,
        holdCenter: SIMD3<Float>(-1.36, 0.88, 0.56)
    )

    var approachThreshold: SIMD3<Float> {
        SIMD3<Float>(0, runwayY, runwayStartZ)
    }

    var departureEnd: SIMD3<Float> {
        SIMD3<Float>(0, runwayY, runwayEndZ)
    }
}

private struct FlightRouteEngine {
    struct State {
        let position: SIMD3<Float>
        let previousPosition: SIMD3<Float>
        let futurePath: [SIMD3<Float>]
        let yaw: Float
        let altitudeFeet: Int
        let speedKnots: Int

        var orientation: simd_quatf {
            AircraftRuntimeTransform.levelYawOrientation(yaw)
        }
    }

    private struct RouteDefinition {
        let points: [SIMD3<Float>]
        let progressRange: ClosedRange<Float>
        let loop: Bool
        let speedRange: (start: Float, end: Float)
    }

    private let runway = RunwaySceneLayout.standard

    func state(for flight: FlightTrack, index: Int, elapsed: TimeInterval) -> State {
        if flight.phase == .holding {
            return holdingState(for: flight, index: index, elapsed: elapsed)
        }
        if flight.phase == .cruise {
            return cruiseState(for: flight, index: index, elapsed: elapsed)
        }

        let definition = routeDefinition(for: flight, index: index)
        let progress = routeProgress(for: flight, definition: definition, elapsed: elapsed)
        let previousProgress = max(definition.progressRange.lowerBound, progress - 0.018)
        let nextProgress = min(definition.progressRange.upperBound, progress + 0.018)
        let position = sample(definition.points, progress: progress, loop: definition.loop)
        let previous = sample(definition.points, progress: previousProgress, loop: definition.loop)
        let next = sample(definition.points, progress: nextProgress, loop: definition.loop)
        let yaw = levelYaw(from: previous, to: next, fallbackDegrees: flight.headingDegrees)

        let speed = interpolatedValue(definition.speedRange, progress: localProgress(progress, in: definition.progressRange))
        return State(
            position: position,
            previousPosition: previous,
            futurePath: futureSamples(for: flight, index: index, elapsed: elapsed, count: flight.phase.futureSampleCount),
            yaw: yaw,
            altitudeFeet: max(0, Int(position.y * 6_600)),
            speedKnots: max(0, Int(speed))
        )
    }

    func futureSamples(for flight: FlightTrack, index: Int, elapsed: TimeInterval, count: Int) -> [SIMD3<Float>] {
        guard count > 1 else { return [] }
        if flight.phase == .holding {
            return holdingSamples(for: flight, index: index, elapsed: elapsed, count: count)
        }
        if flight.phase == .cruise {
            return cruiseSamples(for: flight, index: index, elapsed: elapsed, count: count)
        }

        let definition = routeDefinition(for: flight, index: index)
        let start = routeProgress(for: flight, definition: definition, elapsed: elapsed)
        let maxProgress = definition.loop ? start + 0.32 : min(1, start + flight.phase.futureProgressSpan)
        return (0..<count).map { sampleIndex in
            let t = Float(sampleIndex) / Float(max(1, count - 1))
            let progress = start + (maxProgress - start) * t
            return sample(definition.points, progress: definition.loop ? fractional(progress) : min(max(progress, 0), 1), loop: definition.loop)
        }
    }

    private func routeDefinition(for flight: FlightTrack, index: Int) -> RouteDefinition {
        let lateral = flight.phase.isDemoHighlighted ? 0 : Float((stableHash(flight.id) % 7) - 3) * 0.055
        switch flight.phase.family {
        case .arrival:
            return arrivalDefinition(for: flight, lateral: lateral)
        case .departure, .surface:
            return departureDefinition(for: flight, lateral: lateral)
        case .recovery:
            return goAroundDefinition(lateral: lateral)
        case .enroute:
            return cruiseDefinition(index: index, id: flight.id)
        }
    }

    private func arrivalDefinition(for flight: FlightTrack, lateral: Float) -> RouteDefinition {
        let points = [
            SIMD3<Float>(lateral, 0.78, -1.78),
            SIMD3<Float>(lateral, 0.48, -1.24),
            SIMD3<Float>(lateral * 0.45, 0.20, -0.78),
            SIMD3<Float>(0.00, 0.07, -0.54),
            SIMD3<Float>(0.00, 0.03, runway.touchdownZ),
            SIMD3<Float>(0.00, runway.runwayY, -0.14),
            SIMD3<Float>(0.00, runway.runwayY, 0.42),
            SIMD3<Float>(0.18, runway.runwayY, 0.72)
        ]

        let range: ClosedRange<Float>
        let speed: (start: Float, end: Float)
        switch flight.phase {
        case .descent, .downwind:
            range = 0.05...0.30
            speed = (250, 205)
        case .baseTurn:
            range = 0.25...0.48
            speed = (220, 175)
        case .finalApproach, .final:
            range = 0.00...0.96
            speed = (178, 42)
        case .landingFlare:
            range = 0.50...0.72
            speed = (148, 132)
        case .touchdown:
            range = 0.66...0.80
            speed = (132, 104)
        case .rollout, .taxiIn, .landed:
            range = 0.78...0.98
            speed = (96, 32)
        default:
            range = 0.12...0.62
            speed = (230, 150)
        }
        return RouteDefinition(points: points, progressRange: range, loop: false, speedRange: speed)
    }

    private func departureDefinition(for flight: FlightTrack, lateral: Float) -> RouteDefinition {
        let points = [
            SIMD3<Float>(0.00, runway.runwayY, -0.72),
            SIMD3<Float>(0.00, runway.runwayY, -0.34),
            SIMD3<Float>(0.00, runway.runwayY, 0.04),
            SIMD3<Float>(0.00, 0.07, 0.28),
            SIMD3<Float>(0.12 + lateral, 0.22, 0.54),
            SIMD3<Float>(0.42 + lateral, 0.48, 0.82),
            SIMD3<Float>(0.88 + lateral, 0.76, 0.98),
            SIMD3<Float>(1.36 + lateral, 1.02, 0.84)
        ]

        let range: ClosedRange<Float>
        let speed: (start: Float, end: Float)
        switch flight.phase {
        case .taxiOut, .lineUp:
            range = 0.00...0.16
            speed = (18, 35)
        case .takeoffRoll, .takeoff:
            range = 0.00...1.00
            speed = (35, 290)
        case .rotation:
            range = 0.40...0.52
            speed = (138, 164)
        case .initialClimb:
            range = 0.52...0.70
            speed = (168, 214)
        case .departureTurn:
            range = 0.68...0.86
            speed = (210, 245)
        case .departureClimb, .climb:
            range = 0.82...1.00
            speed = (245, 300)
        default:
            range = 0.10...0.62
            speed = (50, 210)
        }
        return RouteDefinition(points: points, progressRange: range, loop: false, speedRange: speed)
    }

    private func goAroundDefinition(lateral: Float) -> RouteDefinition {
        RouteDefinition(
            points: [
                SIMD3<Float>(0.00, 0.26, -1.02),
                SIMD3<Float>(0.00, 0.18, -0.76),
                SIMD3<Float>(0.02, 0.30, -0.56),
                SIMD3<Float>(-0.28 + lateral, 0.56, -0.28),
                SIMD3<Float>(-0.86 + lateral, 0.82, -0.08),
                SIMD3<Float>(-1.42 + lateral, 1.00, -0.34)
            ],
            progressRange: 0.00...1.00,
            loop: false,
            speedRange: (170, 245)
        )
    }

    private func cruiseDefinition(index: Int, id: String) -> RouteDefinition {
        let seed = Float(stableHash(id) % 360) * .pi / 180
        let radius = 1.55 + Float(index % 4) * 0.18
        let y = 0.76 + Float(index % 5) * 0.14
        let points = (0..<8).map { pointIndex -> SIMD3<Float> in
            let angle = seed + Float(pointIndex) / 8 * .pi * 2
            return SIMD3<Float>(cos(angle) * radius, y + sin(angle * 2) * 0.08, sin(angle) * radius)
        }
        return RouteDefinition(points: points, progressRange: 0...1, loop: true, speedRange: (290, 430))
    }

    private func routeProgress(for flight: FlightTrack, definition: RouteDefinition, elapsed: TimeInterval) -> Float {
        let span = definition.progressRange.upperBound - definition.progressRange.lowerBound
        guard span > 0 else { return definition.progressRange.lowerBound }
        if !definition.loop, flight.phase.isDemoHighlighted {
            let moving = min(1, Float(elapsed) * flight.phase.routePace + flight.phase.demoProgressOffset)
            let eased = flight.phase.usesGentleEasing ? smoothstep(moving) : moving
            return definition.progressRange.lowerBound + span * eased
        }
        let seed = Float(stableHash(flight.id) % 1_000) / 1_000
        let pace = flight.phase.routePace
        let moving = fractional(Float(elapsed) * pace + seed * 0.25 + Float(flight.progress) * 0.35)
        let eased = flight.phase.usesGentleEasing ? smoothstep(moving) : moving
        return definition.progressRange.lowerBound + span * eased
    }

    private func holdingState(for flight: FlightTrack, index: Int, elapsed: TimeInterval) -> State {
        let progress = fractional(Float(elapsed) * 0.035 + Float(stableHash(flight.id) % 100) / 100)
        let position = holdingPosition(progress: progress, index: index)
        let previous = holdingPosition(progress: fractional(progress - 0.012), index: index)
        let next = holdingPosition(progress: fractional(progress + 0.012), index: index)
        let yaw = levelYaw(from: previous, to: next, fallbackDegrees: flight.headingDegrees)
        return State(
            position: position,
            previousPosition: previous,
            futurePath: holdingSamples(for: flight, index: index, elapsed: elapsed, count: flight.phase.futureSampleCount),
            yaw: yaw,
            altitudeFeet: 7_500 + index * 80,
            speedKnots: 205
        )
    }

    private func holdingSamples(for flight: FlightTrack, index: Int, elapsed: TimeInterval, count: Int) -> [SIMD3<Float>] {
        let start = fractional(Float(elapsed) * 0.035 + Float(stableHash(flight.id) % 100) / 100)
        return (0..<count).map { sampleIndex in
            holdingPosition(progress: fractional(start + Float(sampleIndex) / Float(max(1, count - 1)) * 0.52), index: index)
        }
    }

    private func holdingPosition(progress: Float, index: Int) -> SIMD3<Float> {
        let center = runway.holdCenter + SIMD3<Float>(0, Float(index % 3) * 0.035, 0)
        let angle = progress * .pi * 2
        return center + SIMD3<Float>(cos(angle) * 0.46, sin(angle * 2) * 0.025, sin(angle) * 0.28)
    }

    private func cruiseState(for flight: FlightTrack, index: Int, elapsed: TimeInterval) -> State {
        let definition = cruiseDefinition(index: index, id: flight.id)
        let progress = fractional(Float(elapsed) * 0.012 + Float(stableHash(flight.id) % 100) / 100)
        let position = sample(definition.points, progress: progress, loop: true)
        let previous = sample(definition.points, progress: fractional(progress - 0.014), loop: true)
        let next = sample(definition.points, progress: fractional(progress + 0.014), loop: true)
        return State(
            position: position,
            previousPosition: previous,
            futurePath: cruiseSamples(for: flight, index: index, elapsed: elapsed, count: flight.phase.futureSampleCount),
            yaw: levelYaw(from: previous, to: next, fallbackDegrees: flight.headingDegrees),
            altitudeFeet: flight.altitudeFeet,
            speedKnots: flight.speedKnots
        )
    }

    private func cruiseSamples(for flight: FlightTrack, index: Int, elapsed: TimeInterval, count: Int) -> [SIMD3<Float>] {
        let definition = cruiseDefinition(index: index, id: flight.id)
        let start = fractional(Float(elapsed) * 0.012 + Float(stableHash(flight.id) % 100) / 100)
        return (0..<count).map { sampleIndex in
            sample(definition.points, progress: fractional(start + Float(sampleIndex) / Float(max(1, count - 1)) * 0.18), loop: true)
        }
    }

    private func sample(_ points: [SIMD3<Float>], progress: Float, loop: Bool) -> SIMD3<Float> {
        guard points.count > 1 else { return points.first ?? .zero }
        let clamped = loop ? fractional(progress) : min(max(progress, 0), 1)
        let segmentCount = loop ? points.count : points.count - 1
        let scaled = clamped * Float(segmentCount)
        let index = min(Int(floor(scaled)), segmentCount - 1)
        let localT = scaled - Float(index)
        let p0 = point(points, at: index - 1, loop: loop)
        let p1 = point(points, at: index, loop: loop)
        let p2 = point(points, at: index + 1, loop: loop)
        let p3 = point(points, at: index + 2, loop: loop)
        return catmullRom(p0, p1, p2, p3, t: smoothstep(localT))
    }

    private func point(_ points: [SIMD3<Float>], at index: Int, loop: Bool) -> SIMD3<Float> {
        if loop {
            let wrapped = (index % points.count + points.count) % points.count
            return points[wrapped]
        }
        return points[min(max(index, 0), points.count - 1)]
    }

    private func catmullRom(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>, _ p3: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        let t2 = t * t
        let t3 = t2 * t
        let a = p1 * 2.0
        let b = (p2 - p0) * t
        let c = (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
        let d = (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t3
        return (a + b + c + d) * 0.5
    }

    private func localProgress(_ progress: Float, in range: ClosedRange<Float>) -> Float {
        let span = max(0.001, range.upperBound - range.lowerBound)
        return min(max((progress - range.lowerBound) / span, 0), 1)
    }

    private func interpolatedValue(_ range: (start: Float, end: Float), progress: Float) -> Float {
        range.start + (range.end - range.start) * min(max(progress, 0), 1)
    }

    private func stableHash(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { (($0 << 5) &+ $0) &+ Int($1.value) }
    }

    private func levelYaw(from previous: SIMD3<Float>, to next: SIMD3<Float>, fallbackDegrees: Int) -> Float {
        let dx = next.x - previous.x
        let dz = next.z - previous.z
        let horizontalLength = sqrt(dx * dx + dz * dz)
        guard horizontalLength > 0.0001 else {
            return FlightSceneCoordinateConverter.headingToYaw(degrees: fallbackDegrees)
        }
        return atan2(dx, dz)
    }

    private func fractional(_ value: Float) -> Float {
        let raw = value - floor(value)
        return raw < 0 ? raw + 1 : raw
    }

    private func smoothstep(_ value: Float) -> Float {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

@MainActor
private struct TrailEntityFactory {
    func makeTrailEntity(id: String) -> Entity {
        let group = Entity()
        group.name = "trail-\(id)"
        let ribbon = ModelEntity()
        ribbon.name = "trail-ribbon"
        group.addChild(ribbon)
        return group
    }

    func updateTrail(
        _ entity: Entity,
        for flight: FlightTrack,
        history: [SIMD3<Float>],
        futurePath: [SIMD3<Float>],
        lengthFactor: Float,
        isHighlighted: Bool,
        showFuturePath: Bool
    ) {
        entity.isEnabled = true
        for child in Array(entity.children) where child.name.hasPrefix("future-route-") {
            child.removeFromParent()
        }

        let yaw = headingYaw(from: history) ?? FlightSceneCoordinateConverter.headingToYaw(degrees: flight.headingDegrees)
        let syntheticBackfill = makeSyntheticBackfill(from: history.last ?? .zero, yaw: yaw, lengthFactor: lengthFactor)
        let sourcePoints = history.count >= 2 ? history : syntheticBackfill
        let maxPoints = max(3, Int((Float(sourcePoints.count) * lengthFactor).rounded(.up)))
        let points = Array(sourcePoints.suffix(min(sourcePoints.count, maxPoints)))
        let style = flight.phase.routeVisualStyle
        let width = style.trailWidth * (isHighlighted ? 0.038 : 0.018)

        guard let mesh = AirspaceTrailMeshFactory.makeTrailMesh(
            points: points,
            headingYaw: yaw,
            baseWidth: width,
            verticalFade: isHighlighted ? 0.032 : 0.018
        ) else {
            entity.isEnabled = false
            return
        }

        let tint = tintColor(for: flight, isHighlighted: isHighlighted)
        let alpha = isHighlighted
            ? min(0.78, style.trailOpacity * 1.18)
            : min(0.15, style.trailOpacity)
        let material = SimpleMaterial(
            color: tint.withAlphaComponent(alpha),
            roughness: 0.78,
            isMetallic: false
        )
        if let ribbon = entity.children.first(where: { $0.name == "trail-ribbon" }) as? ModelEntity {
            ribbon.model = ModelComponent(mesh: mesh, materials: [material])
        }

        guard showFuturePath, futurePath.count > 1 else { return }
        let futureColor = style.futureColor.withAlphaComponent(isHighlighted ? style.futureOpacity : min(0.15, style.futureOpacity))
        for index in 0..<(futurePath.count - 1) where index.isMultiple(of: 2) {
            let start = futurePath[index]
            let end = futurePath[index + 1]
            let delta = end - start
            let dashStart = start + delta * 0.12
            let dashEnd = start + delta * 0.62
            let dash = AirspaceEnvironmentFactory.makeLine(
                from: dashStart,
                to: dashEnd,
                thickness: isHighlighted ? style.futureThickness : min(style.futureThickness, 0.007),
                color: futureColor,
                name: "future-route-\(flight.id)-\(index)"
            )
            entity.addChild(dash)
        }
    }

    private func makeSyntheticBackfill(from position: SIMD3<Float>, yaw: Float, lengthFactor: Float) -> [SIMD3<Float>] {
        let behind = SIMD3<Float>(-sin(yaw), -0.012, cos(yaw))
        let count = 7
        return Array((0..<count).map { index in
            position + behind * Float(index) * 0.16 * max(0.25, lengthFactor)
        }.reversed())
    }

    private func tintColor(for flight: FlightTrack, isHighlighted: Bool) -> UIColor {
        if isHighlighted { return flight.phase.sceneColor }
        return flight.phase.routeVisualStyle.color
    }

    private func headingYaw(from history: [SIMD3<Float>]) -> Float? {
        guard let last = history.last, let previous = history.dropLast().last else { return nil }
        let delta = last - previous
        guard simd_length(delta) > 0.001 else { return nil }
        return atan2(delta.x, delta.z)
    }
}

struct AirspaceTrailGeometry {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let indices: [UInt32]
}

@MainActor
enum AirspaceTrailMeshFactory {
    static func makeTrailMesh(points: [SIMD3<Float>], headingYaw: Float, baseWidth: Float, verticalFade: Float) -> MeshResource? {
        guard let geometry = makeTrailRibbonGeometry(
            points: points,
            headingYaw: headingYaw,
            baseWidth: baseWidth,
            verticalFade: verticalFade
        ) else { return nil }

        return makeMesh(name: "TaperedFlightTrail", positions: geometry.positions, normals: geometry.normals, indices: geometry.indices)
    }

    static func makeTrailRibbonGeometry(points: [SIMD3<Float>], headingYaw: Float, baseWidth: Float, verticalFade: Float) -> AirspaceTrailGeometry? {
        guard points.count >= 2 else { return nil }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(points.count * 2)
        normals.reserveCapacity(points.count * 2)
        indices.reserveCapacity(max(0, points.count - 1) * 6)

        let fallbackSide = SIMD3<Float>(cos(headingYaw), 0, sin(headingYaw))
        for index in points.indices {
            let previous = index > points.startIndex ? points[points.index(before: index)] : points[index]
            let next = index < points.index(before: points.endIndex) ? points[points.index(after: index)] : points[index]
            let direction = normalizedOrFallback(next - previous, fallback: SIMD3<Float>(-sin(headingYaw), -0.01, cos(headingYaw)))
            let side = normalizedOrFallback(simd_cross(SIMD3<Float>(0, 1, 0), direction), fallback: fallbackSide)
            let progress = Float(index) / Float(max(1, points.count - 1))
            let taper = smoothstep(1 - progress)
            let width = max(0.002, baseWidth * taper)
            let sag = SIMD3<Float>(0, -verticalFade * progress * progress, 0)
            positions.append(points[index] + sag + side * width)
            positions.append(points[index] + sag - side * width)
            normals.append(SIMD3<Float>(0, 1, 0))
            normals.append(SIMD3<Float>(0, 1, 0))
        }

        for index in 0..<(points.count - 1) {
            let base = UInt32(index * 2)
            indices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
        }

        return AirspaceTrailGeometry(positions: positions, normals: normals, indices: indices)
    }

    static func makeWakeMesh(length: Float, startWidth: Float, endWidth: Float, verticalDrop: Float) -> MeshResource? {
        let segments = 7
        let points = (0..<segments).map { index -> SIMD3<Float> in
            let progress = Float(index) / Float(segments - 1)
            return SIMD3<Float>(0, -verticalDrop * progress * progress, progress * length - length * 0.5)
        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for (index, point) in points.enumerated() {
            let progress = Float(index) / Float(segments - 1)
            let width = startWidth + (endWidth - startWidth) * smoothstep(progress)
            positions.append(point + SIMD3<Float>(width, 0, 0))
            positions.append(point - SIMD3<Float>(width, 0, 0))
            positions.append(point + SIMD3<Float>(0, width * 0.45, 0))
            positions.append(point - SIMD3<Float>(0, width * 0.45, 0))
            normals.append(contentsOf: Array(repeating: SIMD3<Float>(0, 1, 0), count: 4))
        }

        for index in 0..<(segments - 1) {
            let base = UInt32(index * 4)
            indices.append(contentsOf: [
                base, base + 1, base + 4, base + 1, base + 5, base + 4,
                base + 2, base + 3, base + 6, base + 3, base + 7, base + 6
            ])
        }

        return makeMesh(name: "TaperedAircraftWake", positions: positions, normals: normals, indices: indices)
    }

    private static func makeMesh(name: String, positions: [SIMD3<Float>], normals: [SIMD3<Float>], indices: [UInt32]) -> MeshResource? {
        guard positions.count == normals.count, !indices.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .allFaces(0)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func normalizedOrFallback(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        guard length > 0.0001 else { return fallback }
        return vector / length
    }

    private static func smoothstep(_ value: Float) -> Float {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

@MainActor
private struct AirportSceneFactory {
    func makeAirportScene(for airport: Airport) -> Entity {
        let group = Entity()
        group.name = "airport-\(airport.icao)"

        let ground = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(3.6, 0.018, 2.55)),
            materials: [SimpleMaterial(color: UIColor(red: 0.055, green: 0.17, blue: 0.18, alpha: 0.82), roughness: 0.86, isMetallic: false)]
        )
        ground.name = "airport-ground"
        ground.position = SIMD3<Float>(0, -0.04, -0.05)
        group.addChild(ground)

        let towerBase = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.08, 0.36, 0.08)),
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.14), roughness: 0.4, isMetallic: true)]
        )
        towerBase.position = SIMD3<Float>(-0.86, 0.16, 0.58)
        group.addChild(towerBase)

        let towerCab = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.24, 0.1, 0.18)),
            materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.26), roughness: 0.22, isMetallic: true)]
        )
        towerCab.position = SIMD3<Float>(-0.86, 0.38, 0.58)
        group.addChild(towerCab)

        let runwayID = airport.runways.first?.id.components(separatedBy: " / ").last ?? "27L"
        group.addChild(makeMainRunway(id: "RWY \(runwayID)"))
        group.addChild(makeApproachCorridor())
        group.addChild(makeDepartureCorridor())
        group.addChild(makeHoldingAndGoAroundContext())
        group.addChild(makeAltitudeRings())
        return group
    }

    private func makeMainRunway(id: String) -> Entity {
        let group = Entity()
        group.name = "main-runway-context"

        let runway = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.18, 0.014, 1.68)),
            materials: [SimpleMaterial(color: UIColor(white: 0.16, alpha: 0.98), roughness: 0.74, isMetallic: false)]
        )
        runway.name = "runway-surface"
        runway.position = SIMD3<Float>(0, 0, 0)
        group.addChild(runway)

        let touchdown = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.21, 0.018, 0.18)),
            materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.3), roughness: 0.5, isMetallic: false)]
        )
        touchdown.name = "touchdown-zone-highlight"
        touchdown.position = SIMD3<Float>(0, 0.018, -0.34)
        group.addChild(touchdown)

        for marker in 0..<11 {
            let stripe = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.06, 0.018, 0.052)),
                materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.9), roughness: 0.36, isMetallic: false)]
            )
            stripe.name = "runway-centerline"
            stripe.position = SIMD3<Float>(0, 0.018, -0.68 + Float(marker) * 0.135)
            group.addChild(stripe)
        }

        for light in 0..<24 {
            let z = -0.8 + Float(light) * 0.069
            let pulseAlpha = 0.46 + CGFloat(light % 5) * 0.055
            let center = ModelEntity(
                mesh: .generateSphere(radius: 0.011),
                materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(min(0.92, pulseAlpha + 0.18)), roughness: 0.2, isMetallic: false)]
            )
            center.name = "runway-centerline-light"
            center.position = SIMD3<Float>(0, 0.028, z)
            group.addChild(center)

            for side: Float in [-0.108, 0.108] {
                let beacon = ModelEntity(
                    mesh: .generateSphere(radius: 0.013),
                    materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.32), roughness: 0.2, isMetallic: false)]
                )
                beacon.name = "runway-edge-light"
                beacon.position = SIMD3<Float>(side, 0.026, z)
                group.addChild(beacon)
            }
        }

        for side: Float in [-0.055, 0.0, 0.055] {
            let threshold = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.026, 0.022, 0.08)),
                materials: [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(0.86), roughness: 0.25, isMetallic: false)]
            )
            threshold.name = "threshold-light"
            threshold.position = SIMD3<Float>(side, 0.03, -0.82)
            group.addChild(threshold)
        }

        let text = AirspaceEnvironmentFactory.makeText(id, size: 0.038, color: UIColor.white.withAlphaComponent(0.82), width: 0.45)
        text.position = SIMD3<Float>(-0.31, 0.046, -0.68)
        group.addChild(text)

        let arrow = AirspaceEnvironmentFactory.makeLine(
            from: SIMD3<Float>(0.19, 0.055, -0.62),
            to: SIMD3<Float>(0.19, 0.055, 0.54),
            thickness: 0.01,
            color: UIColor.white.withAlphaComponent(0.34),
            name: "runway-flow-arrow"
        )
        group.addChild(arrow)
        return group
    }

    private func makeApproachCorridor() -> Entity {
        let group = Entity()
        group.name = "arrival-approach-corridor"
        let style = RouteVisualStyle.style(for: .arrivalFinal)
        let leftRail = [
            SIMD3<Float>(-0.28, 0.56, -1.72),
            SIMD3<Float>(-0.18, 0.32, -1.18),
            SIMD3<Float>(-0.11, 0.09, -0.72)
        ]
        let rightRail = leftRail.map { SIMD3<Float>(-$0.x, $0.y, $0.z) }
        group.addChild(AirspaceEnvironmentFactory.makePolyline(points: leftRail, thickness: 0.014, color: style.color.withAlphaComponent(0.42), name: "arrival-guide-rail-left"))
        group.addChild(AirspaceEnvironmentFactory.makePolyline(points: rightRail, thickness: 0.014, color: style.color.withAlphaComponent(0.42), name: "arrival-guide-rail-right"))

        for step in 0..<13 {
            let progress = Float(step) / 12
            let point = SIMD3<Float>(0, 0.56 + (0.045 - 0.56) * progress, -1.72 + (0.82 * progress))
            let light = ModelEntity(
                mesh: .generateSphere(radius: 0.011 + progress * 0.006),
                materials: [SimpleMaterial(color: style.futureColor.withAlphaComponent(0.38 + CGFloat(progress) * 0.32), roughness: 0.25, isMetallic: false)]
            )
            light.name = "descending-approach-light"
            light.position = point
            group.addChild(light)
        }

        for index in 0..<4 {
            let color: UIColor = index < 2 ? .systemRed : .systemGreen
            let papi = ModelEntity(
                mesh: .generateSphere(radius: 0.012),
                materials: [SimpleMaterial(color: color.withAlphaComponent(0.82), roughness: 0.18, isMetallic: false)]
            )
            papi.name = "glide-slope-indicator"
            papi.position = SIMD3<Float>(-0.22 + Float(index) * 0.04, 0.035, -0.52)
            group.addChild(papi)
        }
        return group
    }

    private func makeDepartureCorridor() -> Entity {
        let group = Entity()
        group.name = "departure-climb-corridor"
        let style = RouteVisualStyle.style(for: .departureTakeoff)
        let path = [
            SIMD3<Float>(0.00, 0.06, -0.08),
            SIMD3<Float>(0.06, 0.20, 0.36),
            SIMD3<Float>(0.34, 0.46, 0.80),
            SIMD3<Float>(0.86, 0.76, 1.02),
            SIMD3<Float>(1.36, 1.02, 0.92)
        ]
        group.addChild(AirspaceEnvironmentFactory.makeDashedPolyline(points: path, thickness: 0.016, color: style.color.withAlphaComponent(0.52), name: "departure-dashed-arc"))
        for step in 0..<8 {
            let point = path[min(step / 2, path.count - 1)]
            let pulse = ModelEntity(
                mesh: .generateSphere(radius: 0.009 + Float(step % 3) * 0.002),
                materials: [SimpleMaterial(color: style.color.withAlphaComponent(0.48), roughness: 0.3, isMetallic: false)]
            )
            pulse.name = "takeoff-direction-pulse"
            pulse.position = point + SIMD3<Float>(0, 0.012, Float(step) * 0.035)
            group.addChild(pulse)
        }
        let label = AirspaceEnvironmentFactory.makeText("TAKEOFF", size: 0.032, color: style.color.withAlphaComponent(0.84), width: 0.42)
        label.position = SIMD3<Float>(0.52, 0.52, 0.78)
        group.addChild(label)
        return group
    }

    private func makeHoldingAndGoAroundContext() -> Entity {
        let group = Entity()
        group.name = "holding-and-go-around-context"
        let holdingStyle = RouteVisualStyle.style(for: .holding)
        let goAroundStyle = RouteVisualStyle.style(for: .goAround)
        let runway = RunwaySceneLayout.standard
        let hold = (0...36).map { index -> SIMD3<Float> in
            let angle = Float(index) / 36 * .pi * 2
            return runway.holdCenter + SIMD3<Float>(cos(angle) * 0.46, 0, sin(angle) * 0.28)
        }
        group.addChild(AirspaceEnvironmentFactory.makeDashedPolyline(points: hold, thickness: 0.012, color: holdingStyle.color.withAlphaComponent(0.44), name: "holding-pattern-dotted-oval"))

        let missed = [
            SIMD3<Float>(0.00, 0.26, -1.02),
            SIMD3<Float>(0.00, 0.18, -0.76),
            SIMD3<Float>(0.02, 0.30, -0.56),
            SIMD3<Float>(-0.28, 0.56, -0.28),
            SIMD3<Float>(-0.86, 0.82, -0.08),
            SIMD3<Float>(-1.42, 1.00, -0.34)
        ]
        group.addChild(AirspaceEnvironmentFactory.makeDashedPolyline(points: missed, thickness: 0.016, color: goAroundStyle.futureColor.withAlphaComponent(0.56), name: "go-around-missed-approach-arc"))
        let label = AirspaceEnvironmentFactory.makeText("GO AROUND", size: 0.034, color: goAroundStyle.color.withAlphaComponent(0.86), width: 0.48)
        label.position = SIMD3<Float>(-0.72, 0.74, -0.18)
        group.addChild(label)
        return group
    }

    private func makeAltitudeRings() -> Entity {
        let group = Entity()
        group.name = "altitude-rings"
        let style = RouteVisualStyle.style(for: .altitudeRing)
        let layers: [(String, Float, Float)] = [("1,000 ft", 0.24, 0.72), ("3,000 ft", 0.56, 1.05), ("10,000 ft", 1.08, 1.46)]
        for (label, y, radius) in layers {
            var previous: SIMD3<Float>?
            for step in 0...40 {
                let angle = Float(step) / 40 * Float.pi * 2
                let current = SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
                if let previous {
                    group.addChild(AirspaceEnvironmentFactory.makeLine(from: previous, to: current, thickness: 0.0035, color: style.color.withAlphaComponent(0.08), name: "altitude-ring"))
                }
                previous = current
            }
            let text = AirspaceEnvironmentFactory.makeText(label, size: 0.022, color: style.color.withAlphaComponent(0.26), width: 0.3)
            text.position = SIMD3<Float>(radius + 0.08, y, 0)
            group.addChild(text)
        }
        return group
    }
}

@MainActor
private struct WeatherLayerFactory {
    func makeWeatherScene() -> Entity {
        let group = Entity()
        group.name = "weather-layers"
        let colors: [UIColor] = [.systemGreen, .systemTeal, .systemOrange, .systemRed]
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

        let keyLight = DirectionalLight()
        keyLight.name = "cinematic-key-light"
        keyLight.light = DirectionalLightComponent(color: .white, intensity: 4_200)
        keyLight.orientation = simd_quatf(angle: -0.72, axis: SIMD3<Float>(1, 0, 0))
            * simd_quatf(angle: 0.35, axis: SIMD3<Float>(0, 1, 0))
        group.addChild(keyLight)

        let fillLight = PointLight()
        fillLight.name = "runway-fill-light"
        fillLight.light = PointLightComponent(color: UIColor(red: 0.75, green: 0.95, blue: 1, alpha: 1), intensity: 2_200, attenuationRadius: 4.2)
        fillLight.position = SIMD3<Float>(0.15, 1.0, -0.8)
        group.addChild(fillLight)

        let dome = ModelEntity(
            mesh: .generateSphere(radius: 5.4),
            materials: [SimpleMaterial(color: UIColor(red: 0.045, green: 0.18, blue: 0.24, alpha: 0.48), roughness: 1, isMetallic: false)]
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
            group.addChild(makeLine(from: a, to: b, thickness: 0.012, color: UIColor.white.withAlphaComponent(0.22), name: "curved-horizon"))
        }

        for index in 0..<22 {
            let glow = ModelEntity(
                mesh: .generateSphere(radius: 0.018 + Float(index % 3) * 0.007),
                materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.30), roughness: 0.4, isMetallic: false)]
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

    static func makePolyline(points: [SIMD3<Float>], thickness: Float, color: UIColor, name: String) -> Entity {
        let group = Entity()
        group.name = name
        guard points.count > 1 else { return group }
        for index in 0..<(points.count - 1) {
            group.addChild(makeLine(from: points[index], to: points[index + 1], thickness: thickness, color: color, name: "\(name)-segment-\(index)"))
        }
        return group
    }

    static func makeDashedPolyline(points: [SIMD3<Float>], thickness: Float, color: UIColor, name: String) -> Entity {
        let group = Entity()
        group.name = name
        guard points.count > 1 else { return group }
        for index in 0..<(points.count - 1) where index.isMultiple(of: 2) {
            let start = points[index]
            let end = points[index + 1]
            let delta = end - start
            group.addChild(makeLine(from: start + delta * 0.08, to: start + delta * 0.68, thickness: thickness, color: color, name: "\(name)-dash-\(index)"))
        }
        return group
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

private enum DefaultLabelRole {
    case landing
    case takeoff
    case holding
    case goAround
}

private extension FlightTrack.Phase {
    var defaultLabelRole: DefaultLabelRole? {
        switch self {
        case .finalApproach, .final, .landingFlare, .touchdown, .rollout:
            return .landing
        case .takeoffRoll, .rotation, .takeoff, .initialClimb:
            return .takeoff
        case .holding:
            return .holding
        case .goAround:
            return .goAround
        default:
            return nil
        }
    }

    var isRunwayCritical: Bool {
        switch self {
        case .finalApproach, .final, .landingFlare, .touchdown, .rollout, .takeoffRoll, .rotation, .takeoff, .initialClimb:
            return true
        default:
            return false
        }
    }

    var demoProgressOffset: Float {
        switch self {
        case .takeoffRoll, .takeoff:
            return 0.34
        case .rotation:
            return 0.44
        case .initialClimb:
            return 0.58
        case .goAround:
            return 0.62
        default:
            return 0
        }
    }

    var phaseBadge: String {
        switch self {
        case .finalApproach, .final:
            return "FINAL"
        case .landingFlare:
            return "FLARE"
        case .touchdown:
            return "LANDING"
        case .rollout:
            return "ROLLOUT"
        case .takeoffRoll, .takeoff:
            return "TAKEOFF"
        case .rotation:
            return "ROTATE"
        case .initialClimb, .departureTurn, .departureClimb, .climb:
            return "CLIMB"
        case .holding:
            return "HOLDING"
        case .goAround:
            return "GO AROUND"
        default:
            return shortLabel
        }
    }

    var isDemoHighlighted: Bool {
        switch self {
        case .finalApproach, .final, .landingFlare, .touchdown, .rollout, .takeoffRoll, .rotation, .initialClimb, .holding, .goAround:
            return true
        default:
            return false
        }
    }

    var usesPersistentDemoLabel: Bool {
        switch self {
        case .finalApproach, .takeoffRoll, .holding, .goAround:
            return true
        default:
            return false
        }
    }

    var sceneColor: UIColor {
        routeVisualStyle.color
    }

    var futureRouteColor: UIColor {
        routeVisualStyle.futureColor
    }

    var trailPointLimit: Int {
        routeVisualStyle.trailPointLimit
    }

    var futureSampleCount: Int {
        routeVisualStyle.futureSampleCount
    }

    var futureProgressSpan: Float {
        routeVisualStyle.futureProgressSpan
    }

    var routePace: Float {
        routeVisualStyle.routePace
    }

    var usesGentleEasing: Bool {
        routeVisualStyle.usesGentleEasing
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
                .accessibilityLabel(mode.title)
                .accessibilityHint(mode.subtitle)
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
