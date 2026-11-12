import Foundation
import RealityKit
import UIKit
import simd
import QuartzCore
import Combine

/// Lightweight, singleplayer-only Spider-Man effects, separate from Goku VFX.
/// Web: a strand attached to the animated wrist, then pulled back.
/// Capoeira: short animated-foot trails and a brief kick arc.
/// Visual only: BattleEngine remains the source of truth for damage/results.
final class SpiderManEffectManager {
    private var generation = 0
    private var subscriptions: [UUID: any Cancellable] = [:]
    private var roots: [UUID: Entity] = [:]

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
        hitsDefender: Bool, isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let token = generation
        let id = UUID()
        let timing = SpiderManVFXTiming(clipDuration: clipDuration)
        let sampler = SpiderManPoseSampler(character: attacker)
        let root = Entity()
        root.name = "SpiderManWebVFX"
        arena.addChild(root)
        roots[id] = root

        let webColors = [
            UIColor(red: 0.94, green: 0.99, blue: 1, alpha: 1),
            UIColor(red: 0.50, green: 0.86, blue: 1, alpha: 1),
            UIColor(red: 0.83, green: 0.94, blue: 1, alpha: 1)
        ]
        let strands = webColors.enumerated().map { index, color -> ModelEntity in
            let width: Float = index == 0 ? 0.0031 : 0.00125
            let model = makeLine(width: width, color: color)
            model.name = "webStrand\(index)"
            model.isEnabled = false
            root.addChild(model)
            return model
        }

