import XCTest
@testable import CardArenaAR

final class SpiderManJointRigTests: XCTestCase {
    func testMixamoFlatHandAndFootChains() {
        let names = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"
        ]
        let rig = SpiderManJointRig(jointNames: names)
        XCTAssertNotNil(rig)
        XCTAssertEqual(rig?.chain(for: .rightHand), [0, 1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(rig?.chain(for: .leftHand)?.last, 11)
        XCTAssertEqual(rig?.chain(for: .rightFoot), [0, 12, 13, 14])
        XCTAssertEqual(rig?.chain(for: .leftFoot), [0, 15, 16, 17])
    }

    func testPathBasedRigSupportsSkeletonHierarchy() {
        let names = [
            "root", "root/Hips", "root/Hips/Spine", "root/Hips/Spine/RightArm",
            "root/Hips/Spine/RightArm/RightHand", "root/Hips/RightUpLeg",
            "root/Hips/RightUpLeg/RightLeg", "root/Hips/RightUpLeg/RightLeg/RightFoot"
        ]
        let rig = SpiderManJointRig(jointNames: names)
        XCTAssertEqual(rig?.chain(for: .rightHand), [0, 1, 2, 3, 4])
        XCTAssertEqual(rig?.chain(for: .rightFoot), [0, 1, 5, 6, 7])
    }

    func testMissingRigDoesNotCrash() {
        XCTAssertNil(SpiderManJointRig(jointNames: ["mesh", "torso", "tail"]))
        XCTAssertNil(SpiderManJointRig(jointNames: ["LeftHand", "RightFoot"]))
    }

    func testTechniqueUsesOppositeOfPreparatoryArm() {
        XCTAssertEqual(SpiderManJointRig.webThrowingHand(oppositeOf: .rightHand), .leftHand)
        XCTAssertEqual(SpiderManJointRig.webThrowingHand(oppositeOf: .leftHand), .rightHand)
    }

    func testFingerNamesAreNotMistakenForWrists() {
        XCTAssertNil(SpiderManJointRig(jointNames: ["LeftHandThumb1", "RightHandIndex1"]))
    }
}
