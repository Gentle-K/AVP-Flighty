import Foundation
import SwiftUI

@MainActor
final class DigitalTowerModel: ObservableObject {
    static let immersiveSpaceID = "DigitalTowerImmersiveSpace"

    enum ImmersiveCommand: Equatable {
        case none
        case open
        case dismiss
    }

    @Published private(set) var dataState: DataState<AviationSnapshot> = .idle
    @Published private(set) var selectedAirport: Airport = AirportCatalog.fallbackAirport
    @Published private(set) var flights: [FlightTrack] = []
    @Published private(set) var weather: WeatherSnapshot?
    @Published private(set) var alerts: [AirspaceAlert] = []
    @Published private(set) var replayEvents: [ReplayEvent] = []
    @Published private(set) var agentPlan: AppActionPlan
    @Published private(set) var releaseReview: ReleaseReviewResult

    @Published var experienceMode: ExperienceMode = .skyPortal {
        didSet {
            if experienceMode == .flightChase, selectedFlight == nil {
                selectedFlight = flights.first
            }
            mode = experienceMode.legacyMode
            refreshDerivedState()
        }
    }
    @Published var sceneScalePreset: SceneScalePreset = .fullSky {
        didSet { refreshDerivedState() }
    }
    @Published var aircraftDensity: AircraftDensity = .medium {
        didSet { refreshDerivedState() }
    }
    @Published var labelDensity: LabelDensity = .focused {
        didSet { refreshDerivedState() }
    }
    @Published var trailLength: Double = 0.68 {
        didSet { refreshDerivedState() }
    }
    @Published var verticalExaggeration: Double = 1.15 {
        didSet { refreshDerivedState() }
    }
    @Published var isSoundEnabled = true
    @Published var isCinematicFlybyEnabled = true
    @Published var shouldShowOnboardingHints = true

    @Published var mode: AirspaceMode = .live {
        didSet {
            if mode == .flight, selectedFlight == nil {
                selectedFlight = flights.first
            }
            refreshDerivedState()
        }
    }
    @Published var selectedFlight: FlightTrack? {
        didSet { refreshDerivedState() }
    }
    @Published var overlays: Set<AirspaceOverlay> = [.traffic, .labels] {
        didSet { refreshDerivedState() }
    }
    @Published var selectedWeatherLayers: Set<WeatherLayer> = [.metar, .wind] {
        didSet {
            if selectedWeatherLayers.contains(.stormCells) {
                overlays.insert(.weather)
            }
            refreshDerivedState()
        }
    }
    @Published var selectedTowerViewpoint: TowerViewpoint = .tower
    @Published var selectedSettingsCategory: SettingsCategory = .dataSources
    @Published var searchText = ""
    @Published var isSearchFocused = false
    @Published var isSettingsPresented = false
    @Published var isSafetyNoticePresented = false
    @Published private(set) var hasAcceptedSafetyNotice: Bool
    @Published var isImmersiveOpen = false
    @Published var immersiveCommand: ImmersiveCommand = .none
    @Published var replayProgress = 0.64
    @Published var playbackSpeed = "1x"
    @Published var isReplayPlaying = false

    let availableAirports = AirportCatalog.airports

    private let provider: any FlightDataProvider
    private let orchestrator: OrchestratorAgent
    private let releaseReviewer: FinalReleaseReviewAgent
    private var loadTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?

    init(
        provider: any FlightDataProvider = FlightDataProviderFactory.makeDefault(),
        orchestrator: OrchestratorAgent = OrchestratorAgent(),
        releaseReviewer: FinalReleaseReviewAgent = FinalReleaseReviewAgent()
    ) {
        self.provider = provider
        self.orchestrator = orchestrator
        self.releaseReviewer = releaseReviewer
        self.hasAcceptedSafetyNotice = UserDefaults.standard.bool(forKey: "DigitalTowerAcceptedSafetyNotice")

        let initialContext = AppContext.empty(
            airport: AirportCatalog.fallbackAirport,
            isAuthorizedLiveData: provider.isAuthorizedLiveProvider
        )
        self.agentPlan = orchestrator.plan(for: initialContext)
        self.releaseReview = releaseReviewer.review(context: initialContext)
    }

    deinit {
        loadTask?.cancel()
        streamTask?.cancel()
        replayTask?.cancel()
    }

    var currentSnapshot: AviationSnapshot? {
        dataState.value
    }

    var isAuthorizedLiveData: Bool {
        currentSnapshot?.freshness.isAuthorizedLive == true && provider.isAuthorizedLiveProvider
    }

    var connectionStatusTitle: String {
        switch dataState {
        case .idle:
            return "Offline"
        case .loading:
            return "Loading"
        case .loaded(let snapshot):
            return snapshot.freshness.isAuthorizedLive ? "Authorized" : "Debug Sample"
        case .empty:
            return "No Data"
        case .failed:
            return "Needs Setup"
        case .stale:
            return "Stale"
        }
    }

