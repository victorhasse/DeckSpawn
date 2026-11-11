import XCTest
@testable import CardArenaAR

final class StageRibbonTimingTests: XCTestCase {
    func testTextIsHiddenDuringCooldown() {
        XCTAssertEqual(StageRibbonTiming.combatOpacity(at: 8), 0)
        XCTAssertEqual(StageRibbonTiming.combatOpacity(at: 23), 0)
    }

    func testTextReturnsOnNextCycle() {
        XCTAssertGreaterThan(StageRibbonTiming.combatOpacity(at: 25), 0)
    }

    func testFadeInAndOut() {
        XCTAssertEqual(StageRibbonTiming.combatOpacity(at: 0), 0)
        XCTAssertGreaterThan(StageRibbonTiming.combatOpacity(at: 1), 0.99)
        XCTAssertLessThan(StageRibbonTiming.combatOpacity(at: 3.9), 0.4)
    }

    func testFightStartsOnlyAtEndOfCountdown() {
        XCTAssertTrue(StageRibbonTiming.isFightTransition(from: .countdown(1), to: .battle))
        XCTAssertFalse(StageRibbonTiming.isFightTransition(from: .versus, to: .battle))
        XCTAssertFalse(StageRibbonTiming.isFightTransition(from: .countdown(2), to: .battle))
    }

    func testCycleDurationIs24Seconds() {
        XCTAssertEqual(StageRibbonTiming.fullCycleSeconds, 24)
    }
}
