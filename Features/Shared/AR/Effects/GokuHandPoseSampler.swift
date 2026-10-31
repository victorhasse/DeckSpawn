import RealityKit
import simd

/// Resolves joint transforms in the *animated* skinned model's local space.
/// For Mixamo, each joint transform is relative to its parent.
/// The sampler does not create or modify entities or USDZ assets.
final class GokuHandPoseSampler {
    private weak var model: ModelEntity?
    private let rig: GokuHandRig
    private var didWarnAboutPose = false

    init?(character: Entity) {
        guard let pair = Self.findRig(in: character) else { return nil }
        self.model = pair.0
        self.rig = pair.1
        #if DEBUG
        print("[DeckSpawn][VFX] Goku: mãos do rig encontradas, acompanhamento ativo")
        #endif
    }

    func midpoint(in arena: AnchorEntity, attacker: Entity) -> SIMD3<Float>? {
        guard let model, model.parent != nil else { return nil }
        let joints = model.jointTransforms
        func endpoint(_ chain: [Int]) -> SIMD3<Float>? {
            var matrix = matrix_identity_float4x4
            for i in chain {
                guard joints.indices.contains(i) else { return nil }
                matrix = simd_mul(matrix, joints[i].matrix)
            }
            let v = simd_mul(matrix, SIMD4<Float>(0, 0, 0, 1))
            guard abs(v.w) > 0.00001 else { return nil }
            let point = SIMD3<Float>(v.x, v.y, v.z) / v.w
            return model.convert(position: point, to: arena)
        }
        guard let left = endpoint(rig.leftChain),
              let right = endpoint(rig.rightChain) else { return nil }
        let mid = (left + right) * 0.5
        guard mid.x.isFinite, mid.y.isFinite, mid.z.isFinite else { return nil }

        // Protect against models with joint transforms in a different unit or
        // coordinate convention. Never spawn the orb underground or far away.
        let bounds = attacker.visualBounds(recursive: true, relativeTo: arena)
        let margin: Float = 0.18
        guard mid.x >= bounds.min.x - margin, mid.x <= bounds.max.x + margin,
              mid.y >= bounds.min.y - margin, mid.y <= bounds.max.y + margin,
              mid.z >= bounds.min.z - margin, mid.z <= bounds.max.z + margin else {
            if !didWarnAboutPose {
                didWarnAboutPose = true
                #if DEBUG
                print("[DeckSpawn][VFX] Goku: articulações fora dos limites; usando fallback")
                #endif
            }
            return nil
        }
        return mid
    }

    private static func findRig(in entity: Entity) -> (ModelEntity, GokuHandRig)? {
        if let model = entity as? ModelEntity,
           let rig = GokuHandRig(jointNames: model.jointNames) {
            return (model, rig)
        }
        for child in entity.children {
            if let result = findRig(in: child) { return result }
        }
        return nil
    }
}
