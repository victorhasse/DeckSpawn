import RealityKit
import UIKit
import simd
import QuartzCore
import Combine // SceneEvents.Update subscription is a Combine Cancellable.

/// Temporary 3D VFX for Goku Impact and Technique in singleplayer.
/// Animation state is read from the actual RealityKit playback controller.
final class BattleEffectManager {
    private enum GokuTuning {
        static let sourceHeightFraction: Float = 0.72
        static let forwardDistance: Float = 0.10
        static let handForwardOffset: Float = 0.025
        static let targetHeightFraction: Float = 0.52
        static let sphereRadius: Float = 0.048
    }

    private var generation = 0
    private var liveEntities: [Entity] = []
    private var updateSubscription: (any Cancellable)?

    func cancelAll() {
        generation &+= 1
        updateSubscription?.cancel()
        updateSubscription = nil
        liveEntities.forEach { $0.removeFromParent() }
        liveEntities.removeAll()
    }

    func playGokuImpact(
        attacker: Entity,
        defender: Entity,
        arena: AnchorEntity,
        scene: Scene,
        controller: AnimationPlaybackController,
        clipDuration: TimeInterval,
        reactionDelay: TimeInterval,
        hitsDefender: Bool,
        isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let token = generation
        let visualImpactDelay = KamehamehaTiming.visualImpactDelay(
            clipDuration: clipDuration,
            combatReactionDelay: reactionDelay,
            hitsDefender: hitsDefender
        )
        let timing = KamehamehaTiming(
            clipDuration: clipDuration,
            reactionDelay: visualImpactDelay
        )
        let hands = GokuHandPoseSampler(character: attacker)
        #if DEBUG
        if hands == nil {
            print("[DeckSpawn][VFX] Goku: mãos não acessíveis; usando posição local de segurança")
        }
        #endif
        let orb = makeOrb()
        orb.scale = SIMD3<Float>(repeating: timing.orbScale(at: timing.chargeAt))
        orb.position = chargePoint(for: attacker, toward: defender, in: arena, hands: hands)
        arena.addChild(orb)
        liveEntities.append(orb)

        let started = CACurrentMediaTime()
        var launched = false
        var completed = false
        var launchPoint = orb.position
        var lastValidHands: SIMD3<Float>? = nil

        updateSubscription?.cancel()
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak attacker, weak defender, weak arena, weak orb] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena, let orb else {
                self.cancelAll()
                return
            }
            let wallTime = CACurrentMediaTime() - started
            // Prefer the actual current frame in the animation, rather than
            // a second unrelated timer. If the controller becomes invalid
            // on completion, use wall time as a recovery fallback.
            // The playback controller may stop reporting progress a frame before
            // the reaction begins; the monotonic wall clock prevents a stall.
            // Normal animation speed is 1.0 for these battle clips.
            let time = max(wallTime, controller.isValid ? max(0, controller.time) : 0)

