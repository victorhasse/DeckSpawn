import XCTest
@testable import CardArenaAR

final class SinglePlayerAITests: XCTestCase {
    func testEasyRepeatsPreviousCPUMove() {
        var ai = SinglePlayerAI()
        let initial = ai.chooseMove(difficulty: .easy, pick: { _ in 0 })
        let repeatMove = ai.chooseMove(difficulty: .easy, pick: { _ in 0 })
        XCTAssertEqual(initial, repeatMove)
        XCTAssertEqual(ai.previousCPUMove, repeatMove)
    }

    func testEasyCanChooseAnotherMove() {
        var ai = SinglePlayerAI()
        XCTAssertEqual(ai.chooseMove(difficulty: .easy, pick: { _ in 0 }), .impact)
        // 99 refuses to repeat, then choose index 1.
        var calls = 0
        let changed = ai.chooseMove(difficulty: .easy, pick: { upper in
            calls += 1
            return upper == 100 ? 99 : 1
        })
        XCTAssertEqual(changed, .technique)
        XCTAssertEqual(calls, 2)
    }

    func testNormalUsesRandomMoveIndex() {
        var ai = SinglePlayerAI()
        XCTAssertEqual(ai.chooseMove(difficulty: .normal, pick: { _ in 0 }), .impact)
        XCTAssertEqual(ai.chooseMove(difficulty: .normal, pick: { _ in 1 }), .technique)
        XCTAssertEqual(ai.chooseMove(difficulty: .normal, pick: { _ in 2 }), .defense)
    }

    func testHardBeforeHistoryIsRandom() {
        var ai = SinglePlayerAI()
        ai.recordCompletedPlayerMove(.impact)
        XCTAssertEqual(ai.chooseMove(difficulty: .hard, pick: { _ in 1 }), .technique)
    }

    func testHardCountersPastFrequentImpactMove() {
        var ai = SinglePlayerAI()
        for move in [BattleMove.impact, .impact, .defense, .impact] {
            ai.recordCompletedPlayerMove(move)
        }
        // With 0 as the probability roll, hard chooses defense to beat impact.
        XCTAssertEqual(ai.chooseMove(difficulty: .hard, pick: { _ in 0 }), .defense)
    }

    func testHardStillHasRandomBranch() {
        var ai = SinglePlayerAI()
        ai.recordCompletedPlayerMove(.impact)
        ai.recordCompletedPlayerMove(.impact)
        XCTAssertEqual(ai.chooseMove(difficulty: .hard, pick: { upper in
            upper == 100 ? 99 : 1
        }), .technique)
    }

    func testOnlyCompletedMovesAreUsedAndHistoryIsLimited() {
        var ai = SinglePlayerAI()
        for _ in 0..<10 { ai.recordCompletedPlayerMove(.technique) }
        XCTAssertEqual(ai.playerHistory.count, SinglePlayerAI.historyWindow)
        XCTAssertTrue(ai.playerHistory.allSatisfy { $0 == .technique })
        XCTAssertEqual(ai.chooseMove(difficulty: .hard, pick: { _ in 0 }), .impact)
    }

    func testResetRemovesHistoryAndPreviousCPUChoice() {
        var ai = SinglePlayerAI()
        ai.recordCompletedPlayerMove(.impact)
        ai.recordCompletedPlayerMove(.impact)
        _ = ai.chooseMove(difficulty: .hard, pick: { _ in 0 })
        ai.reset()
        XCTAssertTrue(ai.playerHistory.isEmpty)
        XCTAssertNil(ai.previousCPUMove)
        XCTAssertEqual(ai.chooseMove(difficulty: .hard, pick: { _ in 2 }), .defense)
    }
}
