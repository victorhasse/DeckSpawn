import Foundation

/// Pure timing and movement selection; no RealityKit or actor dependencies.
nonisolated struct MrsIncredibleVFXTiming {
    enum Move { case punch, kick }
    let clipDuration: TimeInterval
    let move: Move

    init(clipDuration: TimeInterval, move: Move) {
        self.clipDuration = max(0.30, clipDuration)
        self.move = move
    }

    var startAt: TimeInterval { clipDuration * 0.08 }
    var endAt: TimeInterval { clipDuration * 0.92 }
    var sampleInterval: TimeInterval { 0.045 }
    var trailLifetime: TimeInterval { move == .punch ? 0.21 : 0.30 }
    var maxTrails: Int { move == .punch ? 22 : 28 }
    var minimumMovement: Float { move == .punch ? 0.009 : 0.012 }

    func isActive(at time: TimeInterval) -> Bool {
        time >= startAt && time < endAt
    }

    /// A segment always belongs to one joint. Missing samples or large jumps
    /// are never connected to a different limb or a guessed position.
    struct Segment: Equatable {
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        let side: Side
    }
    enum Side: Equatable { case left, right }

    func strongestSegment(leftBefore: SIMD3<Float>?, leftNow: SIMD3<Float>?,
                          rightBefore: SIMD3<Float>?, rightNow: SIMD3<Float>?) -> Segment? {
        func candidate(_ before: SIMD3<Float>?, _ now: SIMD3<Float>?, _ side: Side)
            -> (segment: Segment, distance: Float)? {
            guard let before, let now else { return nil }
            let delta = now - before
            let distance = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
            guard distance.isFinite, distance >= minimumMovement * minimumMovement,
                  distance <= 0.28 * 0.28 else { return nil }
            return (Segment(start: before, end: now, side: side), distance)
        }
        let left = candidate(leftBefore, leftNow, .left)
        let right = candidate(rightBefore, rightNow, .right)
        if let left, let right { return left.distance > right.distance ? left.segment : right.segment }
        return left?.segment ?? right?.segment
    }
}
