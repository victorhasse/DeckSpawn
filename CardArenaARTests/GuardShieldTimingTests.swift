import XCTest
@testable import CardArenaAR

final class GuardShieldTimingTests: XCTestCase {
    func testBlockIsTimedFromOpponentAttack() {
        XCTAssertEqual(GuardShieldTiming.blockMoment(opponentClipDuration: 3.33),
                       3.33 * 0.92, accuracy: 0.0001)
    }

    func testBlockWaitsForContactPulseBeforeCleanup() {
        let contact = GuardShieldTiming.blockMoment(opponentClipDuration: 2)
        let end = GuardShieldTiming.visibleUntil(
            guardClipDuration: 0.8, opponentClipDuration: 2, blocksImpact: true
        )
        XCTAssertGreaterThan(end, contact + GuardShieldTiming.pulseLifetime)
    }

    func testGuardWithoutBlockIsBrief() {
        let end = GuardShieldTiming.visibleUntil(
            guardClipDuration: 1, opponentClipDuration: 5, blocksImpact: false
        )
        XCTAssertEqual(end, 0.65, accuracy: 0.0001)
    }

    func testGuardDurationIsBounded() {
        let short = GuardShieldTiming.visibleUntil(
            guardClipDuration: 0, opponentClipDuration: 0, blocksImpact: false
        )
        let long = GuardShieldTiming.visibleUntil(
            guardClipDuration: 10, opponentClipDuration: 0, blocksImpact: false
        )
        XCTAssertEqual(short, 0.38, accuracy: 0.0001)
        XCTAssertEqual(long, 0.75, accuracy: 0.0001)
    }

    func testShieldRadiusIsBounded() {
        XCTAssertEqual(GuardShieldTiming.radius(characterHeight: 0), 0.105, accuracy: 0.0001)
        XCTAssertEqual(GuardShieldTiming.radius(characterHeight: 20), 0.23, accuracy: 0.0001)
    }

    func testGuardBreakTriggeredAfterTechniqueContact() {
        let moment = GuardShieldTiming.contactMoment(opponentClipDuration: 2,
                                                      breaksGuard: true)
        XCTAssertEqual(moment, 1.68, accuracy: 0.0001)
    }

    func testGuardAbsorptionKeepsBlueStateTiming() {
        let moment = GuardShieldTiming.contactMoment(opponentClipDuration: 2,
                                                      breaksGuard: false)
        XCTAssertEqual(moment, 1.84, accuracy: 0.0001)
    }

    func testBrokenShieldCleanupOccursAfterCracks() {
        let contact = GuardShieldTiming.contactMoment(opponentClipDuration: 2,
                                                       breaksGuard: true)
        let end = GuardShieldTiming.visibleUntil(
            guardClipDuration: 1, opponentClipDuration: 2,
            blocksImpact: false, breaksGuard: true)
        XCTAssertGreaterThan(end, contact + GuardShieldTiming.breakLifetime)
    }

    func testGuardDrawRemainsNeutral() {
        let end = GuardShieldTiming.visibleUntil(
            guardClipDuration: 1, opponentClipDuration: 3,
            blocksImpact: false, breaksGuard: false)
        XCTAssertEqual(end, 0.65, accuracy: 0.0001)
    }
    func testRealDomeCoversCharacterHeight() {
        XCTAssertGreaterThan(GuardShieldTiming.domeHeight(characterHeight: 0.60), 0.60)
    }

    func testRealDomeKeepsWideCharactersInside() {
        let r = GuardShieldTiming.domeRadius(characterHeight: 0.50, characterWidth: 0.90)
        XCTAssertGreaterThan(r, 0.45)
    }

    func testRealDomeIsLargerThanOldFrontalShield() {
        let radius = GuardShieldTiming.domeRadius(characterHeight: 0.6, characterWidth: 0.2)
        XCTAssertGreaterThan(radius, GuardShieldTiming.radius(characterHeight: 0.6))
    }
    func testDomeOriginUsesStableCharacterPivotEvenForGoku() {
        let pivot = SIMD3<Float>(-0.28, 0.025, 0)
        XCTAssertEqual(GuardShieldTiming.domeOrigin(characterPivot: pivot).y,
                       0.025, accuracy: 0.00001)
    }

    func testDomeDoesNotSinkToAnimatedGokuBoundingMinimum() {
        let pivot = SIMD3<Float>(0.28, 0.025, 0)
        let problematicAnimatedMinimum: Float = -0.275
        XCTAssertGreaterThan(GuardShieldTiming.domeOrigin(characterPivot: pivot).y,
                             problematicAnimatedMinimum)
    }

    func testNewDomeHasHeadClearance() {
        XCTAssertGreaterThan(GuardShieldTiming.domeHeight(characterHeight: 0.60),
                             0.60)
        XCTAssertGreaterThan(GuardShieldTiming.domeRadius(characterHeight: 0.60, characterWidth: 0.20),
                             0.30)
    }
}
