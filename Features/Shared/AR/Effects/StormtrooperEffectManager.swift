import Foundation
import RealityKit
import UIKit
import simd
import QuartzCore
import Combine

/// Stage-local shadow / graphite VFX for Stormtrooper's unarmed moves.
/// Technique = animated punches. Impact = spinning flying kick.
/// Visual-only: BattleEngine and reaction timing are never modified here.
final class StormtrooperEffectManager {
    private var generation = 0
    private var subscriptions: [UUID: any Cancellable] = [:]
    private var roots: [UUID: Entity] = [:]

    // Dark silhouettes + narrow steel edges. A completely black unlit shape
    // disappears against DeckSpawn's dark stage, especially in a dim AR room.
    private let shadow = UIColor(red: 0.025, green: 0.028, blue: 0.05, alpha: 1)
    private let graphite = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1)
    private let steel = UIColor(red: 0.58, green: 0.66, blue: 0.77, alpha: 1)

    func cancelAll() {
        generation &+= 1
        subscriptions.values.forEach { $0.cancel() }
        subscriptions.removeAll()
        roots.values.forEach { $0.removeFromParent() }
        roots.removeAll()
    }

    func playTechnique(
        attacker: Entity, defender: Entity, arena: AnchorEntity,
        scene: Scene, controller: AnimationPlaybackController,
        clipDuration: TimeInterval, reactionDelay: TimeInterval,
        hitsDefender: Bool, cameraRotation: simd_quatf?,
        isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let id = UUID()
        let token = generation
        let timing = StormtrooperVFXTiming(clipDuration: clipDuration)
        let sampler = StormtrooperPoseSampler(character: attacker)
        let root = Entity()
        root.name = "StormtrooperPunchVFX"
        arena.addChild(root)
        roots[id] = root

        // Calculate only once. The live joints override these positions.
        let fallbackLeft = fallbackHand(attacker: attacker, arena: arena, left: true)
        let fallbackRight = fallbackHand(attacker: attacker, arena: arena, left: false)
        let orientation = localCameraOrientation(cameraRotation, arena: arena)

        #if DEBUG
        print("[DeckSpawn][TrooperVFX] Técnica iniciada: duration=\(String(format: "%.2f", clipDuration))s, rig=\(sampler != nil)")
        #endif

        let started = CACurrentMediaTime()
        var baselineLeft: SIMD3<Float>?
        var baselineRight: SIMD3<Float>?
        var selected: StormtrooperJointRig.Joint = .rightHand
        var nextAccent = 0
        var lastTrail: SIMD3<Float>?
        var lastTrailTime: TimeInterval = 0
        var trailCount = 0
        var didContact = false

        let subscription = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena, weak root] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena,
                  let root, root.parent != nil else {
                self.finish(id)
                return
            }
            let elapsed = CACurrentMediaTime() - started
            let t = max(elapsed, controller.isValid ? max(0, controller.time) : 0)
            let left = sampler?.point(.leftHand, in: arena, character: attacker)
            let right = sampler?.point(.rightHand, in: arena, character: attacker)
            if baselineLeft == nil { baselineLeft = left }
            if baselineRight == nil { baselineRight = right }

            // Each punch chooses the arm which actually moved during its window.
            // When no rig is available, alternate left/right as a safe fallback.
            while nextAccent < timing.punchAccentTimes.count,
                  t >= timing.punchAccentTimes[nextAccent] {
                selected = StormtrooperJointRig.activeJoint(
                    leftStart: baselineLeft, rightStart: baselineRight,
                    leftCurrent: left, rightCurrent: right,
                    left: .leftHand, right: .rightHand,
                    default: selected == .leftHand ? .rightHand : .leftHand
                )
                // The joint-following trails already highlight each punch.
                // Avoid a decorative circular slash that does not follow the fist.
                #if DEBUG
                print("[DeckSpawn][TrooperVFX] Soco \(nextAccent + 1): \(selected == .leftHand ? "esquerda" : "direita"), tracked=\((selected == .leftHand ? left : right) != nil)")
                #endif
                baselineLeft = left
                baselineRight = right
                nextAccent += 1
                lastTrail = nil
            }

            if timing.shouldShowPunchTrail(at: t), trailCount < 18 {
                let wrist = selected == .leftHand
                    ? (left ?? fallbackLeft) : (right ?? fallbackRight)
                if let previous = lastTrail,
                   t - lastTrailTime > 0.053,
                   simd_length_squared(wrist - previous) > 0.000036 {
                    self.spawnShadowTrail(from: previous, to: wrist, parent: root)
                    trailCount += 1
                    lastTrail = wrist
                    lastTrailTime = t
                } else if lastTrail == nil || t - lastTrailTime > 0.053 {
                    lastTrail = wrist
                    lastTrailTime = t
                }
            }

            if hitsDefender, !didContact, t >= reactionDelay {
                didContact = true
                self.spawnShadowContact(at: self.targetPoint(defender, arena: arena),
                                        orientation: orientation, parent: root)
            }
            let keepUntil = max(clipDuration + 0.33,
                                hitsDefender ? reactionDelay + 0.31 : 0)
            if t >= keepUntil { self.finish(id) }
        }
        subscriptions[id] = subscription
        cleanup(id, token: token, after: max(clipDuration, reactionDelay) + 0.80)
    }

    func playImpact(
        attacker: Entity, defender: Entity, arena: AnchorEntity,
        scene: Scene, controller: AnimationPlaybackController,
        clipDuration: TimeInterval, reactionDelay: TimeInterval,
        hitsDefender: Bool, cameraRotation: simd_quatf?,
        isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let id = UUID()
        let token = generation
        let timing = StormtrooperVFXTiming(clipDuration: clipDuration)
        let sampler = StormtrooperPoseSampler(character: attacker)
        let root = Entity()
        root.name = "StormtrooperSpinningKickVFX"
        arena.addChild(root)
        roots[id] = root

        let fallbackLeft = fallbackFoot(attacker: attacker, arena: arena, left: true)
        let fallbackRight = fallbackFoot(attacker: attacker, arena: arena, left: false)
        let orientation = localCameraOrientation(cameraRotation, arena: arena)
        #if DEBUG
        print("[DeckSpawn][TrooperVFX] Impacto iniciado: duration=\(String(format: "%.2f", clipDuration))s, rig=\(sampler != nil)")
        #endif

        let started = CACurrentMediaTime()
        var baselineLeft: SIMD3<Float>?
        var baselineRight: SIMD3<Float>?
        var activeFoot: StormtrooperJointRig.Joint = .rightFoot
        var didSelect = false
        var didContact = false
        var lastTrail: SIMD3<Float>?
        var lastTrailTime: TimeInterval = 0
        var trailCount = 0

        let subscription = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena, weak root] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena,
                  let root, root.parent != nil else {
                self.finish(id)
                return
            }
            let elapsed = CACurrentMediaTime() - started
            let t = max(elapsed, controller.isValid ? max(0, controller.time) : 0)
            let left = sampler?.point(.leftFoot, in: arena, character: attacker)
            let right = sampler?.point(.rightFoot, in: arena, character: attacker)
            if baselineLeft == nil { baselineLeft = left }
            if baselineRight == nil { baselineRight = right }

            if t >= timing.kickStartAt && !didSelect {
                didSelect = true
                activeFoot = StormtrooperJointRig.activeJoint(
                    leftStart: baselineLeft, rightStart: baselineRight,
                    leftCurrent: left, rightCurrent: right,
                    left: .leftFoot, right: .rightFoot, default: .rightFoot
                )
                #if DEBUG
                print("[DeckSpawn][TrooperVFX] Chute: pé \(activeFoot == .leftFoot ? "esquerdo" : "direito"), tracked=\((activeFoot == .leftFoot ? left : right) != nil)")
                #endif
            }
            let foot = activeFoot == .leftFoot
                ? (left ?? fallbackLeft) : (right ?? fallbackRight)

            if timing.shouldShowKickTrail(at: t), trailCount < 22 {
                if let previous = lastTrail,
                   t - lastTrailTime > 0.052,
                   simd_length_squared(foot - previous) > 0.000042 {
                    self.spawnShadowTrail(from: previous, to: foot, parent: root)
                    trailCount += 1
                    lastTrail = foot
                    lastTrailTime = t
                } else if lastTrail == nil || t - lastTrailTime > 0.052 {
                    lastTrail = foot
                    lastTrailTime = t
                }
            }

            // Only motion-tracked streaks: no orbiting or circular kick effects.

            if hitsDefender, !didContact, t >= reactionDelay {
                didContact = true
                self.spawnShadowContact(at: self.targetPoint(defender, arena: arena),
                                        orientation: orientation, parent: root)
            }
            let keepUntil = max(timing.kickEndAt + 0.42,
                                hitsDefender ? reactionDelay + 0.31 : 0)
            if t >= keepUntil {
                #if DEBUG
                print("[DeckSpawn][TrooperVFX] Impacto concluído: trails=\(trailCount), circularFX=false")
                #endif
                self.finish(id)
            }
        }
        subscriptions[id] = subscription
        cleanup(id, token: token, after: max(clipDuration, reactionDelay) + 0.90)
    }

    private func fallbackHand(attacker: Entity, arena: AnchorEntity,
                              left: Bool) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        return attacker.convert(position: SIMD3<Float>(
            bounds.center.x + (left ? -0.11 : 0.11),
            bounds.min.y + bounds.extents.y * 0.70,
            bounds.center.z
        ), to: arena)
    }

    private func fallbackFoot(attacker: Entity, arena: AnchorEntity,
                              left: Bool) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        return attacker.convert(position: SIMD3<Float>(
            bounds.center.x + (left ? -0.075 : 0.075),
            bounds.min.y + bounds.extents.y * 0.16,
            bounds.center.z
        ), to: arena)
    }

    private func targetPoint(_ defender: Entity, arena: AnchorEntity) -> SIMD3<Float> {
        let bounds = defender.visualBounds(recursive: true, relativeTo: defender)
        return defender.convert(position: SIMD3<Float>(
            bounds.center.x,
            bounds.min.y + bounds.extents.y * 0.55,
            bounds.center.z
        ), to: arena)
    }

    private func makeLine(width: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: SIMD3<Float>(width, width, 1)),
                    materials: [UnlitMaterial(color: color)])
    }

    private func positionLine(_ line: ModelEntity,
                              from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.002, length.isFinite else {
            line.isEnabled = false
            return
        }
        line.isEnabled = true
        line.position = (start + end) * 0.5
        line.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: delta / length)
        line.scale = SIMD3<Float>(1, 1, length)
    }

    private func spawnShadowTrail(from start: SIMD3<Float>, to end: SIMD3<Float>,
                                  parent: Entity) {
        let movement = end - start
        guard simd_length_squared(movement) > 0.00001 else { return }
        let direction = simd_normalize(movement)
        let axis = simd_cross(direction, SIMD3<Float>(0, 1, 0))
        let sideways = simd_length_squared(axis) > 0.00001
            ? simd_normalize(axis) : SIMD3<Float>(1, 0, 0)
        // Black central slash, graphite body, thin pale silhouette.
        for (i, color) in [shadow, graphite, steel].enumerated() {
            let widths: [Float] = [0.019, 0.011, 0.0038]
            let offsets: [Float] = [0, -0.009, 0.014]
            let line = makeLine(width: widths[i], color: color)
            let shift = sideways * offsets[i]
            positionLine(line, from: start - direction * 0.032 + shift,
                         to: end + direction * 0.032 + shift)
            parent.addChild(line)
            var endTransform = line.transform
            endTransform.scale.x = 0.08
            endTransform.scale.y = 0.08
            line.move(to: endTransform, relativeTo: parent,
                      duration: 0.28, timingFunction: .easeOut)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) { [weak line] in
                line?.removeFromParent()
            }
        }
    }

    /// Small, straight contact marks. Unlike the original radial burst,
    /// these are short diagonal strokes rather than circles around the target.
    private func spawnShadowContact(at point: SIMD3<Float>,
                                    orientation: simd_quatf, parent: Entity) {
        let root = Entity()
        root.name = "TrooperShadowContactStreaks"
        root.position = point
        root.orientation = orientation
        parent.addChild(root)

        let strokes: [(SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3<Float>(-0.080, -0.052, 0), SIMD3<Float>(0.072, 0.067, 0)),
            (SIMD3<Float>(-0.041, -0.082, 0), SIMD3<Float>(0.094, 0.018, 0))
        ]
        for (start, end) in strokes {
            let darkLine = makeLine(width: 0.015, color: shadow)
            positionLine(darkLine, from: start, to: end)
            root.addChild(darkLine)

            let rimOffset = SIMD3<Float>(0.007, -0.007, 0)
            let steelLine = makeLine(width: 0.0038, color: steel)
            positionLine(steelLine, from: start + rimOffset, to: end + rimOffset)
            root.addChild(steelLine)

            for line in [darkLine, steelLine] {
                var faded = line.transform
                faded.scale.x *= 0.06
                faded.scale.y *= 0.06
                line.move(to: faded, relativeTo: root,
                          duration: 0.24, timingFunction: .easeOut)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) { [weak root] in
            root?.removeFromParent()
        }
    }

    private func localCameraOrientation(_ cameraRotation: simd_quatf?,
                                        arena: AnchorEntity) -> simd_quatf {
        guard let cameraRotation else {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        }
        return simd_inverse(arena.orientation(relativeTo: nil)) * cameraRotation
    }

    private func finish(_ id: UUID) {
        subscriptions.removeValue(forKey: id)?.cancel()
        roots.removeValue(forKey: id)?.removeFromParent()
    }

    private func cleanup(_ id: UUID, token: Int, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == token else { return }
            self.finish(id)
        }
    }
}
