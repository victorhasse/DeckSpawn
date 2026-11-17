import XCTest
@testable import CardArenaAR

final class MrsIncredibleJointRigTests: XCTestCase {
    func testFlatArmChain() {
        let names = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1",
                     "mixamorig_Spine2", "mixamorig_RightShoulder", "mixamorig_RightArm",
                     "mixamorig_RightForeArm", "mixamorig_RightHand"]
        let rig = MrsIncredibleJointRig(jointNames: names)
        XCTAssertEqual(rig?.chain(for: .rightHand), Array(0..<8))
        XCTAssertNil(rig?.chain(for: .leftHand))
    }
    func testHierarchicalFootChain() {
        let names = ["Rig/Hips", "Rig/Hips/LeftUpLeg", "Rig/Hips/LeftUpLeg/LeftLeg",
                     "Rig/Hips/LeftUpLeg/LeftLeg/LeftFoot"]
        XCTAssertEqual(MrsIncredibleJointRig(jointNames: names)?.chain(for: .leftFoot), [0, 1, 2, 3])
    }
    func testMissingRig() {
        XCTAssertNil(MrsIncredibleJointRig(jointNames: ["root", "head"]))
    }
}
