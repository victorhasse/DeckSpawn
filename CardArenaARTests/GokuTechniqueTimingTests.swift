import XCTest
@testable import CardArenaAR

final class GokuTechniqueTimingTests: XCTestCase {
    func testThreeDistinctBeatsAreInsideClip() {
        let timing = GokuTechniqueTiming(clipDuration: 3.0)
        let moments = GokuTechniqueTiming.beats.map { timing.moment(for: $0) }
        XCTAssertEqual(moments.count, 3)
        XCTAssertTrue(zip(moments, moments.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
        XCTAssertTrue(moments.allSatisfy { $0 > 0 && $0 < 3.0 })
    }

    func testPunchesAlternateHands() {
        let hands = GokuTechniqueTiming.beats.map(\.hand)
        XCTAssertEqual(hands, [.right, .left, .right])
    }

    func testBeatsScaleWithActualClipDuration() {
        let short = GokuTechniqueTiming(clipDuration: 2)
        let long = GokuTechniqueTiming(clipDuration: 4)
        for beat in GokuTechniqueTiming.beats {
            XCTAssertEqual(long.moment(for: beat), short.moment(for: beat) * 2, accuracy: 0.0001)
        }
    }

    func testClipHasSafeMinimumDuration() {
        let timing = GokuTechniqueTiming(clipDuration: 0)
        XCTAssertEqual(timing.clipDuration, 0.30, accuracy: 0.0001)
        XCTAssertGreaterThan(timing.finalAccentAt, 0)
    }

    func testAccentsHaveShortLifetimes() {
        XCTAssertLessThan(GokuTechniqueTiming.streakLifetime, 0.25)
        XCTAssertLessThan(GokuTechniqueTiming.contactLifetime, 0.25)
    }

    func testThreeBeatsIncreaseInVisualStrength() {
        let strengths = GokuTechniqueTiming.beats.map(\.strength)
        XCTAssertEqual(strengths.count, 3)
        XCTAssertLessThan(strengths[0], strengths[1])
        XCTAssertLessThan(strengths[1], strengths[2])
    }

    func testSlashesAndMinorBurstsAreVeryShort() {
        XCTAssertLessThan(GokuTechniqueTiming.slashLifetime, 0.15)
        XCTAssertLessThan(GokuTechniqueTiming.contactLifetime, 0.15)
    }

    func testFinisherIsStrongerAndSlightlyLonger() {
        XCTAssertGreaterThan(GokuTechniqueTiming.finalImpactStrength,
                             GokuTechniqueTiming.beats[1].strength)
        XCTAssertGreaterThan(GokuTechniqueTiming.finisherLifetime,
                             GokuTechniqueTiming.contactLifetime)
    }

    func testVisualBeatsDoNotRequireExtraDamageEvents() {
        // Visual beats are descriptive only: timing has no HP or damage fields.
        let timing = GokuTechniqueTiming(clipDuration: 3.0)
        XCTAssertEqual(GokuTechniqueTiming.beats.count, 3)
        XCTAssertLessThan(timing.finalAccentAt, timing.clipDuration)
    }

    func testVisualParametersStayWithinReasonableScale() {
        XCTAssertTrue(GokuTechniqueTiming.beats.allSatisfy { $0.strength > 0 && $0.strength < 1.5 })
        XCTAssertGreaterThan(GokuTechniqueTiming.finalImpactStrength, 0)
        XCTAssertLessThan(GokuTechniqueTiming.finisherLifetime, 0.25)
    }
}
