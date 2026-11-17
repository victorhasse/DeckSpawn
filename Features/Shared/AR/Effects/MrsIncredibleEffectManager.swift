import Foundation
import RealityKit
import UIKit
import simd
import QuartzCore
import Combine

/// Warm motion trails. No floating arcs, circles or fabricated limb motion.
/// Only the existing single-player battle presentation starts these effects.
final class MrsIncredibleEffectManager {
    private var generation = 0
    private var subscriptions: [UUID: any Cancellable] = [:]
    private var roots: [UUID: Entity] = [:]
    private let red = UIColor(red: 0.96, green: 0.09, blue: 0.055, alpha: 1)
    private let orange = UIColor(red: 1, green: 0.43, blue: 0.055, alpha: 1)
    private let gold = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)

    func cancelAll() {
        generation &+= 1
        subscriptions.values.forEach { $0.cancel() }
        subscriptions.removeAll()
        roots.values.forEach { $0.removeFromParent() }
        roots.removeAll()
    }

    func playTechnique(attacker: Entity, defender: Entity, arena: AnchorEntity,
                       scene: Scene, controller: AnimationPlaybackController,
                       clipDuration: TimeInterval, reactionDelay: TimeInterval,
                       hitsDefender: Bool, cameraRotation: simd_quatf?,
                       isValid: @escaping () -> Bool) {
        play(.punch, attacker: attacker, defender: defender, arena: arena, scene: scene,
             controller: controller, clipDuration: clipDuration, reactionDelay: reactionDelay,
             hitsDefender: hitsDefender, cameraRotation: cameraRotation, isValid: isValid)
    }

    func playImpact(attacker: Entity, defender: Entity, arena: AnchorEntity,
                    scene: Scene, controller: AnimationPlaybackController,
                    clipDuration: TimeInterval, reactionDelay: TimeInterval,
                    hitsDefender: Bool, cameraRotation: simd_quatf?,
                    isValid: @escaping () -> Bool) {
        play(.kick, attacker: attacker, defender: defender, arena: arena, scene: scene,
             controller: controller, clipDuration: clipDuration, reactionDelay: reactionDelay,
             hitsDefender: hitsDefender, cameraRotation: cameraRotation, isValid: isValid)
    }

    private func play(_ move: MrsIncredibleVFXTiming.Move,
                      attacker: Entity, defender: Entity, arena: AnchorEntity,
                      scene: Scene, controller: AnimationPlaybackController,
                      clipDuration: TimeInterval, reactionDelay: TimeInterval,
                      hitsDefender: Bool, cameraRotation: simd_quatf?,
                      isValid: @escaping () -> Bool) {
        guard clipDuration.isFinite, clipDuration > 0.15, isValid() else { return }
        let timing = MrsIncredibleVFXTiming(clipDuration: clipDuration, move: move)
        let id = UUID()
        let token = generation
        let sampler = MrsIncrediblePoseSampler(character: attacker)
        let root = Entity()
        root.name = move == .punch ? "MrsPunchVFX" : "MrsKickVFX"
        arena.addChild(root)
        roots[id] = root
        let leftJoint: MrsIncredibleJointRig.Joint = move == .punch ? .leftHand : .leftFoot
        let rightJoint: MrsIncredibleJointRig.Joint = move == .punch ? .rightHand : .rightFoot
        let cameraOrientation = cameraRotation.map {
            simd_inverse(arena.orientation(relativeTo: nil)) * $0
        } ?? simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        let started = CACurrentMediaTime()
        var lastSampleTime: TimeInterval = -1
        var previousLeft: SIMD3<Float>?
        var previousRight: SIMD3<Float>?
        var count = 0
        var leftCount = 0
        var rightCount = 0
        var didContact = false
        #if DEBUG
        print("[DeckSpawn][MrsVFX] \(move) duration=\(clipDuration) rig=\(sampler != nil)")
        #endif
        let sub = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena, weak root] _ in
            guard let self else { return }
            guard self.generation == token, isValid(), let attacker, let defender,
                  let arena, let root, root.parent != nil else {
                self.finish(id)
                return
            }
            let elapsed = CACurrentMediaTime() - started
            let t = max(elapsed, controller.isValid ? max(0, controller.time) : 0)
            if t < timing.endAt, t - lastSampleTime >= timing.sampleInterval,
               count < timing.maxTrails {
                let left = sampler?.point(leftJoint, in: arena, character: attacker)
                let right = sampler?.point(rightJoint, in: arena, character: attacker)
                // Do not bridge a stalled frame or a missing tracking sample.
                if timing.isActive(at: t), t - lastSampleTime < 0.16,
                   let segment = timing.strongestSegment(leftBefore: previousLeft, leftNow: left,
                                                         rightBefore: previousRight, rightNow: right) {
                    self.spawnTrail(segment, timing: timing, parent: root)
                    count += 1
                    if segment.side == .left { leftCount += 1 } else { rightCount += 1 }
                }
                previousLeft = left
                previousRight = right
                lastSampleTime = t
            }
            if hitsDefender, !didContact, t >= reactionDelay {
                didContact = true
                self.spawnContact(defender: defender, arena: arena, orientation: cameraOrientation,
                                  strong: move == .kick, parent: root)
            }
            if t >= max(clipDuration + timing.trailLifetime + 0.07,
                        hitsDefender ? reactionDelay + 0.33 : 0) {
                #if DEBUG
                print("[DeckSpawn][MrsVFX] \(move) concluído: trails=\(count) left=\(leftCount) right=\(rightCount)")
                #endif
                self.finish(id)
            }
        }
        subscriptions[id] = sub
        DispatchQueue.main.asyncAfter(deadline: .now() + max(clipDuration, reactionDelay) + 0.85) { [weak self] in
            guard let self, self.generation == token else { return }
            self.finish(id)
        }
    }

    private func line(from start: SIMD3<Float>, to end: SIMD3<Float>, width: Float,
                      color: UIColor, lifetime: TimeInterval, parent: Entity) {
        let delta = end - start
        let length = simd_length(delta)
        guard length.isFinite, length > 0.002 else { return }
        let entity = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(width, width, 1)),
                                 materials: [UnlitMaterial(color: color)])
        entity.position = (start + end) * 0.5
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: delta / length)
        entity.scale = SIMD3<Float>(1, 1, length)
        parent.addChild(entity)
        var faded = entity.transform
        faded.scale.x = 0.07
        faded.scale.y = 0.07
        entity.move(to: faded, relativeTo: parent, duration: lifetime, timingFunction: .easeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime + 0.03) { [weak entity] in
            entity?.removeFromParent()
        }
    }

    private func spawnTrail(_ segment: MrsIncredibleVFXTiming.Segment,
                            timing: MrsIncredibleVFXTiming, parent: Entity) {
        let direction = simd_normalize(segment.end - segment.start)
        let cross = simd_cross(direction, SIMD3<Float>(0, 1, 0))
        let sideways = simd_length_squared(cross) > 0.00001
            ? simd_normalize(cross) : SIMD3<Float>(1, 0, 0)
        let strong = timing.move == .kick
        let start = segment.start - direction * (strong ? 0.025 : 0.012)
        let end = segment.end
        line(from: start, to: end, width: strong ? 0.025 : 0.016, color: red,
             lifetime: timing.trailLifetime, parent: parent)
        let offset = sideways * (strong ? 0.019 : 0.012)
        line(from: start + offset, to: end + offset, width: strong ? 0.010 : 0.007,
             color: orange, lifetime: timing.trailLifetime, parent: parent)
        if strong {
            let edge = -sideways * 0.017
            line(from: start + edge, to: end + edge, width: 0.0045, color: gold,
                 lifetime: timing.trailLifetime, parent: parent)
        }
    }

    private func spawnContact(defender: Entity, arena: AnchorEntity, orientation: simd_quatf,
                              strong: Bool, parent: Entity) {
        let bounds = defender.visualBounds(recursive: true, relativeTo: defender)
        let contact = Entity()
        contact.position = defender.convert(position: SIMD3<Float>(bounds.center.x,
            bounds.min.y + bounds.extents.y * 0.55, bounds.center.z), to: arena)
        contact.orientation = orientation
        parent.addChild(contact)
        let size: Float = strong ? 1.2 : 0.85
        // Two short diagonal hit marks, no radial/circular effects.
        line(from: SIMD3<Float>(-0.075, -0.045, 0) * size,
             to: SIMD3<Float>(0.065, 0.065, 0) * size,
             width: 0.014, color: orange, lifetime: 0.24, parent: contact)
        line(from: SIMD3<Float>(-0.035, -0.075, 0) * size,
             to: SIMD3<Float>(0.08, 0.015, 0) * size,
             width: 0.007, color: gold, lifetime: 0.24, parent: contact)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak contact] in
            contact?.removeFromParent()
        }
    }

    private func finish(_ id: UUID) {
        subscriptions.removeValue(forKey: id)?.cancel()
        roots.removeValue(forKey: id)?.removeFromParent()
    }
}
