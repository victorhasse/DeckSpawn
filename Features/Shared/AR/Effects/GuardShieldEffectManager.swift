import RealityKit
import UIKit
import simd

/// Efeito de Guarda universal: cúpula translúcida e reações de absorção/ruptura.
/// Só é instanciado no singleplayer. Não altera o resultado da batalha.
final class GuardShieldEffectManager {
    private var generation = 0
    private var liveShields: [Entity] = []

    func cancelAll() {
        generation &+= 1
        liveShields.forEach { $0.removeFromParent() }
        liveShields.removeAll()
    }

    func playGuard(
        defender: Entity,
        attacker: Entity,
        arena: AnchorEntity,
        guardClipDuration: TimeInterval,
        opponentClipDuration: TimeInterval,
        blocksImpact: Bool,
        breaksGuard: Bool,
        isGoku: Bool = false,
        isValid: @escaping () -> Bool
    ) {
        guard isValid() else { return }
        let token = generation
        // O pivô do personagem fica na altura do palco. Ao contrário dos
        // visualBounds, ele não salta quando o esqueleto entra na animação
        // Guard. O Goku ainda tem um offset de -0.30 m DENTRO do USDZ:
        // usar bounds.min.y como base colocava o domo debaixo da arena.
        let pivot = defender.convert(position: .zero, to: arena)
        let visual = defender.visualBounds(recursive: true, relativeTo: arena)
        // Uma dimensão de referência estável, sem confiar em bounds animados
        // extremos. Todos os quatro personagens atuais têm 0.55–0.60 m.
        let referenceHeight: Float = isGoku ? 0.60 :
            min(0.62, max(0.52, visual.extents.y))
        let referenceWidth = min(0.42, max(0.16,
            max(visual.extents.x, visual.extents.z)))
        let radius = GuardShieldTiming.domeRadius(
            characterHeight: referenceHeight, characterWidth: referenceWidth)
        let domeHeight = GuardShieldTiming.domeHeight(characterHeight: referenceHeight)
        let center = GuardShieldTiming.domeOrigin(characterPivot: pivot)

        let shield = makeDome(radius: radius, height: domeHeight)
        shield.position = center
        shield.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        shield.scale = SIMD3<Float>(repeating: 0.12)
        #if DEBUG
        print(String(format: "[DeckSpawn][VFX] Dome pivot: %@ boundsY=[%.3f,%.3f] radius=%.3f domeHeight=%.3f pos=(%.3f,%.3f,%.3f)",
                     isGoku ? "Goku" : "personagem", visual.min.y, visual.max.y,
                     radius, domeHeight, center.x, center.y, center.z))
        #endif
        arena.addChild(shield)
        liveShields.append(shield)

        var open = shield.transform
        open.scale = SIMD3<Float>(repeating: 1)
        shield.move(to: open, relativeTo: arena,
                    duration: GuardShieldTiming.appearDuration, timingFunction: .easeOut)

        if blocksImpact || breaksGuard {
            let contact = GuardShieldTiming.contactMoment(opponentClipDuration: opponentClipDuration,
                                                           breaksGuard: breaksGuard)
            schedule(at: contact, token: token, isValid: isValid) {
                [weak self, weak shield] in
                guard let self, let shield, shield.parent != nil else { return }
                if breaksGuard {
                    self.showBreak(on: shield, radius: radius, domeHeight: domeHeight,
                                   token: token, isValid: isValid)
                } else {
                    self.showAbsorption(on: shield, radius: radius, domeHeight: domeHeight,
                                        token: token, isValid: isValid)
                }
                #if DEBUG
                print(String(format: "[DeckSpawn][VFX] Guarda: %@ em %.2fs",
                             breaksGuard ? "ruptura" : "absorção", contact))
                #endif
            }
        }

        let lifetime = GuardShieldTiming.visibleUntil(
            guardClipDuration: guardClipDuration,
            opponentClipDuration: opponentClipDuration,
            blocksImpact: blocksImpact,
            breaksGuard: breaksGuard
        )
        schedule(at: lifetime, token: token, isValid: isValid) {
            [weak self, weak shield] in
            guard let self, let shield else { return }
            shield.removeFromParent()
            self.liveShields.removeAll { $0 === shield }
        }
    }

