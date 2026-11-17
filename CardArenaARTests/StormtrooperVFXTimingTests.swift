import XCTest
@testable import CardArenaAR

final class StormtrooperVFXTimingTests: XCTestCase {
    func testPunchAccentsAreOrderedAndInsideAnimation() {
        let t = StormtrooperVFXTiming(clipDuration: 2)
        XCTAssertEqual(t.punchAccentTimes.count, 3)
        XCTAssertEqual(t.punchAccentTimes, t.punchAccentTimes.sorted())
        XCTAssertTrue(t.punchAccentTimes.allSatisfy { $0 > t.punchStartAt && $0 < t.punchEndAt })
    }

    func testKickArcsAreVisibleBeforeEndOfClip() {
        let t = StormtrooperVFXTiming(clipDuration: 1.8)
        XCTAssertTrue(t.kickStartAt < t.kickArcAt)
        XCTAssertTrue(t.kickArcAt < t.kickSecondArcAt)
        XCTAssertTrue(t.kickSecondArcAt < t.kickEndAt)
        XCTAssertLessThanOrEqual(t.kickEndAt, t.clipDuration)
    }

    func testVisualWindowsDoNotRunForever() {
        let t = StormtrooperVFXTiming(clipDuration: 1)
        XCTAssertFalse(t.shouldShowPunchTrail(at: 0))
        XCTAssertTrue(t.shouldShowPunchTrail(at: 0.50))
        XCTAssertFalse(t.shouldShowPunchTrail(at: 1))
        XCTAssertFalse(t.shouldShowKickTrail(at: 0))
        XCTAssertTrue(t.shouldShowKickTrail(at: 0.50))
        XCTAssertFalse(t.shouldShowKickTrail(at: 1))
    }

    func testShortClipUsesSafeMinimumDuration() {
        let t = StormtrooperVFXTiming(clipDuration: 0.01)
        XCTAssertEqual(t.clipDuration, 0.30, accuracy: 0.0001)
        XCTAssertGreaterThan(t.kickArcAt, 0)
        XCTAssertLessThan(t.punchAccentTimes.last ?? 100, t.clipDuration)
    }
}
