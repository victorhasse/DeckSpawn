import XCTest
@testable import CardArenaAR

final class MrsIncredibleVFXTimingTests: XCTestCase {
    func testWindowIsInsideClip() {
        let t = MrsIncredibleVFXTiming(clipDuration: 2, move: .punch)
        XCTAssertFalse(t.isActive(at: 0))
        XCTAssertTrue(t.isActive(at: 1))
        XCTAssertFalse(t.isActive(at: 2))
    }
    func testImpactTrailLastsLongerAndIsBounded() {
        let p = MrsIncredibleVFXTiming(clipDuration: 1, move: .punch)
        let k = MrsIncredibleVFXTiming(clipDuration: 1, move: .kick)
        XCTAssertGreaterThan(k.trailLifetime, p.trailLifetime)
        XCTAssertGreaterThan(k.maxTrails, p.maxTrails)
        XCTAssertLessThanOrEqual(k.maxTrails, 28)
    }
    func testTracksStrongerLimbWithoutCrossingSides() {
        let t = MrsIncredibleVFXTiming(clipDuration: 1, move: .punch)
        let l = SIMD3<Float>(0.1, 0, 0)
        let r = SIMD3<Float>(-0.1, 0, 0)
        let end = l + SIMD3<Float>(0, 0.08, 0)
        let segment = t.strongestSegment(leftBefore: l, leftNow: end,
                                         rightBefore: r, rightNow: r + SIMD3<Float>(0, 0.02, 0))
        XCTAssertEqual(segment?.side, .left)
        XCTAssertEqual(segment?.start, l)
        XCTAssertEqual(segment?.end, end)
    }
    func testStationaryAndInvalidSamplesDoNotDrawTrails() {
        let t = MrsIncredibleVFXTiming(clipDuration: 1, move: .kick)
        let zero = SIMD3<Float>(repeating: 0)
        XCTAssertNil(t.strongestSegment(leftBefore: zero, leftNow: zero,
                                       rightBefore: nil, rightNow: zero))
        XCTAssertNil(t.strongestSegment(leftBefore: zero, leftNow: SIMD3<Float>(1, 0, 0),
                                       rightBefore: zero, rightNow: SIMD3<Float>(.nan, 0, 0)))
    }
    func testRightLimbSurvivesMissingLeftSample() {
        let t = MrsIncredibleVFXTiming(clipDuration: 1, move: .kick)
        let zero = SIMD3<Float>(repeating: 0)
        let end = SIMD3<Float>(0.05, 0, 0)
        let s = t.strongestSegment(leftBefore: nil, leftNow: zero, rightBefore: zero, rightNow: end)
        XCTAssertEqual(s?.side, .right)
        XCTAssertEqual(s?.end, end)
    }
}
