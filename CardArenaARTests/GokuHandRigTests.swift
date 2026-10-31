import XCTest
@testable import CardArenaAR

final class GokuHandRigTests: XCTestCase {
    func testMixamoFlatJointNamesResolveBothHands() {
        let names = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
                     "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
                     "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand"]
        let rig = GokuHandRig(jointNames: names)
        XCTAssertNotNil(rig)
        XCTAssertEqual(rig?.leftChain.last, 7)
        XCTAssertEqual(rig?.rightChain.last, 11)
        XCTAssertEqual(rig?.leftChain.first, 0)
    }

    func testFullHierarchyJointNamesResolvePaths() {
        let names = ["root", "root/hips", "root/hips/spine", "root/hips/spine/leftarm", "root/hips/spine/leftarm/LeftHand",
                     "root/hips/spine/rightarm", "root/hips/spine/rightarm/RightHand"]
        let rig = GokuHandRig(jointNames: names)
        XCTAssertEqual(rig?.leftChain, [0, 1, 2, 3, 4])
        XCTAssertEqual(rig?.rightChain, [0, 1, 2, 5, 6])
    }

    func testIncompleteRigFailsSafely() {
        XCTAssertNil(GokuHandRig(jointNames: ["Hips", "LeftHand", "RightHand"]))
        XCTAssertNil(GokuHandRig(jointNames: ["Hips", "LeftHand"]))
    }

    func testFingersAreNotMistakenForHands() {
        let names = ["Hips", "LeftHandThumb1", "RightHandThumb1"]
        XCTAssertNil(GokuHandRig(jointNames: names))
    }

    func testSphereGrowsWithinChargeWindow() {
        let t = KamehamehaTiming(clipDuration: 2, reactionDelay: 2.1)
        XCTAssertLessThan(t.orbScale(at: t.chargeAt), t.orbScale(at: (t.chargeAt + t.launchAt) / 2))
        XCTAssertEqual(t.orbScale(at: t.launchAt), 1, accuracy: 0.0001)
    }

    func testSuccessfulKamehamehaContactIsBeforeClipEnds() {
        let reaction = KamehamehaTiming.reactionDelayForSuccessfulHit(
            gokuClipDuration: 3.33,
            opponentClipDuration: 1.2
        )
        let timing = KamehamehaTiming(clipDuration: 3.33, reactionDelay: reaction)
        XCTAssertEqual(reaction, 3.33 * 0.92, accuracy: 0.001)
        XCTAssertEqual(timing.impactAt, reaction, accuracy: 0.001)
        XCTAssertLessThan(timing.impactAt, 3.33)
        XCTAssertGreaterThan(timing.impactAt - timing.launchAt, 0.6)
        XCTAssertLessThan(timing.impactAt - timing.launchAt, 0.9)
    }

    func testLongOpponentAnimationIsNotInterruptedByEarlyImpact() {
        let reaction = KamehamehaTiming.reactionDelayForSuccessfulHit(
            gokuClipDuration: 3.33,
            opponentClipDuration: 4.2
        )
        XCTAssertGreaterThanOrEqual(reaction, 4.25 - 0.0001)
    }

    func testNonDamagingKamehamehaAlsoFinishesBeforeClipEnd() {
        let visual = KamehamehaTiming.visualImpactDelay(
            clipDuration: 3.33,
            combatReactionDelay: 3.39,
            hitsDefender: false
        )
        XCTAssertEqual(visual, 3.33 * 0.92, accuracy: 0.001)
        XCTAssertLessThan(visual, 3.33)
    }

    func testDamagingKamehamehaKeepsItsReactionSynchronized() {
        let visual = KamehamehaTiming.visualImpactDelay(
            clipDuration: 3.33,
            combatReactionDelay: 3.08,
            hitsDefender: true
        )
        XCTAssertEqual(visual, 3.08, accuracy: 0.001)
    }

    func testShortClipHasSafeMinimumReactionDelay() {
        let reaction = KamehamehaTiming.reactionDelayForSuccessfulHit(
            gokuClipDuration: 0.1,
            opponentClipDuration: 0.0
        )
        XCTAssertGreaterThanOrEqual(reaction, 0.35)
    }

    func testFlightProgressClamped() {
        let t = KamehamehaTiming(clipDuration: 2, reactionDelay: 2.1)
        XCTAssertEqual(t.flightProgress(at: 0), 0)
        XCTAssertEqual(t.flightProgress(at: t.impactAt), 1)
        XCTAssertEqual(t.flightProgress(at: t.impactAt + 100), 1)
    }
}
