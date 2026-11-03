import Foundation

/// Light, configurable anime accents for the rapid punches in Goku_Tecnic.usdz.
/// Beat fractions are initial estimates; align them with real gameplay video.
/// They never alter HP, round results, or reaction animations.
struct GokuTechniqueTiming {
    enum Hand: Equatable {
        case left
        case right
    }

    struct Beat: Equatable {
        let fraction: Double
        let hand: Hand
        let strength: Float
    }

    // Escalation across three anime punches: subtle -> medium -> strongest.
    static let beats: [Beat] = [
        .init(fraction: 0.24, hand: .right, strength: 0.75),
        .init(fraction: 0.45, hand: .left, strength: 0.90),
        .init(fraction: 0.68, hand: .right, strength: 1.10)
    ]

    static let slashLifetime: TimeInterval = 0.115
    static let contactLifetime: TimeInterval = 0.115
    static let finisherLifetime: TimeInterval = 0.16
    static let finalImpactStrength: Float = 1.15
    // Preserve old property for callers compiled against the earlier test code.
    static let streakLifetime = slashLifetime

    let clipDuration: TimeInterval

    init(clipDuration: TimeInterval) {
        self.clipDuration = max(0.30, clipDuration)
    }

    func moment(for beat: Beat) -> TimeInterval {
        clipDuration * max(0, min(1, beat.fraction))
    }

    var finalAccentAt: TimeInterval {
        Self.beats.map(moment(for:)).max() ?? 0
    }
}
