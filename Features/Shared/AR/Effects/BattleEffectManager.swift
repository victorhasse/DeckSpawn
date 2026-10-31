import RealityKit
import UIKit
import simd
import QuartzCore
import Combine // SceneEvents.Update subscription is a Combine Cancellable.

/// Temporary 3D VFX. Called only for Goku's Impact in singleplayer.
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
