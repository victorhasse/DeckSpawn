import XCTest
@testable import CardArenaAR

final class StormtrooperJointRigTests: XCTestCase {
    func testFlatMixamoArmChain() {
        let names = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1",
                     "mixamorig_Spine2", "mixamorig_RightShoulder", "mixamorig_RightArm",
                     "mixamorig_RightForeArm", "mixamorig_RightHand"]
        let rig = StormtrooperJointRig(jointNames: names)
        XCTAssertEqual(rig?.chain(for: .rightHand), Array(0..<8))
        XCTAssertNil(rig?.chain(for: .leftHand))
    }

    func testFootChainWithoutFullPaths() {
        let names = ["mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg",
                     "mixamorig_LeftFoot"]
        XCTAssertEqual(StormtrooperJointRig(jointNames: names)?.chain(for: .leftFoot),
                       [0, 1, 2, 3])
    }

    func testFullPathJointChain() {
        let names = ["Rig/Hips", "Rig/Hips/RightUpLeg",
                     "Rig/Hips/RightUpLeg/RightLeg",
                     "Rig/Hips/RightUpLeg/RightLeg/RightFoot"]
        XCTAssertEqual(StormtrooperJointRig(jointNames: names)?.chain(for: .rightFoot),
                       [0, 1, 2, 3])
    }

    func testNoMixamoBonesDoesNotInventPositions() {
        XCTAssertNil(StormtrooperJointRig(jointNames: ["root", "head", "cape"]))
    }

    func testActiveJointSelectsMovingLimb() {
        let zero = SIMD3<Float>(repeating: 0)
        let left = SIMD3<Float>(0.22, 0.05, 0)
        let right = SIMD3<Float>(0.02, 0, 0)
        XCTAssertEqual(StormtrooperJointRig.activeJoint(
            leftStart: zero, rightStart: zero,
            leftCurrent: left, rightCurrent: right,
            left: .leftFoot, right: .rightFoot, default: .rightFoot
        ), .leftFoot)
    }

    func testMissingAndStationaryLimbHaveStableFallback() {
        let zero = SIMD3<Float>(repeating: 0)
        XCTAssertEqual(StormtrooperJointRig.activeJoint(
            leftStart: zero, rightStart: zero, leftCurrent: nil, rightCurrent: zero,
            left: .leftHand, right: .rightHand, default: .leftHand
        ), .rightHand)
        XCTAssertEqual(StormtrooperJointRig.activeJoint(
            leftStart: zero, rightStart: zero, leftCurrent: zero, rightCurrent: zero,
            left: .leftHand, right: .rightHand, default: .leftHand
        ), .leftHand)
    }
}