    var dataTimestampText: String {
        guard let freshness = currentSnapshot?.freshness else {
            return "No data"
        }
        return freshness.serverTime.formatted(date: .omitted, time: .shortened)
    }

    var searchResults: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        let airportResults = availableAirports
            .filter {
                $0.iata.lowercased().contains(query)
                    || $0.icao.lowercased().contains(query)
                    || $0.name.lowercased().contains(query)
                    || $0.city.lowercased().contains(query)
            }
            .map(SearchResult.airport)

        let flightResults = flights
            .filter {
                $0.callsign.lowercased().contains(query)
                    || $0.origin.lowercased().contains(query)
                    || $0.destination.lowercased().contains(query)
                    || $0.aircraft.lowercased().contains(query)
            }
            .prefix(8)
            .map(SearchResult.flight)

        return Array(flightResults) + airportResults
    }

    var metrics: AirspaceMetrics {
        let arrivals = flights.filter { $0.destination == selectedAirport.iata }.count
        let departures = flights.filter { $0.origin == selectedAirport.iata }.count
        let highPriorityAlerts = alerts.filter { $0.severity == .critical || $0.severity == .warning }.count
        let congestionValue = min(1, Double(flights.count) / 120)
        let congestionLabel: String

        switch congestionValue {
        case 0..<0.35:
            congestionLabel = "Light"
        case 0..<0.72:
            congestionLabel = "Moderate"
        default:
            congestionLabel = "High"
        }

        return AirspaceMetrics(
            visibleFlights: flights.count,
            arrivals: arrivals,
            departures: departures,
            highPriorityAlerts: highPriorityAlerts,
            congestionLabel: congestionLabel,
            congestionValue: congestionValue
        )
    }

    func start() {
        guard loadTask == nil else { return }
        loadAirport(selectedAirport)
        if !hasAcceptedSafetyNotice {
            isSafetyNoticePresented = true
        }
    }

    func loadAirport(_ airport: Airport) {
        loadTask?.cancel()
        streamTask?.cancel()
        selectedAirport = airport
        selectedFlight = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            let previous = self.currentSnapshot
            self.dataState = .loading(previous: previous)
            self.refreshDerivedState()

            do {
                let snapshot = try await self.provider.bootstrap(airportCode: airport.icao)
                self.apply(snapshot)
                self.startStreaming(airportCode: airport.icao)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if let previous {
                    self.dataState = .stale(previous, message: message)
                    self.applySnapshotValues(previous)
                } else {
                    self.dataState = .failed(message: message, previous: nil)
                    self.clearSnapshotValues()
                }
                self.refreshDerivedState()
            }

            self.loadTask = nil
        }
    }

    func setMode(_ newMode: AirspaceMode) {
        mode = newMode
        experienceMode = ExperienceMode.fromLegacyMode(newMode)
    }

    func setExperienceMode(_ newMode: ExperienceMode) {
        if newMode == .flightChase, selectedFlight == nil {
            selectedFlight = flights.first
        }
        if newMode == .globe {
            sceneScalePreset = .globe
        } else if newMode == .skyPortal {
            sceneScalePreset = .fullSky
        } else if newMode == .digitalTower || newMode == .replay {
            sceneScalePreset = .roomScaleAirport
        }
        experienceMode = newMode
    }

    func selectFlight(_ flight: FlightTrack) {
        selectedFlight = flight
        mode = .flight
        experienceMode = .flightChase
        searchText = ""
        isSearchFocused = false
    }

    func selectFlight(id: String) {
        guard let flight = flights.first(where: { $0.id == id }) else { return }
        selectFlight(flight)
    }

    func selectSearchResult(_ result: SearchResult) {
        switch result {
        case .flight(let flight):
            selectFlight(flight)
        case .airport(let airport):
            loadAirport(airport)
            mode = .live
        }
        searchText = ""
        isSearchFocused = false
    }

    func toggleOverlay(_ overlay: AirspaceOverlay) {
        if overlays.contains(overlay) {
            overlays.remove(overlay)
        } else {
            overlays.insert(overlay)
        }
    }

    func toggleWeatherLayer(_ layer: WeatherLayer) {
        if selectedWeatherLayers.contains(layer) {
            selectedWeatherLayers.remove(layer)
        } else {
            selectedWeatherLayers.insert(layer)
        }
    }

    func setTowerViewpoint(_ viewpoint: TowerViewpoint) {
        selectedTowerViewpoint = viewpoint
    }

    func toggleReplayPlayback() {
        setReplayPlaying(!isReplayPlaying)
    }

    func jumpReplay(by delta: Double) {
        replayProgress = min(1, max(0, replayProgress + delta))
    }

    func cyclePlaybackSpeed() {
        playbackSpeed = playbackSpeed == "1x" ? "2x" : playbackSpeed == "2x" ? "0.5x" : "1x"
        if isReplayPlaying {
            setReplayPlaying(true)
        }
    }

    func resetLayout() {
        overlays = [.traffic, .labels]
        selectedWeatherLayers = [.metar, .wind]
        selectedTowerViewpoint = .tower
        aircraftDensity = .medium
        labelDensity = .focused
        trailLength = 0.68
        verticalExaggeration = 1.15
        sceneScalePreset = .fullSky
        isSettingsPresented = false
    }

    func acceptSafetyNotice() {
        hasAcceptedSafetyNotice = true
        UserDefaults.standard.set(true, forKey: "DigitalTowerAcceptedSafetyNotice")
        isSafetyNoticePresented = false
    }

    func requestToggleImmersive() {
        guard hasAcceptedSafetyNotice else {
            isSafetyNoticePresented = true
            return
        }
        immersiveCommand = isImmersiveOpen ? .dismiss : .open
    }

    func requestOpenImmersive() {
        guard hasAcceptedSafetyNotice else {
            isSafetyNoticePresented = true
            return
        }
        guard !isImmersiveOpen else { return }
        immersiveCommand = .open
    }

    func requestDismissImmersive() {
        guard isImmersiveOpen else { return }
        immersiveCommand = .dismiss
    }

    func dismissOnboardingHints() {
        shouldShowOnboardingHints = false
    }

    func completeImmersiveCommand() {
        immersiveCommand = .none
    }

    func markImmersiveOpened(_ opened: Bool) {
        isImmersiveOpen = opened
    }

    private func setReplayPlaying(_ playing: Bool) {
        replayTask?.cancel()
        isReplayPlaying = playing
        guard playing else { return }

        let speed = playbackSpeed == "2x" ? 0.018 : playbackSpeed == "0.5x" ? 0.0045 : 0.009
        replayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    guard let self else { return }
                    self.replayProgress += speed
                    if self.replayProgress >= 1 {
                        self.replayProgress = 1
                        self.setReplayPlaying(false)
                    }
                }
            }
        }
    }

    private func startStreaming(airportCode: String) {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in self.provider.events(airportCode: airportCode) {
                    self.apply(event)
                }
            } catch is CancellationError {
                return
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if let snapshot = self.currentSnapshot {
                    self.dataState = .stale(snapshot, message: message)
                } else {
                    self.dataState = .failed(message: message, previous: nil)
                }
                self.refreshDerivedState()
            }
        }
    }

    private func apply(_ snapshot: AviationSnapshot) {
        if snapshot.flights.isEmpty {
            dataState = .empty(reason: "Authorized source returned no visible traffic for \(snapshot.airport.iata).", freshness: snapshot.freshness)
        } else if snapshot.freshness.isStale {
            dataState = .stale(snapshot, message: "Authorized source is stale.")
        } else {
            dataState = .loaded(snapshot)
        }
        applySnapshotValues(snapshot)
        refreshDerivedState()
    }

    private func applySnapshotValues(_ snapshot: AviationSnapshot) {
        selectedAirport = snapshot.airport
        flights = snapshot.flights.sorted { $0.callsign < $1.callsign }
        weather = snapshot.weather
        alerts = snapshot.alerts
        replayEvents = snapshot.replayEvents
        if let selectedFlight, !flights.contains(where: { $0.id == selectedFlight.id }) {
            self.selectedFlight = flights.first
        }
    }

    private func clearSnapshotValues() {
        flights = []
        selectedFlight = nil
        weather = nil
        alerts = []
        replayEvents = []
    }

    private func apply(_ event: AviationDataEvent) {
        switch event {
        case .flightUpsert(let flight):
            if let index = flights.firstIndex(where: { $0.id == flight.id }) {
                flights[index] = flight
            } else {
                flights.append(flight)
            }
            flights.sort { $0.callsign < $1.callsign }
        case .flightDelete(let id):
            flights.removeAll { $0.id == id }
            if selectedFlight?.id == id {
                selectedFlight = flights.first
            }
        case .weatherUpdate(let snapshot):
            weather = snapshot
        case .alertUpsert(let alert):
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index] = alert
            } else {
                alerts.append(alert)
            }
        case .alertDelete(let id):
            alerts.removeAll { $0.id == id }
        case .heartbeat:
            break
        }

        if var snapshot = currentSnapshot {
            snapshot = AviationSnapshot(
                airport: selectedAirport,
                flights: flights,
                weather: weather ?? snapshot.weather,
                alerts: alerts,
                replayEvents: replayEvents,
                freshness: snapshot.freshness
            )
            dataState = snapshot.freshness.isStale ? .stale(snapshot, message: "Authorized source is stale.") : .loaded(snapshot)
        }
        refreshDerivedState()
    }

    private func refreshDerivedState() {
        let context = AppContext(
            mode: mode,
            airport: selectedAirport,
            selectedFlight: selectedFlight,
            flights: flights,
            weather: weather,
            alerts: alerts,
            overlays: overlays,
            freshness: currentSnapshot?.freshness,
            isAuthorizedLiveData: isAuthorizedLiveData
        )
        agentPlan = orchestrator.plan(for: context)
        releaseReview = releaseReviewer.review(context: context)
    }
}