    private func makeDome(radius: Float, height: Float) -> Entity {
        let root = Entity()

        // UIColor alpha alone does not make a RealityKit material translucent.
        // Explicit transparent blending is required for the blue surface.
        var surface = PhysicallyBasedMaterial()
        surface.baseColor = .init(tint: UIColor(red: 0.08, green: 0.55, blue: 0.98, alpha: 1))
        surface.roughness = .init(floatLiteral: 0.22)
        surface.metallic = .init(floatLiteral: 0)
        surface.blending = .transparent(opacity: .init(floatLiteral: 0.18))
        let shell = ModelEntity(mesh: GuardDomeMesh.hemisphere(radius: radius, height: height),
                                materials: [surface])
        shell.name = "shieldShell"
        root.addChild(shell)

        var hexMaterial = UnlitMaterial(color: UIColor(red: 0.36, green: 0.85, blue: 1, alpha: 1))
        hexMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.52))
        let lattice = ModelEntity(mesh: GuardDomeMesh.hexagons(radius: radius, height: height),
                                  materials: [hexMaterial])
        lattice.name = "shieldHexagons"
        root.addChild(lattice)

        var rimMaterial = UnlitMaterial(color: UIColor(red: 0.32, green: 0.86, blue: 1, alpha: 1))
        rimMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.90))
        let rim = ModelEntity(mesh: GuardDomeMesh.rim(radius: radius, height: height),
                              materials: [rimMaterial])
        rim.name = "shieldRim"
        root.addChild(rim)
        return root
    }

    private func showAbsorption(on shield: Entity, radius: Float, domeHeight: Float,
                                token: Int, isValid: @escaping () -> Bool) {
        let wave = ModelEntity(mesh: GuardDomeMesh.rim(radius: radius * 0.76, height: domeHeight * 0.76),
            materials: [UnlitMaterial(color: UIColor(red: 0.73, green: 0.96, blue: 1, alpha: 0.95))])
        wave.position.y = domeHeight * 0.08
        wave.scale = SIMD3<Float>(repeating: 0.22)
        shield.addChild(wave)
        var expanded = wave.transform
        expanded.scale = SIMD3<Float>(repeating: 1.20)
        wave.move(to: expanded, relativeTo: shield,
                  duration: GuardShieldTiming.pulseLifetime, timingFunction: .easeOut)
        schedule(at: GuardShieldTiming.pulseLifetime, token: token, isValid: isValid) {
            [weak wave] in wave?.removeFromParent()
        }
    }

    private func showBreak(on shield: Entity, radius: Float, domeHeight: Float,
                           token: Int, isValid: @escaping () -> Bool) {
        // O flash vermelho é limitado à Guarda que perde para Técnica.
        if let shell = shield.findEntity(named: "shieldShell") as? ModelEntity {
            var redSurface = PhysicallyBasedMaterial()
            redSurface.baseColor = .init(tint: UIColor(red: 1, green: 0.10, blue: 0.17, alpha: 1))
            redSurface.roughness = .init(floatLiteral: 0.22)
            redSurface.blending = .transparent(opacity: .init(floatLiteral: 0.34))
            shell.model?.materials = [redSurface]
        }
        if let rim = shield.findEntity(named: "shieldRim") as? ModelEntity {
            var redRim = UnlitMaterial(color: UIColor(red: 1, green: 0.24, blue: 0.28, alpha: 1))
            redRim.blending = .transparent(opacity: .init(floatLiteral: 0.95))
            rim.model?.materials = [redRim]
        }
        if let hex = shield.findEntity(named: "shieldHexagons") as? ModelEntity {
            var redHex = UnlitMaterial(color: UIColor(red: 1, green: 0.35, blue: 0.42, alpha: 1))
            redHex.blending = .transparent(opacity: .init(floatLiteral: 0.73))
            hex.model?.materials = [redHex]
        }
        let cracks = ModelEntity(mesh: GuardDomeMesh.cracks(radius: radius, height: domeHeight),
            materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.76, blue: 0.76, alpha: 1))])
        cracks.scale = SIMD3<Float>(repeating: 0.18)
        shield.addChild(cracks)
        var spread = cracks.transform
        spread.scale = SIMD3<Float>(repeating: 1)
        cracks.move(to: spread, relativeTo: shield,
                    duration: GuardShieldTiming.breakLifetime * 0.65,
                    timingFunction: .easeOut)

        // Ruptura rápida, sem deixar um escudo vermelho persistente na cena.
        schedule(at: GuardShieldTiming.breakLifetime, token: token, isValid: isValid) {
            [weak shield] in
            guard let shield else { return }
            shield.removeFromParent()
            self.liveShields.removeAll { $0 === shield }
        }
    }

    private func schedule(at delay: TimeInterval, token: Int,
                          isValid: @escaping () -> Bool,
                          action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) { [weak self] in
            guard let self, self.generation == token, isValid() else { return }
            action()
        }
    }
}
