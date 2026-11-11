import Foundation
import simd

enum GuardShieldTiming {
    static let appearDuration: TimeInterval = 0.16
    static let quietLifetime: TimeInterval = 0.55
    static let pulseLifetime: TimeInterval = 0.22
    static let breakLifetime: TimeInterval = 0.22
    static let cleanupMargin: TimeInterval = 0.04

    static func blockMoment(opponentClipDuration: TimeInterval) -> TimeInterval {
        max(0.20, max(0, opponentClipDuration) * 0.92)
    }

    static func contactMoment(opponentClipDuration: TimeInterval,
                              breaksGuard: Bool) -> TimeInterval {
        // Ambos os estados são sincronizados à ação do adversário.
        max(0.18, max(0, opponentClipDuration) * (breaksGuard ? 0.84 : 0.92))
    }

    static func visibleUntil(guardClipDuration: TimeInterval,
                             opponentClipDuration: TimeInterval,
                             blocksImpact: Bool,
                             breaksGuard: Bool = false) -> TimeInterval {
        if blocksImpact || breaksGuard {
            return contactMoment(opponentClipDuration: opponentClipDuration,
                                 breaksGuard: breaksGuard)
                + (breaksGuard ? breakLifetime : pulseLifetime) + cleanupMargin
        }
        return min(0.75, max(0.38, max(0, guardClipDuration) * 0.65))
    }


    /// O domo é ancorado no pivô no palco, não no bound de um rig animado.
    /// Esta função deliberadamente NÃO depende da pose atual do USDZ.
    static func domeOrigin(characterPivot: SIMD3<Float>) -> SIMD3<Float> {
        characterPivot
    }

    /// Folga acima da cabeça para acomodar a postura de Guarda.
    static func domeHeight(characterHeight: Float) -> Float {
        max(0.22, max(0, characterHeight) * 1.25)
    }

    /// Aumenta a folga lateral, mas evita esferas gigantes com bounds corrompidos.
    static func domeRadius(characterHeight: Float, characterWidth: Float) -> Float {
        max(0.30, max(max(0, characterHeight) * 0.70,
                      max(0, characterWidth) * 0.95))
    }

    static func radius(characterHeight: Float) -> Float {
        min(0.23, max(0.105, max(0, characterHeight) * 0.29))
    }
}
