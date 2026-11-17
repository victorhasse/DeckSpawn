import RealityKit
import simd

/// Reads animated Mixamo joint transforms in the shared stage coordinate space.
/// Does not modify the skeleton, the imported model, or the combat animation.
final class StormtrooperPoseSampler {
    private weak var model: ModelEntity?
    private let rig: StormtrooperJointRig
    private var envelope: (min: SIMD3<Float>, max: SIMD3<Float>)?
    private var didWarn = false

    init?(character: Entity) {
        guard let match = Self.findRig(in: character) else { return nil }
        model = match.model
        rig = match.rig
        #if DEBUG
        print("[DeckSpawn][TrooperVFX] Mixamo rig encontrado para mãos/pés")
        #endif
    }

    func point(_ joint: StormtrooperJointRig.Joint,
               in arena: AnchorEntity, character: Entity) -> SIMD3<Float>? {
        guard let model, model.parent != nil,
              let chain = rig.chain(for: joint) else { return nil }
        let transforms = model.jointTransforms
        var matrix = matrix_identity_float4x4
        for index in chain {
            guard transforms.indices.contains(index) else { return nil }
            matrix = simd_mul(matrix, transforms[index].matrix)
        }
        let transformed = simd_mul(matrix, SIMD4<Float>(0, 0, 0, 1))
        guard abs(transformed.w) > 0.00001 else { return nil }
        let local = SIMD3<Float>(transformed.x, transformed.y, transformed.z) / transformed.w
        let p = model.convert(position: local, to: arena)
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return nil }

        if envelope == nil {
            let bounds = character.visualBounds(recursive: true, relativeTo: arena)
            envelope = (bounds.min, bounds.max)
        }
        guard let envelope else { return nil }
        // A spinning kick may exit the bind-pose bounds significantly.
        let margin: Float = 0.45
        guard p.x >= envelope.min.x - margin, p.x <= envelope.max.x + margin,
              p.y >= envelope.min.y - margin, p.y <= envelope.max.y + margin,
              p.z >= envelope.min.z - margin, p.z <= envelope.max.z + margin else {
            if !didWarn {
                didWarn = true
                #if DEBUG
                print("[DeckSpawn][TrooperVFX] Articulação fora do envelope; usando fallback")
                #endif
            }
            return nil
        }
        return p
    }

    private static func findRig(in entity: Entity)
        -> (model: ModelEntity, rig: StormtrooperJointRig)? {
        if let model = entity as? ModelEntity,
           let rig = StormtrooperJointRig(jointNames: model.jointNames) {
            return (model, rig)
        }
        for child in entity.children {
            if let found = findRig(in: child) { return found }
        }
        return nil
    }
}