            if time < timing.chargeAt {
                orb.position = self.chargePoint(for: attacker, toward: defender, in: arena, hands: hands)
                return
            }
            if time < timing.launchAt {
                if let position = hands?.midpoint(in: arena, attacker: attacker) {
                    lastValidHands = position
                }
                let handPoint = lastValidHands.map {
                    self.offsetTowardTarget($0, defender: defender, in: arena)
                }
                orb.position = handPoint ?? self.fallbackChargePoint(for: attacker, toward: defender, in: arena)
                let size = timing.orbScale(at: time)
                orb.scale = SIMD3<Float>(repeating: size)
                return
            }
            if !launched {
                launched = true
                launchPoint = lastValidHands.map {
                    self.offsetTowardTarget($0, defender: defender, in: arena)
                } ?? self.fallbackChargePoint(for: attacker, toward: defender, in: arena)
                orb.position = launchPoint
                orb.scale = SIMD3<Float>(repeating: 1)
                #if DEBUG
                print(String(format: "[DeckSpawn][VFX] Goku Impact disparo: %.2fs / clip %.2fs", time, clipDuration))
                #endif
            }
            if time < timing.impactAt {
                let target = self.targetPoint(for: defender, in: arena)
                let fraction = timing.flightProgress(at: time)
                orb.position = launchPoint + (target - launchPoint) * fraction
                return
            }
            guard !completed else { return }
            completed = true
            #if DEBUG
            print(String(format: "[DeckSpawn][VFX] Goku Impact contato: %.2fs", time))
            #endif
            orb.removeFromParent()
            self.forget(orb)
            self.updateSubscription?.cancel()
            self.updateSubscription = nil
            if hitsDefender {
                let flash = self.makeImpactFlash()
                flash.position = self.targetPoint(for: defender, in: arena)
                // Smaller, shorter contact flash: it should accent the Hit,
                // not cover the defending character or obscure the damage number.
                flash.scale = SIMD3<Float>(repeating: 0.25)
                arena.addChild(flash)
                self.liveEntities.append(flash)
                var transform = flash.transform
                transform.scale = SIMD3<Float>(repeating: 0.85)
                flash.move(to: transform, relativeTo: arena, duration: 0.10, timingFunction: .easeOut)
                self.schedule(at: 0.14, token: token, isValid: isValid) { [weak self, weak flash] in
                    flash?.removeFromParent()
                    if let flash { self?.forget(flash) }
                }
            }
        }
        // Safety cleanup when the AR scene stops sending frame events.
        schedule(at: timing.cleanupAt + 0.75, token: token, isValid: isValid) { [weak self] in
            self?.cancelAll()
        }
    }

    /// Anime-inspired, intentionally small punch VFX for Goku's Technique.
    /// The three punches are visual beats only: BattleEngine applies damage ONCE.
    /// Two light target accents appear at the first two beats on a winning move,
    /// and the final accent is tied to the real Hit/Death reaction time.
    func playGokuTechnique(
        attacker: Entity,
        defender: Entity,
        arena: AnchorEntity,
        scene: Scene,
        controller: AnimationPlaybackController,
        clipDuration: TimeInterval,
        reactionDelay: TimeInterval,
        hitsDefender: Bool,
        cameraRotation: simd_quatf?,
        isValid: @escaping () -> Bool
    ) {
        guard clipDuration > 0.15, isValid() else { return }
        let token = generation
        let timing = GokuTechniqueTiming(clipDuration: clipDuration)
        let hands = GokuHandPoseSampler(character: attacker)
        let started = CACurrentMediaTime()
        var nextBeat = 0
        var didFinalContact = false

        // One subscription per combat visual sequence, just as for Kamehameha.
        updateSubscription?.cancel()
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) {
            [weak self, weak attacker, weak defender, weak arena] _ in
            guard let self else { return }
            guard self.generation == token, isValid(),
                  let attacker, let defender, let arena else {
                self.cancelAll()
                return
            }
            let wallTime = CACurrentMediaTime() - started
            let time = max(wallTime, controller.isValid ? max(0, controller.time) : 0)

            // Consume skipped beats at most once; no allocations per frame.
            while nextBeat < GokuTechniqueTiming.beats.count {
                let beat = GokuTechniqueTiming.beats[nextBeat]
                guard time >= timing.moment(for: beat) else { break }
                let index = nextBeat
                nextBeat += 1
                let points = hands?.positions(in: arena, attacker: attacker)
                let source: SIMD3<Float>
                if let points {
                    source = beat.hand == .left ? points.left : points.right
                } else {
                    source = self.fallbackPunchPoint(
                        for: attacker, toward: defender, in: arena, hand: beat.hand
                    )
                }
                self.spawnAnimePunchSlash(
                    at: source, toward: defender, in: arena,
                    cameraRotation: cameraRotation,
                    strength: beat.strength,
                    token: token, isValid: isValid
                )
                // Only a winning Technique may show contact on the opponent.
                // The two small hits are VFX, not extra HP changes or Hit animations.
                if hitsDefender && index < GokuTechniqueTiming.beats.count - 1 {
                    self.spawnAnimeImpactBurst(
                        at: self.targetPoint(for: defender, in: arena),
                        in: arena, cameraRotation: cameraRotation,
                        strength: beat.strength * 0.72,
                        finalHit: false,
                        token: token, isValid: isValid
                    )
                }
                #if DEBUG
                print(String(format: "[DeckSpawn][VFX] Goku Tecnic anime soco %d: %.2fs / clip %.2fs",
                             index + 1, time, clipDuration))
                #endif
            }

            // Tie the strong finishing burst to the damage reaction, NOT to a
            // guessed beat fraction. The normal HP change/number occurs once.
            if hitsDefender && !didFinalContact && time >= reactionDelay {
                didFinalContact = true
                self.spawnAnimeImpactBurst(
                    at: self.targetPoint(for: defender, in: arena),
                    in: arena, cameraRotation: cameraRotation,
                    strength: GokuTechniqueTiming.finalImpactStrength,
                    finalHit: true,
                    token: token, isValid: isValid
                )
                #if DEBUG
                print(String(format: "[DeckSpawn][VFX] Goku Tecnic anime contato final: %.2fs", time))
                #endif
            }

            let finishedBeats = nextBeat == GokuTechniqueTiming.beats.count
            let finishedContact = !hitsDefender || didFinalContact
            if finishedBeats && finishedContact {
                self.updateSubscription?.cancel()
                self.updateSubscription = nil
            }
        }
        schedule(at: max(clipDuration, reactionDelay) + 0.70,
                 token: token, isValid: isValid) { [weak self] in
            self?.cancelAll()
        }
    }

    private func fallbackPunchPoint(
        for attacker: Entity, toward defender: Entity,
        in arena: AnchorEntity, hand: GokuTechniqueTiming.Hand
    ) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        let xOffset = max(0.03, bounds.extents.x * 0.22)
        let x: Float = hand == .left ? -xOffset : xOffset
        let center = attacker.convert(position: SIMD3<Float>(
            bounds.center.x + x,
            bounds.min.y + bounds.extents.y * 0.69,
            bounds.center.z
        ), to: arena)
        return offsetTowardTarget(center, defender: defender, in: arena)
    }

    /// Short, angular speed lines instead of the old elongated cyan spheres.
    /// Geometry is authored in meters and creates only three tiny boxes per hit.
    private func spawnAnimePunchSlash(
        at hand: SIMD3<Float>, toward defender: Entity, in arena: AnchorEntity,
        cameraRotation: simd_quatf?, strength: Float,
        token: Int, isValid: @escaping () -> Bool
    ) {
        let delta = targetPoint(for: defender, in: arena) - hand
        guard simd_length_squared(delta) > 0.000001 else { return }
        let forward = simd_normalize(delta)
        let rotation = localCameraOrientation(cameraRotation, in: arena)
        let right = simd_act(rotation, SIMD3<Float>(1, 0, 0))
        let up = simd_act(rotation, SIMD3<Float>(0, 1, 0))
        let colors: [UIColor] = [
            .white,
            UIColor(red: 0.63, green: 0.94, blue: 1.0, alpha: 1),
            UIColor(red: 0.20, green: 0.75, blue: 1.0, alpha: 1)
        ]
        for index in 0..<3 {
            let offset = Float(index) - 1
            let length: Float = (0.065 + Float(index) * 0.012) * strength
            let direction = simd_normalize(
                forward * 0.77 + right * (0.32 + offset * 0.12) + up * (0.16 - offset * 0.13)
            )
            let slash = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.0055, 0.004, length)),
                materials: [UnlitMaterial(color: colors[index])]
            )
            slash.position = hand + forward * 0.025 + right * (offset * 0.016)
                            + up * (Float(index % 2) * 0.012)
            slash.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
            arena.addChild(slash)
            liveEntities.append(slash)
            var end = slash.transform
            end.translation += forward * (0.038 * strength)
            end.scale = SIMD3<Float>(0.10, 0.10, 0.20)
            slash.move(to: end, relativeTo: arena,
                       duration: GokuTechniqueTiming.slashLifetime,
                       timingFunction: .easeOut)
            schedule(at: GokuTechniqueTiming.slashLifetime + 0.03,
                     token: token, isValid: isValid) { [weak self, weak slash] in
                slash?.removeFromParent()
                if let slash { self?.forget(slash) }
            }
        }
    }

    /// Camera-facing anime starburst, built from a small white X and radial
    /// warm-yellow spikes. It is intentionally flat/lightweight, rather than
    /// another opaque sphere over the opponent.
    private func spawnAnimeImpactBurst(
        at target: SIMD3<Float>, in arena: AnchorEntity,
        cameraRotation: simd_quatf?, strength: Float, finalHit: Bool,
        token: Int, isValid: @escaping () -> Bool
    ) {
        let root = Entity()
        root.position = target
        root.orientation = localCameraOrientation(cameraRotation, in: arena)
        root.scale = SIMD3<Float>(repeating: 0.7)
        let rays = finalHit ? 8 : 5
        let gold = UIColor(red: 1.0, green: 0.79, blue: 0.23, alpha: 1)
        let pale = UIColor(red: 1.0, green: 0.94, blue: 0.66, alpha: 1)
        let radius: Float = 0.032 * strength
        for index in 0..<rays {
            let angle = Float(index) * (2 * Float.pi / Float(rays))
            let radial = SIMD3<Float>(sin(angle), cos(angle), 0)
            let length: Float = (index % 2 == 0 ? 0.034 : 0.024) * strength
            let spike = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.006, length, 0.003)),
                materials: [UnlitMaterial(color: index % 2 == 0 ? gold : pale)]
            )
            spike.position = radial * (radius + length * 0.40)
            spike.orientation = simd_quatf(angle: -angle, axis: SIMD3<Float>(0, 0, 1))
            root.addChild(spike)
        }
        // Two angular central strokes convey a punch rather than an explosion ball.
        for angle in [-Float.pi / 4, Float.pi / 4] {
            let cross = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.008, 0.045 * strength, 0.004)),
                materials: [UnlitMaterial(color: .white)]
            )
            cross.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
            root.addChild(cross)
        }
        arena.addChild(root)
        liveEntities.append(root)
        var end = root.transform
        end.scale = SIMD3<Float>(repeating: finalHit ? 1.20 : 1.08)
        root.move(to: end, relativeTo: arena,
                  duration: finalHit ? GokuTechniqueTiming.finisherLifetime : GokuTechniqueTiming.contactLifetime,
                  timingFunction: .easeOut)
        let lifetime = finalHit ? GokuTechniqueTiming.finisherLifetime : GokuTechniqueTiming.contactLifetime
        schedule(at: lifetime + 0.02, token: token, isValid: isValid) { [weak self, weak root] in
            root?.removeFromParent()
            if let root { self?.forget(root) }
        }
    }

    private func localCameraOrientation(_ rotation: simd_quatf?, in arena: AnchorEntity) -> simd_quatf {
        guard let rotation else {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        }
        return simd_inverse(arena.orientation(relativeTo: nil)) * rotation
    }

    private func offsetTowardTarget(
        _ point: SIMD3<Float>, defender: Entity, in arena: AnchorEntity
    ) -> SIMD3<Float> {
        let toward = defender.position(relativeTo: arena) - point
        let flat = SIMD3<Float>(toward.x, 0, toward.z)
        guard simd_length_squared(flat) > 0.000001 else { return point }
        return point + simd_normalize(flat) * GokuTuning.handForwardOffset
    }

    private func chargePoint(
        for attacker: Entity, toward defender: Entity, in arena: AnchorEntity,
        hands: GokuHandPoseSampler?
    ) -> SIMD3<Float> {
        if let midpoint = hands?.midpoint(in: arena, attacker: attacker) {
            return offsetTowardTarget(midpoint, defender: defender, in: arena)
        }
        return fallbackChargePoint(for: attacker, toward: defender, in: arena)
    }

    private func fallbackChargePoint(
        for attacker: Entity, toward defender: Entity, in arena: AnchorEntity
    ) -> SIMD3<Float> {
        let bounds = attacker.visualBounds(recursive: true, relativeTo: attacker)
        let center = attacker.convert(
            position: SIMD3<Float>(
                bounds.center.x,
                bounds.min.y + bounds.extents.y * GokuTuning.sourceHeightFraction,
                bounds.center.z
            ),
            to: arena
        )
        let target = defender.position(relativeTo: arena) - attacker.position(relativeTo: arena)
        let flat = SIMD3<Float>(target.x, 0, target.z)
        guard simd_length_squared(flat) > 0.000001 else { return center }
        return center + simd_normalize(flat) * GokuTuning.forwardDistance
    }

    private func targetPoint(for target: Entity, in arena: AnchorEntity) -> SIMD3<Float> {
        let bounds = target.visualBounds(recursive: true, relativeTo: target)
        return target.convert(
            position: SIMD3<Float>(
                bounds.center.x,
                bounds.min.y + bounds.extents.y * GokuTuning.targetHeightFraction,
                bounds.center.z
            ),
            to: arena
        )
    }

    private func schedule(
        at delay: TimeInterval, token: Int,
        isValid: @escaping () -> Bool, action: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) { [weak self] in
            guard let self, self.generation == token, isValid() else { return }
            action()
        }
    }

    private func forget(_ entity: Entity) {
        liveEntities.removeAll { $0 === entity }
    }

    private func makeOrb() -> Entity {
        let group = Entity()
        let halo = ModelEntity(
            mesh: .generateSphere(radius: GokuTuning.sphereRadius * 1.55),
            materials: [SimpleMaterial(color: UIColor(red: 0.05, green: 0.46, blue: 1.0, alpha: 0.32), isMetallic: false)]
        )
        let center = ModelEntity(
            mesh: .generateSphere(radius: GokuTuning.sphereRadius),
            materials: [UnlitMaterial(color: .cyan)]
        )
        let core = ModelEntity(
            mesh: .generateSphere(radius: GokuTuning.sphereRadius * 0.42),
            materials: [UnlitMaterial(color: .white)]
        )
        group.addChild(halo)
        group.addChild(center)
        group.addChild(core)
        return group
    }

    private func makeImpactFlash() -> Entity {
        // A soft flash instead of a large opaque cyan ball.
        ModelEntity(
            mesh: .generateSphere(radius: 0.055),
            materials: [SimpleMaterial(
                color: UIColor(red: 0.15, green: 0.79, blue: 1.0, alpha: 0.55),
                isMetallic: false
            )]
        )
    }
}
