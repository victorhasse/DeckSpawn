import Foundation

struct CardDefinition: Identifiable, Hashable {

    var id: String {
        referenceImageName
    }

    let referenceImageName: String
    let displayName: String
    let modelName: String

    let modelHeight: Float
    let yawOffset: Float

    let maxHP: Int
    let attackPower: Int

    let animations: CharacterAnimationSet?

    init(
        referenceImageName: String,
        displayName: String,
        modelName: String,
        modelHeight: Float,
        yawOffset: Float,
        maxHP: Int,
        attackPower: Int,
        animations: CharacterAnimationSet? = nil
    ) {

        self.referenceImageName = referenceImageName
        self.displayName = displayName
        self.modelName = modelName
        self.modelHeight = modelHeight
        self.yawOffset = yawOffset
        self.maxHP = maxHP
        self.attackPower = attackPower
        self.animations = animations
    }
}
