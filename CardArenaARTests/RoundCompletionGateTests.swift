import XCTest
@testable import CardArenaAR

final class RoundCompletionGateTests: XCTestCase {
    @MainActor
    func testResultCannotUnlockBeforeAnimationsFinish() {
        var gate = RoundCompletionGate()
        XCTAssertFalse(gate.markResultDisplayFinished())
        XCTAssertFalse(gate.didScheduleRecovery)
        XCTAssertTrue(gate.markAnimationsFinished())
        XCTAssertTrue(gate.didScheduleRecovery)
    }

    @MainActor
    func testAnimationsCannotUnlockBeforeResultDisplay() {
        var gate = RoundCompletionGate()
        XCTAssertFalse(gate.markAnimationsFinished())
        XCTAssertFalse(gate.didScheduleRecovery)
        XCTAssertTrue(gate.markResultDisplayFinished())
    }

    @MainActor
    func testDuplicateCompletionNeverSchedulesTwice() {
        var gate = RoundCompletionGate()
        XCTAssertFalse(gate.markAnimationsFinished())
        XCTAssertFalse(gate.markAnimationsFinished())
        XCTAssertTrue(gate.markResultDisplayFinished())
        XCTAssertFalse(gate.markResultDisplayFinished())
        XCTAssertFalse(gate.markAnimationsFinished())
    }

    @MainActor
    func testNewGateStartsLockedAfterPreviousRound() {
        var previous = RoundCompletionGate()
        _ = previous.markResultDisplayFinished()
        _ = previous.markAnimationsFinished()
        let next = RoundCompletionGate()
        XCTAssertFalse(next.didScheduleRecovery)
        XCTAssertFalse(next.resultDisplayFinished)
        XCTAssertFalse(next.animationsFinished)
    }

    @MainActor
    func testRecoveryDurationAndWatchdogHaveSafeValues() {
        XCTAssertGreaterThan(BattleRules.roundRecoverySeconds, 0)
        XCTAssertGreaterThan(BattleRules.maxRoundAnimationWaitSeconds, BattleRules.roundResultDisplaySeconds)
    }
}
