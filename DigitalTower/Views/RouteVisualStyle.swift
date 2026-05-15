import UIKit

enum RouteVisualType: CaseIterable {
    case arrivalFinal
    case landingRollout
    case departureTakeoff
    case departureClimb
    case holding
    case goAround
    case altitudeRing
    case runwayGuide
    case backgroundTraffic
}

struct RouteVisualStyle {
    let color: UIColor
    let futureColor: UIColor
    let trailOpacity: CGFloat
    let futureOpacity: CGFloat
    let trailWidth: Float
    let futureThickness: Float
    let trailPointLimit: Int
    let futureSampleCount: Int
    let futureProgressSpan: Float
    let routePace: Float
    let usesGentleEasing: Bool

    static func style(for type: RouteVisualType) -> RouteVisualStyle {
        switch type {
        case .arrivalFinal:
            return RouteVisualStyle(
                color: .systemCyan,
                futureColor: .systemBlue,
                trailOpacity: 0.58,
                futureOpacity: 0.62,
                trailWidth: 1.08,
                futureThickness: 0.014,
                trailPointLimit: 18,
                futureSampleCount: 18,
                futureProgressSpan: 0.34,
                routePace: 0.030,
                usesGentleEasing: true
            )
        case .landingRollout:
            return RouteVisualStyle(
                color: UIColor(white: 0.95, alpha: 1),
                futureColor: .systemCyan,
                trailOpacity: 0.34,
                futureOpacity: 0.34,
                trailWidth: 0.72,
                futureThickness: 0.009,
                trailPointLimit: 9,
                futureSampleCount: 8,
                futureProgressSpan: 0.12,
                routePace: 0.018,
                usesGentleEasing: true
            )
        case .departureTakeoff:
            return RouteVisualStyle(
                color: .systemOrange,
                futureColor: .systemOrange,
                trailOpacity: 0.58,
                futureOpacity: 0.64,
                trailWidth: 1.0,
                futureThickness: 0.016,
                trailPointLimit: 15,
                futureSampleCount: 18,
                futureProgressSpan: 0.36,
                routePace: 0.032,
                usesGentleEasing: true
            )
        case .departureClimb:
            return RouteVisualStyle(
                color: .systemOrange,
                futureColor: .systemOrange,
                trailOpacity: 0.42,
                futureOpacity: 0.46,
                trailWidth: 0.86,
                futureThickness: 0.012,
                trailPointLimit: 14,
                futureSampleCount: 12,
                futureProgressSpan: 0.30,
                routePace: 0.026,
                usesGentleEasing: true
            )
        case .holding:
            return RouteVisualStyle(
                color: .systemPurple,
                futureColor: .systemPurple,
                trailOpacity: 0.38,
                futureOpacity: 0.56,
                trailWidth: 0.82,
                futureThickness: 0.012,
                trailPointLimit: 20,
                futureSampleCount: 24,
                futureProgressSpan: 0.50,
                routePace: 0.035,
                usesGentleEasing: false
            )
        case .goAround:
            return RouteVisualStyle(
                color: .systemRed,
                futureColor: .systemOrange,
                trailOpacity: 0.62,
                futureOpacity: 0.68,
                trailWidth: 1.08,
                futureThickness: 0.016,
                trailPointLimit: 18,
                futureSampleCount: 20,
                futureProgressSpan: 0.42,
                routePace: 0.032,
                usesGentleEasing: true
            )
        case .altitudeRing:
            return RouteVisualStyle(
                color: UIColor(white: 0.72, alpha: 1),
                futureColor: UIColor(white: 0.72, alpha: 1),
                trailOpacity: 0.10,
                futureOpacity: 0.10,
                trailWidth: 0.25,
                futureThickness: 0.004,
                trailPointLimit: 8,
                futureSampleCount: 0,
                futureProgressSpan: 0,
                routePace: 0,
                usesGentleEasing: false
            )
        case .runwayGuide:
            return RouteVisualStyle(
                color: .white,
                futureColor: .systemGreen,
                trailOpacity: 0.58,
                futureOpacity: 0.50,
                trailWidth: 0.42,
                futureThickness: 0.009,
                trailPointLimit: 8,
                futureSampleCount: 0,
                futureProgressSpan: 0,
                routePace: 0,
                usesGentleEasing: false
            )
        case .backgroundTraffic:
            return RouteVisualStyle(
                color: .systemBlue,
                futureColor: .systemBlue,
                trailOpacity: 0.14,
                futureOpacity: 0.12,
                trailWidth: 0.52,
                futureThickness: 0.006,
                trailPointLimit: 10,
                futureSampleCount: 7,
                futureProgressSpan: 0.18,
                routePace: 0.012,
                usesGentleEasing: false
            )
        }
    }
}

extension FlightTrack.Phase {
    var routeVisualType: RouteVisualType {
        switch self {
        case .downwind, .baseTurn, .descent, .finalApproach, .final, .landingFlare:
            return .arrivalFinal
        case .touchdown, .rollout, .taxiIn, .landed:
            return .landingRollout
        case .takeoffRoll, .rotation, .takeoff, .lineUp:
            return .departureTakeoff
        case .initialClimb, .departureTurn, .departureClimb, .climb:
            return .departureClimb
        case .holding:
            return .holding
        case .goAround:
            return .goAround
        case .cruise:
            return .backgroundTraffic
        case .pushback, .taxi, .taxiOut:
            return .runwayGuide
        }
    }

    var routeVisualStyle: RouteVisualStyle {
        RouteVisualStyle.style(for: routeVisualType)
    }
}
