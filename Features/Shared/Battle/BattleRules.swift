import Foundation

enum BattleRules {

    static let startCountdownSeconds = 3
    static let turnDurationSeconds = 25
    static let roundResultDisplaySeconds: TimeInterval = 2.0
    /// Time after the result AND 3D sequences have completed.
    static let roundRecoverySeconds: TimeInterval = 0.5
    /// Safety fallback if a completion callback is lost during an AR session.
    static let maxRoundAnimationWaitSeconds: TimeInterval = 20.0
}
