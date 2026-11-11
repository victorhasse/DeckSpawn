import Foundation

/// View-only cue from the existing singleplayer battle clock.
/// No extra countdown timer is created by the stage.
enum StageRibbonCue: Equatable {
    case ambient
    case versus
    case countdown(Int)
    case battle
    case action
    case result
}

/// Letreiro on for 4 seconds, then off for 20, with short fades.
enum StageRibbonTiming {
    static let visibleSeconds: TimeInterval = 4
    static let quietSeconds: TimeInterval = 20
    static let fadeSeconds: TimeInterval = 0.5
    static let fightSeconds: TimeInterval = 1.0
    static let fullCycleSeconds = visibleSeconds + quietSeconds

    static func combatOpacity(at seconds: TimeInterval) -> Float {
        let elapsed = max(0, seconds)
        let portion = elapsed.truncatingRemainder(dividingBy: fullCycleSeconds)
        guard portion < visibleSeconds else { return 0 }
        let fadeIn = min(1, portion / fadeSeconds)
        let fadeOut = min(1, (visibleSeconds - portion) / fadeSeconds)
        return Float(max(0, min(fadeIn, fadeOut)))
    }

    static func isFightTransition(from previous: StageRibbonCue, to next: StageRibbonCue) -> Bool {
        if case .countdown(1) = previous, next == .battle { return true }
        return false
    }
}
