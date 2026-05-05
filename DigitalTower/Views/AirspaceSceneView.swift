import SwiftUI

struct AirspaceSceneView: View {
    @EnvironmentObject private var model: DigitalTowerModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background(for: proxy.size)
                routeLayer(size: proxy.size)

                if model.overlays.contains(.labels) || model.mode == .flight {
                    labelLayer(size: proxy.size)
                }

                hitTargetLayer(size: proxy.size)

                if model.mode == .weather || model.overlays.contains(.weather) {
                    WeatherOverlayLayer()
                }

                if model.mode == .alerts || model.overlays.contains(.alerts) {
                    AlertOverlayLayer()
                }

                if model.flights.isEmpty {
                    SceneStateOverlay(message: model.dataState.userMessage ?? "No visible traffic for this airport.")
                }
            }
            .overlay(alignment: .bottomLeading) {
                complianceCaption
                    .padding(.leading, 300)
                    .padding(.bottom, 24)
            }
        }
    }

    private func background(for size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let sky = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.12, blue: 0.22),
                    Color(red: 0.04, green: 0.28, blue: 0.48),
                    Color(red: 0.62, green: 0.78, blue: 0.88)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
            context.fill(Path(rect), with: sky)

            if model.mode == .live || model.mode == .flight {
                drawGlobe(in: &context, size: canvasSize)
            } else {
                drawAirport(in: &context, size: canvasSize)
            }

            drawClouds(in: &context, size: canvasSize)
            drawHorizon(in: &context, size: canvasSize)
        }
    }

    private func routeLayer(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            if model.overlays.contains(.altitudeBands) || model.mode == .live {
                drawAltitudeBands(in: &context, size: canvasSize)
            }

            if model.overlays.contains(.runways) || model.mode == .tower || model.mode == .replay {
                drawRunwayOverlay(in: &context, size: canvasSize)
            }

            for flight in model.flights {
                drawRoute(for: flight, in: &context, size: canvasSize)
                drawAircraftSymbol(for: flight, in: &context, size: canvasSize)
            }
        }
    }

    private func labelLayer(size: CGSize) -> some View {
        ForEach(model.flights) { flight in
            FlightSpatialLabel(flight: flight, color: flightColor(for: flight))
                .position(labelPosition(for: flight, in: size))
                .onTapGesture {
                    model.selectFlight(flight)
                }
        }
    }

    private func hitTargetLayer(size: CGSize) -> some View {
        ForEach(model.flights) { flight in
            Button {
                model.selectFlight(flight)
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .position(position(for: flight, in: size))
            .accessibilityLabel("\(flight.callsign), \(flight.aircraft), \(flight.altitudeFeet.formatted()) feet")
        }
    }

    private var complianceCaption: some View {
        Text("For aviation discovery only. Not for navigation, ATC, flight safety, or operational decisions.")
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.36), in: Capsule())
    }

    private func position(for flight: FlightTrack, in size: CGSize) -> CGPoint {
        let deltaLongitude = flight.longitude - model.selectedAirport.longitude
        let deltaLatitude = flight.latitude - model.selectedAirport.latitude
        let altitudeLift = min(0.18, CGFloat(flight.altitudeFeet) / 80_000)
        let normalizedX = (0.5 + CGFloat(deltaLongitude) * 4.2).clamped(to: 0.08...0.92)
        let normalizedY = (0.54 - CGFloat(deltaLatitude) * 5.6 - altitudeLift).clamped(to: 0.12...0.86)
        return CGPoint(x: size.width * normalizedX, y: size.height * normalizedY)
    }

    private func labelPosition(for flight: FlightTrack, in size: CGSize) -> CGPoint {
        let base = position(for: flight, in: size)
        let index = CGFloat(stableIndex(for: flight.callsign, modulo: 5))
        let xOffset: CGFloat = Int(index).isMultiple(of: 2) ? 42 : -46
        let yOffset: CGFloat = -54 - (index * 7)
        return CGPoint(x: base.x + xOffset, y: base.y + yOffset)
    }

    private func drawGlobe(in context: inout GraphicsContext, size: CGSize) {
        var globePath = Path()
        let rect = CGRect(x: -size.width * 0.08, y: size.height * 0.13, width: size.width * 1.16, height: size.height * 0.82)
        globePath.addEllipse(in: rect)
        context.fill(globePath, with: .radialGradient(
            Gradient(colors: [
                Color(red: 0.12, green: 0.42, blue: 0.52).opacity(0.8),
                Color(red: 0.04, green: 0.16, blue: 0.24).opacity(0.98),
                Color.black.opacity(0.86)
            ]),
            center: CGPoint(x: size.width * 0.52, y: size.height * 0.42),
            startRadius: 20,
            endRadius: size.width * 0.72
        ))
        context.stroke(globePath, with: .color(Color.cyan.opacity(0.22)), lineWidth: 3)

        for index in 0..<10 {
            let y = size.height * (0.28 + CGFloat(index) * 0.052)
            var line = Path()
            line.move(to: CGPoint(x: size.width * 0.16, y: y))
            line.addCurve(
                to: CGPoint(x: size.width * 0.86, y: y + CGFloat(index % 2) * 20),
                control1: CGPoint(x: size.width * 0.36, y: y - 42),
                control2: CGPoint(x: size.width * 0.64, y: y + 42)
            )
            context.stroke(line, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
        }

        drawCity("LOS ANGELES", x: 0.23, y: 0.62, in: &context, size: size)
        drawCity("CHICAGO", x: 0.58, y: 0.45, in: &context, size: size)
        drawCity("NEW YORK", x: 0.72, y: 0.46, in: &context, size: size)
        drawCity("MIAMI", x: 0.69, y: 0.72, in: &context, size: size)
    }

    private func drawAirport(in context: inout GraphicsContext, size: CGSize) {
        let groundRect = CGRect(x: size.width * 0.08, y: size.height * 0.42, width: size.width * 0.84, height: size.height * 0.48)
        var ground = Path()
        ground.addRoundedRect(in: groundRect, cornerSize: CGSize(width: 42, height: 42))
        context.fill(ground, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.2, green: 0.34, blue: 0.28).opacity(0.8),
                Color(red: 0.12, green: 0.17, blue: 0.15).opacity(0.98)
            ]),
            startPoint: groundRect.origin,
            endPoint: CGPoint(x: groundRect.maxX, y: groundRect.maxY)
        ))

        let water = CGRect(x: 0, y: size.height * 0.67, width: size.width, height: size.height * 0.35)
        context.fill(Path(water), with: .linearGradient(
            Gradient(colors: [Color.blue.opacity(0.35), Color.black.opacity(0.42)]),
            startPoint: water.origin,
            endPoint: CGPoint(x: water.maxX, y: water.maxY)
        ))

        drawRunway(in: &context, start: CGPoint(x: size.width * 0.25, y: size.height * 0.79), end: CGPoint(x: size.width * 0.62, y: size.height * 0.47), label: "22R")
        drawRunway(in: &context, start: CGPoint(x: size.width * 0.36, y: size.height * 0.84), end: CGPoint(x: size.width * 0.78, y: size.height * 0.53), label: "22L")
        drawRunway(in: &context, start: CGPoint(x: size.width * 0.18, y: size.height * 0.58), end: CGPoint(x: size.width * 0.62, y: size.height * 0.68), label: "31L")

        for index in 0..<22 {
            let x = size.width * (0.16 + CGFloat(index % 8) * 0.09)
            let y = size.height * (0.53 + CGFloat(index / 8) * 0.09)
            var taxi = Path()
            taxi.move(to: CGPoint(x: x, y: y))
            taxi.addLine(to: CGPoint(x: x + size.width * 0.08, y: y + 18))
            context.stroke(taxi, with: .color(Color.yellow.opacity(0.16)), lineWidth: 1.2)
        }
    }

    private func drawRunway(in context: inout GraphicsContext, start: CGPoint, end: CGPoint, label: String) {
        var runway = Path()
        runway.move(to: start)
        runway.addLine(to: end)
        context.stroke(runway, with: .color(Color.white.opacity(0.72)), lineWidth: 9)
        context.stroke(runway, with: .color(Color.black.opacity(0.52)), lineWidth: 5)

        let text = Text(label).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.82))
        context.draw(text, at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
    }

    private func drawClouds(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<7 {
            let x = size.width * (0.08 + CGFloat(index) * 0.14)
            let y = size.height * (0.14 + CGFloat(index % 3) * 0.08)
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: x, y: y, width: 130, height: 38))
            cloud.addEllipse(in: CGRect(x: x + 42, y: y - 18, width: 88, height: 56))
            context.fill(cloud, with: .color(Color.white.opacity(0.18)))
        }
    }

    private func drawHorizon(in context: inout GraphicsContext, size: CGSize) {
        var horizon = Path()
        horizon.move(to: CGPoint(x: 0, y: size.height * 0.38))
        horizon.addCurve(
            to: CGPoint(x: size.width, y: size.height * 0.36),
            control1: CGPoint(x: size.width * 0.3, y: size.height * 0.3),
            control2: CGPoint(x: size.width * 0.7, y: size.height * 0.42)
        )
        context.stroke(horizon, with: .color(Color.white.opacity(0.24)), lineWidth: 1)
    }

    private func drawAltitudeBands(in context: inout GraphicsContext, size: CGSize) {
        for (index, label) in ["FL390", "FL340", "FL290", "FL260"].enumerated() {
            let y = size.height * (0.24 + CGFloat(index) * 0.12)
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.16, y: y))
            path.addLine(to: CGPoint(x: size.width * 0.82, y: y))
            context.stroke(path, with: .color(Color.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            context.draw(Text(label).font(.caption).foregroundStyle(.white.opacity(0.64)), at: CGPoint(x: size.width * 0.18, y: y - 10))
        }
    }

    private func drawRunwayOverlay(in context: inout GraphicsContext, size: CGSize) {
        let labels = [("22L", 0.54, 0.67), ("22R", 0.62, 0.59), ("31L", 0.42, 0.73)]
        for item in labels {
            let rect = CGRect(x: size.width * item.1 - 24, y: size.height * item.2 - 12, width: 48, height: 24)
            var pill = Path()
            pill.addRoundedRect(in: rect, cornerSize: CGSize(width: 8, height: 8))
            context.fill(pill, with: .color(DTColors.appleBlue.opacity(0.48)))
            context.draw(Text(item.0).font(.caption.weight(.bold)).foregroundStyle(.white), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func drawRoute(for flight: FlightTrack, in context: inout GraphicsContext, size: CGSize) {
        let p = position(for: flight, in: size)
        let color = flightColor(for: flight)
        var route = Path()
        route.move(to: CGPoint(x: p.x - size.width * 0.18, y: p.y + size.height * 0.16))
        route.addCurve(
            to: p,
            control1: CGPoint(x: p.x - size.width * 0.12, y: p.y - size.height * 0.10),
            control2: CGPoint(x: p.x - size.width * 0.04, y: p.y + size.height * 0.08)
        )
        context.stroke(route, with: .color(color.opacity(0.82)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        var trail = Path()
        trail.move(to: p)
        trail.addCurve(
            to: CGPoint(x: p.x + size.width * 0.12, y: p.y - size.height * 0.08),
            control1: CGPoint(x: p.x + size.width * 0.03, y: p.y - 44),
            control2: CGPoint(x: p.x + size.width * 0.10, y: p.y + 20)
        )
        context.stroke(trail, with: .color(color.opacity(0.28)), style: StrokeStyle(lineWidth: 1.4, dash: [5, 7]))
    }

    private func drawAircraftSymbol(for flight: FlightTrack, in context: inout GraphicsContext, size: CGSize) {
        let p = position(for: flight, in: size)
        let scale: CGFloat = model.selectedFlight?.id == flight.id ? 1.25 : 1
        let color = flightColor(for: flight)
        var aircraft = Path()
        aircraft.move(to: CGPoint(x: p.x, y: p.y - 12 * scale))
        aircraft.addLine(to: CGPoint(x: p.x, y: p.y + 13 * scale))
        aircraft.move(to: CGPoint(x: p.x - 17 * scale, y: p.y + 2 * scale))
        aircraft.addLine(to: CGPoint(x: p.x + 17 * scale, y: p.y + 2 * scale))
        aircraft.move(to: CGPoint(x: p.x - 8 * scale, y: p.y + 10 * scale))
        aircraft.addLine(to: CGPoint(x: p.x + 8 * scale, y: p.y + 10 * scale))
        context.stroke(aircraft, with: .color(Color.white.opacity(0.92)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

        var nose = Path()
        nose.addEllipse(in: CGRect(x: p.x - 3 * scale, y: p.y - 14 * scale, width: 6 * scale, height: 6 * scale))
        context.fill(nose, with: .color(color.opacity(0.92)))
    }

    private func flightColor(for flight: FlightTrack) -> Color {
        if model.selectedFlight?.id == flight.id {
            return .white
        }

        switch flight.category {
        case .cargo:
            return .yellow
        case .privateJet:
            return .purple
        case .commercial:
            let palette: [Color] = [.cyan, .green, .orange, .blue]
            return palette[stableIndex(for: flight.id, modulo: palette.count)]
        case .unknown:
            return DTColors.appleBlue
        }
    }

    private func stableIndex(for value: String, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        let total = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return abs(total) % modulo
    }

    private func drawCity(_ name: String, x: CGFloat, y: CGFloat, in context: inout GraphicsContext, size: CGSize) {
        let point = CGPoint(x: size.width * x, y: size.height * y)
        var glow = Path()
        glow.addEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
        context.fill(glow, with: .color(Color.yellow.opacity(0.78)))
        context.draw(Text(name).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.8)), at: CGPoint(x: point.x + 44, y: point.y - 12))
    }
}

struct WeatherOverlayLayer: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<4 {
                var band = Path()
                let y = size.height * (0.30 + CGFloat(index) * 0.12)
                band.move(to: CGPoint(x: size.width * -0.05, y: y))
                band.addCurve(
                    to: CGPoint(x: size.width * 1.05, y: y + CGFloat(index % 2 == 0 ? 90 : -80)),
                    control1: CGPoint(x: size.width * 0.25, y: y - 110),
                    control2: CGPoint(x: size.width * 0.72, y: y + 130)
                )
                context.stroke(band, with: .color(Color.cyan.opacity(0.26)), lineWidth: 2)
            }

            let stormRect = CGRect(x: size.width * 0.50, y: size.height * 0.20, width: size.width * 0.26, height: size.height * 0.24)
            var storm = Path()
            storm.addEllipse(in: stormRect)
            context.fill(storm, with: .radialGradient(
                Gradient(colors: [.red.opacity(0.32), .yellow.opacity(0.22), .green.opacity(0.18), .clear]),
                center: CGPoint(x: stormRect.midX, y: stormRect.midY),
                startRadius: 4,
                endRadius: stormRect.width * 0.6
            ))
        }
        .allowsHitTesting(false)
    }
}

struct AlertOverlayLayer: View {
    var body: some View {
        Canvas { context, size in
            let zones: [(Color, CGRect)] = [
                (.red, CGRect(x: size.width * 0.45, y: size.height * 0.45, width: size.width * 0.18, height: size.height * 0.10)),
                (.yellow, CGRect(x: size.width * 0.62, y: size.height * 0.53, width: size.width * 0.20, height: size.height * 0.14)),
                (.purple, CGRect(x: size.width * 0.49, y: size.height * 0.72, width: size.width * 0.24, height: size.height * 0.13))
            ]

            for zone in zones {
                var path = Path()
                path.addRoundedRect(in: zone.1, cornerSize: CGSize(width: 44, height: 44))
                context.fill(path, with: .color(zone.0.opacity(0.14)))
                context.stroke(path, with: .color(zone.0.opacity(0.66)), style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
            }
        }
        .allowsHitTesting(false)
    }
}

struct FlightSpatialLabel: View {
    let flight: FlightTrack
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flight.callsign)
                .font(.caption.weight(.bold))
            HStack(spacing: 6) {
                Text(flight.aircraft)
                Text("\(flight.altitudeFeet.formatted()) ft")
            }
            .font(.caption2)
            .monoMetric()
            .foregroundStyle(Color.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(color)
                .frame(width: 38, height: 2)
                .offset(x: 10, y: 1)
        }
    }
}

private struct SceneStateOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 26, weight: .semibold))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
