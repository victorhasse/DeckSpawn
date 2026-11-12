import Foundation

/// Initial timing fractions for the user-provided Spiderman animations.
/// Tune after an iPhone video: the actual playback controller provides time.
/// These are VFX-only cues; neither damage nor the reaction deadline changes.
struct SpiderManVFXTiming {
    let clipDuration: TimeInterval
    init(clipDuration: TimeInterval) {
        self.clipDuration = max(0.30, clipDuration)
    }

    var webLaunchAt: TimeInterval { clipDuration * 0.24 }
    var webConnectAt: TimeInterval { clipDuration * 0.42 }
    var webRetractAt: TimeInterval { clipDuration * 0.62 }
    var webEndAt: TimeInterval { clipDuration * 0.86 }
    var kickStartAt: TimeInterval { clipDuration * 0.19 }
    var kickArcAt: TimeInterval { clipDuration * 0.43 }
    var kickSecondArcAt: TimeInterval { clipDuration * 0.67 }
    var kickEndAt: TimeInterval { clipDuration * 0.93 }

    /// Fraction of the strand drawn between wrist and target. Starts at the
    /// wrist, stays attached for the pull, then retracts to the moving wrist.
    func webExtension(at t: TimeInterval) -> Float {
        guard t >= webLaunchAt && t < webEndAt else { return 0 }
        if t < webConnectAt {
            return ease(Float((t - webLaunchAt) / max(0.001, webConnectAt - webLaunchAt)))
        }
        if t < webRetractAt { return 1 }
        return 1 - ease(Float((t - webRetractAt) / max(0.001, webEndAt - webRetractAt)))
    }

    private func ease(_ raw: Float) -> Float {
        let t = min(1, max(0, raw))
        return t * t * (3 - 2 * t)
    }
}
