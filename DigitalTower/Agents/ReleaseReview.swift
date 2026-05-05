import Foundation

enum ReleaseGateState: String {
    case approved = "APPROVED_FOR_TESTFLIGHT"
    case requiresImprovement = "REQUIRES_IMPROVEMENT"
    case blocked = "BLOCKED"
}

enum ReleaseIssueSeverity: String {
    case p0 = "P0 Blocker"
    case p1 = "P1 Critical"
    case p2 = "P2 Major"
    case p3 = "P3 Minor"
}

struct ReleaseIssue: Identifiable {
    let id: String
    let severity: ReleaseIssueSeverity
    let ownerAgent: String
    let title: String
    let fixCondition: String
}

struct ReleaseReviewResult {
    let state: ReleaseGateState
    let summary: String
    let issues: [ReleaseIssue]
}

struct FinalReleaseReviewAgent {
    func review(context: AppContext) -> ReleaseReviewResult {
        var issues: [ReleaseIssue] = []

        if !context.isAuthorizedLiveData {
            issues.append(
                ReleaseIssue(
                    id: "authorized-live-data",
                    severity: .p0,
                    ownerAgent: "Data Agent",
                    title: "Authorized aviation backend is not active",
                    fixCondition: "Configure AVIATION_API_BASE_URL and AVIATION_API_TOKEN for the contracted backend before TestFlight distribution."
                )
            )
        }

        if context.freshness?.isStale == true {
            issues.append(
                ReleaseIssue(
                    id: "stale-data",
                    severity: .p1,
                    ownerAgent: "Data Agent",
                    title: "Aviation data is stale",
                    fixCondition: "Restore SSE stream and freshness heartbeat before inviting testers."
                )
            )
        }

        if context.flights.isEmpty {
            issues.append(
                ReleaseIssue(
                    id: "empty-traffic",
                    severity: .p1,
                    ownerAgent: "Product Agent",
                    title: "No traffic available for selected airport",
                    fixCondition: "Show a valid authorized traffic set or a clear no-traffic state for the selected airport."
                )
            )
        }

        let state: ReleaseGateState
        if issues.contains(where: { $0.severity == .p0 }) {
            state = .blocked
        } else if issues.isEmpty {
            state = .approved
        } else {
            state = .requiresImprovement
        }

        let summary: String
        switch state {
        case .approved:
            summary = "Runtime release checks are passing for TestFlight. External signing, App Store Connect, privacy policy, and review metadata still need owner-provided values."
        case .requiresImprovement:
            summary = "Runtime release checks found issues that should be fixed before broad TestFlight rollout."
        case .blocked:
            summary = "TestFlight distribution is blocked until authorized aviation data is configured."
        }

        return ReleaseReviewResult(state: state, summary: summary, issues: issues)
    }
}
