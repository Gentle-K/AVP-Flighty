import Foundation

enum AviationDataError: LocalizedError, Equatable, Sendable {
    case missingConfiguration
    case invalidResponse(Int)
    case malformedEvent(String)
    case streamEnded
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Authorized aviation data endpoint is not configured."
        case .invalidResponse(let status):
            return "Aviation data service returned HTTP \(status)."
        case .malformedEvent(let event):
            return "Aviation data stream sent an unsupported event: \(event)."
        case .streamEnded:
            return "Aviation data stream ended."
        case .unavailable(let message):
            return message
        }
    }
}

protocol FlightDataProvider: Sendable {
    var isAuthorizedLiveProvider: Bool { get }

    func bootstrap(airportCode: String) async throws -> AviationSnapshot
    func events(airportCode: String) -> AsyncThrowingStream<AviationDataEvent, Error>
}

struct AviationDataConfiguration: Equatable, Sendable {
    let baseURL: URL
    let bearerToken: String

    static func fromBundle(_ bundle: Bundle = .main, userDefaults: UserDefaults = .standard) -> AviationDataConfiguration? {
        let baseURLString = clean(bundle.object(forInfoDictionaryKey: "AVIATION_API_BASE_URL") as? String)
        let token = clean(userDefaults.string(forKey: "AviationAPIToken"))
            ?? clean(bundle.object(forInfoDictionaryKey: "AVIATION_API_TOKEN") as? String)

        guard let baseURLString, let baseURL = URL(string: baseURLString), let token else {
            return nil
        }

        return AviationDataConfiguration(baseURL: baseURL, bearerToken: token)
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard !trimmed.contains("$("), trimmed != "<#AVIATION_API_TOKEN#>" else {
            return nil
        }
        return trimmed
    }
}

struct LiveAviationDataProvider: FlightDataProvider {
    let configuration: AviationDataConfiguration
    let session: URLSession = .shared

    var isAuthorizedLiveProvider: Bool { true }

    func bootstrap(airportCode: String) async throws -> AviationSnapshot {
        let url = configuration.baseURL
            .appending(path: "v1")
            .appending(path: "bootstrap")
            .appending(queryItems: [URLQueryItem(name: "airport", value: airportCode)])
        let (data, response) = try await session.data(for: request(url: url))
        try validate(response)
        return try JSONDecoder.aviation.decode(AviationSnapshot.self, from: data)
    }

    func events(airportCode: String) -> AsyncThrowingStream<AviationDataEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = configuration.baseURL
                        .appending(path: "v1")
                        .appending(path: "flights")
                        .appending(path: "stream")
                        .appending(queryItems: [URLQueryItem(name: "airport", value: airportCode)])
                    let (bytes, response) = try await session.bytes(for: request(url: url, acceptsEventStream: true))
                    try validate(response)
                    var parser = ServerSentEventParser()

                    for try await line in bytes.lines {
                        if let event = try parser.consume(line) {
                            continuation.yield(event)
                        }
                    }

                    throw AviationDataError.streamEnded
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func request(url: URL, acceptsEventStream: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if acceptsEventStream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        request.timeoutInterval = acceptsEventStream ? 60 : 20
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw AviationDataError.invalidResponse(http.statusCode)
        }
    }
}

struct UnavailableAviationDataProvider: FlightDataProvider {
    let message: String
    var isAuthorizedLiveProvider: Bool { false }

    func bootstrap(airportCode: String) async throws -> AviationSnapshot {
        throw AviationDataError.unavailable(message)
    }

    func events(airportCode: String) -> AsyncThrowingStream<AviationDataEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AviationDataError.unavailable(message))
        }
    }
}

enum FlightDataProviderFactory {
    static func makeDefault() -> any FlightDataProvider {
        if let configuration = AviationDataConfiguration.fromBundle() {
            return LiveAviationDataProvider(configuration: configuration)
        }

        #if DEBUG
        return SampleAviationDataProvider()
        #else
        return UnavailableAviationDataProvider(
            message: "TestFlight builds require AVIATION_API_BASE_URL and AVIATION_API_TOKEN configured for an authorized backend."
        )
        #endif
    }
}

enum AviationDataEvent: Equatable, Sendable {
    case flightUpsert(FlightTrack)
    case flightDelete(String)
    case weatherUpdate(WeatherSnapshot)
    case alertUpsert(AirspaceAlert)
    case alertDelete(String)
    case heartbeat(Date)

    static func decode(named eventName: String, data: Data, decoder: JSONDecoder = .aviation) throws -> AviationDataEvent {
        switch eventName {
        case "flight.upsert":
            return try .flightUpsert(decoder.decode(FlightPayload.self, from: data).flight)
        case "flight.delete":
            return try .flightDelete(decoder.decode(IDPayload.self, from: data).id)
        case "weather.update":
            return try .weatherUpdate(decoder.decode(WeatherPayload.self, from: data).weather)
        case "alert.upsert":
            return try .alertUpsert(decoder.decode(AlertPayload.self, from: data).alert)
        case "alert.delete":
            return try .alertDelete(decoder.decode(IDPayload.self, from: data).id)
        case "heartbeat":
            return try .heartbeat(decoder.decode(HeartbeatPayload.self, from: data).serverTime)
        default:
            throw AviationDataError.malformedEvent(eventName)
        }
    }
}

private struct FlightPayload: Decodable {
    let flight: FlightTrack
}

private struct WeatherPayload: Decodable {
    let weather: WeatherSnapshot
}

private struct AlertPayload: Decodable {
    let alert: AirspaceAlert
}

private struct IDPayload: Decodable {
    let id: String
}

private struct HeartbeatPayload: Decodable {
    let serverTime: Date
}

struct ServerSentEventParser {
    private var eventName = "message"
    private var dataLines: [String] = []

    mutating func consume(_ line: String) throws -> AviationDataEvent? {
        if line.isEmpty {
            defer {
                eventName = "message"
                dataLines.removeAll(keepingCapacity: true)
            }

            guard !dataLines.isEmpty else { return nil }
            let dataString = dataLines.joined(separator: "\n")
            guard let data = dataString.data(using: .utf8) else {
                throw AviationDataError.malformedEvent(eventName)
            }
            return try AviationDataEvent.decode(named: eventName, data: data)
        }

        if line.hasPrefix("event:") {
            eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            dataLines.append(String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces))
        }

        return nil
    }
}

extension JSONDecoder {
    static var aviation: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var aviation: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}