        let started = CACurrentMediaTime()
        var baselineLeft: SIMD3<Float>?
        var baselineRight: SIMD3<Float>?
        var castHand: SpiderManJointRig.Joint = .leftHand
        var didChooseHand = false
        var didConnect = false
        var didFinishWeb = false
        var didFinishContact = false
        let subscription = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena, weak root] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena, let root, root.parent != nil else {
                self.finish(id)
                return
            }
            let elapsed = CACurrentMediaTime() - started
            let t = max(elapsed, controller.isValid ? max(0, controller.time) : 0)
            let left = sampler?.point(.leftHand, in: arena, character: attacker)
            let right = sampler?.point(.rightHand, in: arena, character: attacker)
            if baselineLeft == nil { baselineLeft = left }
            if baselineRight == nil { baselineRight = right }

            if t >= timing.webLaunchAt && !didChooseHand {
                didChooseHand = true
                // In this particular USDZ the preparatory/counterbalancing arm
                // moves farther *before* the throwing wrist extends. The 5.3S.1
                // selection followed that arm and was visibly wrong on iPhone.
                // Invert the original movement-based choice for THIS animation.
                // If only one joint exists, never switch to a missing joint.
                if let left, let right, let baselineLeft, let baselineRight {
                    let leftTravel = simd_length_squared(left - baselineLeft)
                    let rightTravel = simd_length_squared(right - baselineRight)
                    let preparationHand: SpiderManJointRig.Joint = leftTravel > rightTravel
                        ? .leftHand : .rightHand
                    castHand = SpiderManJointRig.webThrowingHand(oppositeOf: preparationHand)
                } else if left != nil {
                    castHand = .leftHand
                } else if right != nil {
                    castHand = .rightHand
                }
                #if DEBUG
                print("[DeckSpawn][SpiderVFX] Técnica: mão corrigida = \(castHand == .leftHand ? "esquerda" : "direita"); leftTracked=\(left != nil) rightTracked=\(right != nil)")
                #endif
            }

            if t >= timing.webLaunchAt && t < timing.webEndAt {
                let hand = castHand == .leftHand ? left : right
                let source = hand ?? self.fallbackHand(attacker: attacker, defender: defender, arena: arena,
                                                        left: castHand == .leftHand)
                let target = self.targetPoint(defender, arena: arena)
                let extensionFraction = timing.webExtension(at: t)
                let endpoint = source + (target - source) * extensionFraction
                let delta = target - source
                let perpCandidate = simd_cross(delta, SIMD3<Float>(0, 1, 0))
                let rightVector = simd_length_squared(perpCandidate) > 0.000001
                    ? simd_normalize(perpCandidate)
                    : SIMD3<Float>(1, 0, 0)
                for (index, strand) in strands.enumerated() {
                    let sideways = Float(index - 1) * 0.0035
                    let shift = rightVector * sideways
                    self.positionLine(strand, from: source + shift, to: endpoint + shift)
                }
            } else {
                strands.forEach { $0.isEnabled = false }
                if t >= timing.webEndAt { didFinishWeb = true }
            }

            if !didConnect && t >= timing.webConnectAt {
                didConnect = true
                if hitsDefender {
                    self.spawnWebMark(
                        at: self.targetPoint(defender, arena: arena),
                        toward: attacker.position(relativeTo: arena),
                        parent: root
                    )
                }
            }
            // Winning attacks can have their hit reaction after the clip ends.
            if !didFinishContact && t >= reactionDelay { didFinishContact = true }
            if didFinishWeb && (!hitsDefender || didFinishContact) {
                self.finish(id)
            }
        }
        subscriptions[id] = subscription
        cleanup(id, token: token, after: max(clipDuration, reactionDelay) + 0.70)
    }

    func playImpact(
        attacker: Entity, defender: Entity, arena: AnchorEntity,
        scene: Scene, controller: AnimationPlaybackController,
        clipDuration: TimeInterval, reactionDelay: TimeInterval,
        hitsDefender: Bool, cameraRotation: simd_quatf?,
        isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let token = generation
        let id = UUID()
        let timing = SpiderManVFXTiming(clipDuration: clipDuration)
        let sampler = SpiderManPoseSampler(character: attacker)
        let root = Entity()
        root.name = "SpiderManCapoeiraVFX"
        arena.addChild(root)
        roots[id] = root

        #if DEBUG
        print("[DeckSpawn][SpiderVFX] Impacto iniciado: clip=\(String(format: "%.2f", clipDuration))s, rig=\(sampler != nil)")
        #endif

        // Precompute stage-space fallbacks once; visualBounds per AR frame would
        // cause an avoidable performance regression when a rig is unavailable.
        let fallbackLeftFoot = fallbackFoot(attacker: attacker, arena: arena, left: true)
        let fallbackRightFoot = fallbackFoot(attacker: attacker, arena: arena, left: false)
        let started = CACurrentMediaTime()
        var baselineLeft: SIMD3<Float>?
        var baselineRight: SIMD3<Float>?
        var activeFoot: SpiderManJointRig.Joint = .rightFoot
        var didChooseFoot = false
        var firstArc: Entity?
        var didSecondArc = false
        var didContact = false
        var lastTrailPosition: SIMD3<Float>?
        var lastTrailTime: TimeInterval = 0
        var trailCount = 0
        var didLogFinish = false

        let subscription = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena, weak root] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena, let root, root.parent != nil else {
                self.finish(id)
                return
            }
            let elapsed = CACurrentMediaTime() - started
            let t = max(elapsed, controller.isValid ? max(0, controller.time) : 0)
            let left = sampler?.point(.leftFoot, in: arena, character: attacker)
            let right = sampler?.point(.rightFoot, in: arena, character: attacker)
            if baselineLeft == nil { baselineLeft = left }
            if baselineRight == nil { baselineRight = right }

            if t >= timing.kickArcAt && !didChooseFoot {
                didChooseFoot = true
                if let left, let right, let baselineLeft, let baselineRight {
                    activeFoot = simd_length_squared(left - baselineLeft) > simd_length_squared(right - baselineRight)
                        ? .leftFoot : .rightFoot
                } else if left != nil {
                    activeFoot = .leftFoot
                }
                #if DEBUG
                print("[DeckSpawn][SpiderVFX] Impacto: seguindo \(activeFoot == .leftFoot ? "pé esquerdo" : "pé direito"); leftTracked=\(left != nil) rightTracked=\(right != nil)")
                #endif
            }

            // Always draw the kick accent, even when the skeleton has no usable
            // foot joint. The fallback stays within the attacker's lower body.
            let foot = (activeFoot == .leftFoot ? left : right)
                ?? (activeFoot == .leftFoot ? fallbackLeftFoot : fallbackRightFoot)

            if t >= timing.kickStartAt && t < timing.kickEndAt {
                if let previous = lastTrailPosition {
                    if t - lastTrailTime > 0.052 {
                        if simd_length_squared(foot - previous) > 0.000036 && trailCount < 24 {
                            trailCount += 1
                            self.spawnFootTrail(from: previous, to: foot, parent: root)
                        }
                        lastTrailPosition = foot
                        lastTrailTime = t
                    }
                } else {
                    lastTrailPosition = foot
                    lastTrailTime = t
                }
            }

            // Unlike 5.3S.1's 0.23-second static arc, the main luminous swoosh
            // follows the actual kicking foot while the animation is playing.
            if t >= timing.kickArcAt && firstArc == nil {
                firstArc = self.spawnKickArc(
                    at: foot, cameraRotation: cameraRotation,
                    arena: arena, parent: root, secondary: false
                )
                #if DEBUG
                print("[DeckSpawn][SpiderVFX] Impacto: arco principal ativado")
                #endif
            }
            if t >= timing.kickSecondArcAt && !didSecondArc {
                didSecondArc = true
                self.spawnKickArc(
                    at: foot, cameraRotation: cameraRotation,
                    arena: arena, parent: root, secondary: true
                )
            }
            if t < timing.kickEndAt {
                firstArc?.position = foot
            }

            if !didContact && hitsDefender && t >= reactionDelay {
                didContact = true
                self.spawnContactBurst(at: self.targetPoint(defender, arena: arena),
                                       cameraRotation: cameraRotation, arena: arena,
                                       parent: root)
            }

            // Keep the visible afterimage after the original kick window;
            // removing the parent at 87% cut off the effect before players
            // could see it. Preserve the target-contact reaction if it hits.
            let keepUntil = max(timing.kickEndAt + 0.43,
                                hitsDefender ? reactionDelay + 0.33 : 0)
            if t >= keepUntil {
                if !didLogFinish {
                    didLogFinish = true
                    #if DEBUG
                    print("[DeckSpawn][SpiderVFX] Impacto concluído: trails=\(trailCount), arc=\(firstArc != nil), secondArc=\(didSecondArc), contact=\(didContact)")
                    #endif
                }
                self.finish(id)
            }
        }
        subscriptions[id] = subscription
        cleanup(id, token: token, after: max(clipDuration, reactionDelay) + 0.90)
    }

    private func fallbackHand(attacker: Entity, defender: Entity, arena: AnchorEntity,
                              left: Bool) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        let local = SIMD3<Float>(bounds.center.x + (left ? -0.09 : 0.09),
                                 bounds.min.y + bounds.extents.y * 0.69, bounds.center.z)
        let point = attacker.convert(position: local, to: arena)
        let toward = defender.position(relativeTo: arena) - point
        let horizontal = SIMD3<Float>(toward.x, 0, toward.z)
        return point + (simd_length_squared(horizontal) > 0.00001
                        ? simd_normalize(horizontal) * 0.035 : .zero)
    }

    private func fallbackFoot(attacker: Entity, arena: AnchorEntity,
                              left: Bool) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        return attacker.convert(position: SIMD3<Float>(
            bounds.center.x + (left ? -0.075 : 0.075),
            bounds.min.y + bounds.extents.y * 0.14,
            bounds.center.z
        ), to: arena)
    }

    private func targetPoint(_ character: Entity, arena: AnchorEntity) -> SIMD3<Float> {
        let bounds = character.visualBounds(recursive: true, relativeTo: character)
        return character.convert(position: SIMD3<Float>(
            bounds.center.x, bounds.min.y + bounds.extents.y * 0.52, bounds.center.z
        ), to: arena)
    }

    private func makeLine(width: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: SIMD3<Float>(width, width, 1)),
                    materials: [UnlitMaterial(color: color)])
    }

    private func positionLine(_ line: ModelEntity,
                              from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let delta = end - start
        let distance = simd_length(delta)
        guard distance > 0.002, distance.isFinite else {
            line.isEnabled = false
            return
        }
        line.isEnabled = true
        line.position = (start + end) * 0.5
        line.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: delta / distance)
        line.scale = SIMD3<Float>(1, 1, distance)
    }

    private func spawnWebMark(at target: SIMD3<Float>, toward attacker: SIMD3<Float>,
                              parent: Entity) {
        let root = Entity()
        root.position = target
        let normal = attacker - target
        if simd_length_squared(normal) > 0.000001 {
            root.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(normal))
        }
        parent.addChild(root)
        let color = UIColor(red: 0.82, green: 0.97, blue: 1, alpha: 1)
        let spokes = 8
        let count = Float(spokes)
        for i in 0..<spokes {
            let a = Float(i) * 2 * Float.pi / count
            let b = Float(i + 1) * 2 * Float.pi / count
            let inner = SIMD3<Float>(cos(a) * 0.011, sin(a) * 0.011, 0)
            let outer = SIMD3<Float>(cos(a) * 0.045, sin(a) * 0.045, 0)
            let next = SIMD3<Float>(cos(b) * 0.045, sin(b) * 0.045, 0)
            let spoke = makeLine(width: 0.0015, color: color)
            positionLine(spoke, from: inner, to: outer)
            root.addChild(spoke)
            let rim = makeLine(width: 0.0011, color: color)
            positionLine(rim, from: outer, to: next)
            root.addChild(rim)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak root] in
            root?.removeFromParent()
        }
    }

    private func spawnFootTrail(from start: SIMD3<Float>, to end: SIMD3<Float>, parent: Entity) {
        let delta = end - start
        guard simd_length_squared(delta) > 0.00001 else { return }
        let up = SIMD3<Float>(0, 1, 0)
        let lateral = simd_cross(simd_normalize(delta), up)
        let side = simd_length_squared(lateral) > 0.00001
            ? simd_normalize(lateral) : SIMD3<Float>(1, 0, 0)
        // Stronger, wider dual-color streaks remain visible at normal AR distance.
        let widths: [Float] = [0.011, 0.0075]
        let colors = [UIColor(red: 0.67, green: 0.95, blue: 1, alpha: 1),
                      UIColor(red: 1, green: 0.20, blue: 0.25, alpha: 1)]
        for i in 0..<2 {
            let line = makeLine(width: widths[i], color: colors[i])
            let offset = side * Float(i == 0 ? -0.012 : 0.012)
            let push = simd_normalize(delta) * 0.030
            positionLine(line, from: start - push + offset, to: end + push + offset)
            parent.addChild(line)
            var target = line.transform
            target.scale.x = 0.10
            target.scale.y = 0.10
            line.move(to: target, relativeTo: parent,
                      duration: 0.30, timingFunction: .easeOut)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) { [weak line] in
                line?.removeFromParent()
            }
        }
    }

    /// A cyan/white slash with a red trailing edge, large enough to read on an
    /// iPhone. The slash starts around the animated foot (not the stage pivot).
    /// The outer root is updated every AR frame for the primary slash.
    @discardableResult
    private func spawnKickArc(at foot: SIMD3<Float>, cameraRotation: simd_quatf?,
                              arena: AnchorEntity, parent: Entity,
                              secondary: Bool) -> Entity {
        let arcRoot = Entity()
        arcRoot.name = secondary ? "SpiderKickAfterimage" : "SpiderKickSwoosh"
        arcRoot.position = foot
        arcRoot.orientation = localCameraOrientation(cameraRotation, arena: arena)
        parent.addChild(arcRoot)
        // Animate the child, not the tracked parent: RealityKit's move(to:)
        // otherwise fights the per-frame foot position update.
        let visual = Entity()
        arcRoot.addChild(visual)
        let arcColors: [UIColor] = [
            UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1),
            UIColor(red: 0.37, green: 0.83, blue: 1, alpha: 1),
            UIColor(red: 1, green: 0.16, blue: 0.22, alpha: 1)
        ]
        let segments = 12
        for layer in 0..<3 {
            let radius: Float = secondary
                ? (0.142 + Float(layer) * 0.016)
                : (0.162 + Float(layer) * 0.017)
            for i in 0..<segments {
                let angleA = Float(i) / Float(segments) * 3.85 - 1.95
                let angleB = Float(i + 1) / Float(segments) * 3.85 - 1.95
                let p0 = SIMD3<Float>(cos(angleA) * radius,
                                      sin(angleA) * radius, 0)
                let p1 = SIMD3<Float>(cos(angleB) * radius,
                                      sin(angleB) * radius, 0)
                let line = makeLine(
                    width: layer == 0 ? 0.0105 : (layer == 1 ? 0.014 : 0.008),
                    color: arcColors[layer]
                )
                positionLine(line, from: p0, to: p1)
                visual.addChild(line)
            }
        }
        var target = visual.transform
        target.scale = SIMD3<Float>(repeating: secondary ? 0.97 : 1.12)
        visual.move(to: target, relativeTo: arcRoot,
                     duration: secondary ? 0.28 : 0.40, timingFunction: .easeOut)
        // Do not drop the slash on the very same frame the kicking foot pauses.
        DispatchQueue.main.asyncAfter(deadline: .now() + (secondary ? 0.38 : 0.49)) {
            [weak arcRoot] in
            arcRoot?.removeFromParent()
        }
        return arcRoot
    }

    private func spawnContactBurst(at point: SIMD3<Float>,
                                   cameraRotation: simd_quatf?, arena: AnchorEntity,
                                   parent: Entity) {
        let root = Entity()
        root.position = point
        root.orientation = localCameraOrientation(cameraRotation, arena: arena)
        parent.addChild(root)
        for i in 0..<8 {
            let angle = Float(i) * (2 * Float.pi / 8)
            let p0 = SIMD3<Float>(cos(angle) * 0.018, sin(angle) * 0.018, 0)
            let p1 = SIMD3<Float>(cos(angle) * 0.095, sin(angle) * 0.095, 0)
            let color = i.isMultiple(of: 2)
                ? UIColor.white
                : UIColor(red: 0.47, green: 0.82, blue: 1, alpha: 1)
            let line = makeLine(width: 0.010, color: color)
            positionLine(line, from: p0, to: p1)
            root.addChild(line)
        }
        var end = root.transform
        end.scale = SIMD3<Float>(repeating: 1.22)
        root.move(to: end, relativeTo: parent, duration: 0.25, timingFunction: .easeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak root] in
            root?.removeFromParent()
        }
    }

    private func localCameraOrientation(_ cameraRotation: simd_quatf?,
                                        arena: AnchorEntity) -> simd_quatf {
        guard let cameraRotation else { return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) }
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
