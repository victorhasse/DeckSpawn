import XCTest
@testable import CardArenaAR

final class KamehamehaTimingTests: XCTestCase {
    func testChargePrecedesLaunchAndImpact() {
        let timing = KamehamehaTiming(clipDuration: 1.5, reactionDelay: 1.6)
        XCTAssertGreaterThan(timing.chargeAt, 0)
        XCTAssertLessThan(timing.chargeAt, timing.launchAt)
        XCTAssertLessThan(timing.launchAt, timing.impactAt)
        XCTAssertLessThan(timing.impactAt, timing.cleanupAt)
    }

    func testImpactDoesNotPrecedeDamageReaction() {
        let timing = KamehamehaTiming(clipDuration: 1.2, reactionDelay: 1.85)
        XCTAssertGreaterThanOrEqual(timing.impactAt, 1.85)
    }

    func testMinimumDurationAllowsVeryShortClip() {
        let timing = KamehamehaTiming(clipDuration: 0, reactionDelay: 0)
        XCTAssertGreaterThan(timing.launchAt, timing.chargeAt)
        XCTAssertGreaterThan(timing.impactAt, timing.launchAt)
    }

    func testSecondRoundCanUseDifferentClipDuration() {
        let short = KamehamehaTiming(clipDuration: 0.8, reactionDelay: 0.85)
        let long = KamehamehaTiming(clipDuration: 2.0, reactionDelay: 2.05)
        XCTAssertGreaterThan(long.launchAt, short.launchAt)
        XCTAssertGreaterThan(long.impactAt, short.impactAt)
    }
}
