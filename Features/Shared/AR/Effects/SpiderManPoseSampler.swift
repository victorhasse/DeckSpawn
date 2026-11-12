import RealityKit
import simd

/// Reads the *animated* Mixamo pose in arena coordinates. Read-only: no bones
/// or imported model transforms are changed by these effects.
final class SpiderManPoseSampler {
    private weak var model: ModelEntity?
    private let rig: SpiderManJointRig
    private var warned = false
    // Arena anchors stay fixed during one attack; avoid a costly visualBounds
    // tree walk for every hand/foot on every AR frame.
    private var envelope: (min: SIMD3<Float>, max: SIMD3<Float>)?

    init?(character: Entity) {
        guard let match = Self.findRig(in: character) else { return nil }
        model = match.0
        rig = match.1
        #if DEBUG
        print("[DeckSpawn][SpiderVFX] Rig Mixamo encontrado; rastreamento das mãos/pés ativo")
        #endif
    }

    func point(_ joint: SpiderManJointRig.Joint,
               in arena: AnchorEntity,
               character: Entity) -> SIMD3<Float>? {
        guard let model, model.parent != nil,
              let chain = rig.chain(for: joint) else { return nil }
        let transforms = model.jointTransforms
        var matrix = matrix_identity_float4x4
        for i in chain {
            guard transforms.indices.contains(i) else { return nil }
            matrix = simd_mul(matrix, transforms[i].matrix)
        }
        let v = simd_mul(matrix, SIMD4<Float>(0, 0, 0, 1))
        guard abs(v.w) > 0.00001 else { return nil }
        let local = SIMD3<Float>(v.x, v.y, v.z) / v.w
        let result = model.convert(position: local, to: arena)
        guard result.x.isFinite, result.y.isFinite, result.z.isFinite else { return nil }

        // Guard against malformed transforms in the supplied USDZ. A spinning
        // capoeira leg can extend beyond the bind pose, hence the generous margin.
        if envelope == nil {
            let bounds = character.visualBounds(recursive: true, relativeTo: arena)
            envelope = (bounds.min, bounds.max)
        }
        guard let envelope else { return nil }
        let margin: Float = 0.34
        guard result.x >= envelope.min.x - margin, result.x <= envelope.max.x + margin,
              result.y >= envelope.min.y - margin, result.y <= envelope.max.y + margin,
              result.z >= envelope.min.z - margin, result.z <= envelope.max.z + margin else {
            if !warned {
                warned = true
                #if DEBUG
                print("[DeckSpawn][SpiderVFX] Pose fora dos limites; fallback seguro")
                #endif
            }
            return nil
        }
        return result
    }

    private static func findRig(in entity: Entity) -> (ModelEntity, SpiderManJointRig)? {
        if let model = entity as? ModelEntity,
           let rig = SpiderManJointRig(jointNames: model.jointNames) {
            return (model, rig)
        }
        for child in entity.children {
            if let match = findRig(in: child) { return match }
        }
        return nil
    }
}
