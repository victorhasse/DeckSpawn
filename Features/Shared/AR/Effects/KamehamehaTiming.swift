import Foundation

/// Initial calibration for Goku_Impact.usdz. Values are editable after the
/// iPhone video review; no assumption of a fixed frame rate or clip length.
struct KamehamehaTiming {
    // Calibrated from four iPhone captures of Goku_Impact.usdz (3.33 s).
    // The old contact at 3.40 s trailed the animation; bring a successful
    // impact forward while ensuring the defender's own attack can finish.
    static let successfulHitFraction = 0.92

    static func reactionDelayForSuccessfulHit(
        gokuClipDuration: TimeInterval,
        opponentClipDuration: TimeInterval
    ) -> TimeInterval {
        let clip = max(0.30, gokuClipDuration)
        return max(0.35, clip * successfulHitFraction, opponentClipDuration + 0.05)
    }

    /// On a block, miss or draw, the projectile should still finish near the
    /// end of Goku's gesture; there is no Hit reaction to wait for.
    static func visualImpactDelay(
        clipDuration: TimeInterval,
        combatReactionDelay: TimeInterval,
        hitsDefender: Bool
    ) -> TimeInterval {
        if hitsDefender { return combatReactionDelay }
        return min(combatReactionDelay, max(0.30, clipDuration) * successfulHitFraction)
    }

    let chargeAt: TimeInterval
    let launchAt: TimeInterval
    let impactAt: TimeInterval
    let cleanupAt: TimeInterval

    init(clipDuration: TimeInterval, reactionDelay: TimeInterval) {
        let clip = max(0.30, clipDuration)
        chargeAt = clip * 0.04
        launchAt = clip * 0.68
        // The successful-hit delay is shared with the Hit/Defeat reaction.
        // Non-damaging impacts finish near the end of the attack gesture.
        impactAt = max(launchAt + 0.08, reactionDelay)
        cleanupAt = impactAt + 0.14
    }

    /// Smoothly grows from 18% to 100% while Goku is charging.
    func orbScale(at animationTime: TimeInterval) -> Float {
        let span = max(launchAt - chargeAt, 0.001)
        let progress = max(0, min(1, (animationTime - chargeAt) / span))
        let eased = progress * progress * (3 - 2 * progress)
        return Float(0.18 + 0.82 * eased)
    }

    func flightProgress(at animationTime: TimeInterval) -> Float {
        let span = max(impactAt - launchAt, 0.001)
        return Float(max(0, min(1, (animationTime - launchAt) / span)))
    }
}
