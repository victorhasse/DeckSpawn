import Foundation

/// Visual-only timing landmarks. The real animation playback controls the clock;
/// no changes are made to the round timing, damage, or guard logic.
struct StormtrooperVFXTiming {
    let clipDuration: TimeInterval

    init(clipDuration: TimeInterval) {
        self.clipDuration = max(0.30, clipDuration)
    }

    var punchStartAt: TimeInterval { clipDuration * 0.14 }
    var punchEndAt: TimeInterval { clipDuration * 0.92 }
    var punchAccentTimes: [TimeInterval] {
        [0.28, 0.52, 0.75].map { clipDuration * $0 }
    }
    var kickStartAt: TimeInterval { clipDuration * 0.17 }
    var kickArcAt: TimeInterval { clipDuration * 0.33 }
    var kickSecondArcAt: TimeInterval { clipDuration * 0.57 }
    var kickEndAt: TimeInterval { clipDuration * 0.95 }

    func shouldShowPunchTrail(at time: TimeInterval) -> Bool {
        time >= punchStartAt && time < punchEndAt
    }

    func shouldShowKickTrail(at time: TimeInterval) -> Bool {
        time >= kickStartAt && time < kickEndAt
    }
}
