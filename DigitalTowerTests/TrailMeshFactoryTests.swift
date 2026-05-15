import XCTest
import simd
@testable import DigitalTower

@MainActor
final class TrailMeshFactoryTests: XCTestCase {
    func testTrailRibbonGeometryIsFiniteAndTapered() throws {
        let points = [
            SIMD3<Float>(0, 0.42, 0),
            SIMD3<Float>(0.08, 0.43, 0.18),
            SIMD3<Float>(0.15, 0.44, 0.36),
            SIMD3<Float>(0.22, 0.45, 0.54),
            SIMD3<Float>(0.30, 0.46, 0.72)
        ]

        let geometry = try XCTUnwrap(AirspaceTrailMeshFactory.makeTrailRibbonGeometry(
            points: points,
            headingYaw: 0,
            baseWidth: 0.035,
            verticalFade: 0.03
        ))

        XCTAssertEqual(geometry.positions.count, points.count * 2)
        XCTAssertEqual(geometry.normals.count, geometry.positions.count)
        XCTAssertEqual(geometry.indices.count, (points.count - 1) * 6)
        XCTAssertTrue(geometry.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        XCTAssertTrue(geometry.indices.allSatisfy { Int($0) < geometry.positions.count })

        let widths = stride(from: 0, to: geometry.positions.count, by: 2).map {
            simd_distance(geometry.positions[$0], geometry.positions[$0 + 1])
        }
        XCTAssertGreaterThan(try XCTUnwrap(widths.first), try XCTUnwrap(widths.last))

        for index in 1..<widths.count {
            XCTAssertLessThanOrEqual(widths[index], widths[index - 1] + 0.0001)
        }
    }

    func testTrailRibbonGeometryRejectsInsufficientSamples() {
        let geometry = AirspaceTrailMeshFactory.makeTrailRibbonGeometry(
            points: [SIMD3<Float>(0, 0, 0)],
            headingYaw: 0,
            baseWidth: 0.035,
            verticalFade: 0.03
        )
        XCTAssertNil(geometry)
    }
}
