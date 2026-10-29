import XCTest
@testable import CardArenaAR

/// Exercises the real battle engine without opening ARKit or loading USDZ assets.
final class BattleEngineTests: XCTestCase {

    private func makeCard(
        _ name: String,
        hp: Int = 100,
        attack: Int = 25
    ) -> CardDefinition {
        CardDefinition(
            referenceImageName: name.lowercased(),
            displayName: name,
            modelName: "\(name)_Idle.usdz",
            modelHeight: 0.60,
            yawOffset: 0,
            maxHP: hp,
            attackPower: attack
        )
    }

    private func newBattle(playerAttack: Int = 25, enemyAttack: Int = 25) -> BattleState {
        BattleState.newBattle(
            player: makeCard("Player", attack: playerAttack),
            enemy: makeCard("CPU", attack: enemyAttack)
        )
    }

    func testMoveCycleIsCompleteAndConsistent() {
        let expected: [(BattleMove, BattleMove)] = [
            (.impact, .technique),
            (.technique, .defense),
            (.defense, .impact)
        ]

        XCTAssertEqual(BattleMove.allCases.count, 3)
        for (winner, loser) in expected {
            XCTAssertTrue(winner.beats(loser))
            XCTAssertFalse(loser.beats(winner))
            XCTAssertFalse(winner.beats(winner))
        }
        for move in BattleMove.allCases {
            XCTAssertEqual(BattleMove.allCases.filter { move.beats($0) }.count, 1)
            XCTAssertEqual(BattleMove.allCases.filter { $0.beats(move) }.count, 1)
        }
    }

    func testNewBattleStartsWithFullHPAndNoResult() {
        let state = newBattle()
        XCTAssertEqual(state.playerHP, 100)
        XCTAssertEqual(state.enemyHP, 100)
        XCTAssertEqual(state.round, 1)
        XCTAssertNil(state.lastPlayerMove)
        XCTAssertNil(state.lastEnemyMove)
        XCTAssertNil(state.lastRoundResult)
        XCTAssertNil(state.winner)
        XCTAssertEqual(state.playerHPProgress, 1)
        XCTAssertEqual(state.enemyHPProgress, 1)
    }

    func testDrawKeepsHPAndAdvancesRound() {
        let result = BattleEngine.resolveTurn(
            state: newBattle(), playerMove: .impact, enemyMove: .impact
        ).state
        XCTAssertEqual(result.playerHP, 100)
        XCTAssertEqual(result.enemyHP, 100)
        XCTAssertEqual(result.lastRoundResult, .draw)
        XCTAssertEqual(result.lastPlayerMove, .impact)
        XCTAssertEqual(result.lastEnemyMove, .impact)
        XCTAssertEqual(result.round, 2)
        XCTAssertNil(result.winner)
    }

    func testPlayerWinningMoveDamagesOnlyEnemy() {
        let result = BattleEngine.resolveTurn(
            state: newBattle(), playerMove: .impact, enemyMove: .technique
        ).state
        XCTAssertEqual(result.playerHP, 100)
        XCTAssertEqual(result.enemyHP, 75)
        XCTAssertEqual(result.lastRoundResult, .playerWin)
        XCTAssertEqual(result.round, 2)
        XCTAssertNil(result.winner)
        XCTAssertEqual(result.enemyHPProgress, 0.75)
    }

    func testCPUWinningMoveDamagesOnlyPlayer() {
        let result = BattleEngine.resolveTurn(
            state: newBattle(), playerMove: .technique, enemyMove: .impact
        ).state
        XCTAssertEqual(result.playerHP, 75)
        XCTAssertEqual(result.enemyHP, 100)
        XCTAssertEqual(result.lastRoundResult, .enemyWin)
        XCTAssertEqual(result.round, 2)
        XCTAssertNil(result.winner)
    }

    func testPlayerWinsWhenEnemyHPReachesZero() {
        var state = newBattle()
        for _ in 0..<4 {
            state = BattleEngine.resolveTurn(
                state: state, playerMove: .impact, enemyMove: .technique
            ).state
        }
        XCTAssertEqual(state.enemyHP, 0)
        XCTAssertEqual(state.playerHP, 100)
        XCTAssertEqual(state.winner, .player)
        XCTAssertEqual(state.round, 4) // final round does not advance
    }

    func testCPUWinsWhenPlayerHPReachesZero() {
        var state = newBattle()
        for _ in 0..<4 {
            state = BattleEngine.resolveTurn(
                state: state, playerMove: .technique, enemyMove: .impact
            ).state
        }
        XCTAssertEqual(state.playerHP, 0)
        XCTAssertEqual(state.enemyHP, 100)
        XCTAssertEqual(state.winner, .enemy)
        XCTAssertEqual(state.round, 4)
    }

    func testLargeDamageNeverProducesNegativeHP() {
        let state = newBattle(playerAttack: 500, enemyAttack: 500)
        let playerWin = BattleEngine.resolveTurn(
            state: state, playerMove: .impact, enemyMove: .technique
        ).state
        let enemyWin = BattleEngine.resolveTurn(
            state: state, playerMove: .technique, enemyMove: .impact
        ).state
        XCTAssertEqual(playerWin.enemyHP, 0)
        XCTAssertEqual(playerWin.winner, .player)
        XCTAssertEqual(enemyWin.playerHP, 0)
        XCTAssertEqual(enemyWin.winner, .enemy)
    }

    func testHealthProgressReturnsZeroForZeroMaximumHP() {
        let zero = makeCard("Zero", hp: 0)
        let state = BattleState.newBattle(player: zero, enemy: zero)
        XCTAssertEqual(state.playerHPProgress, 0)
        XCTAssertEqual(state.enemyHPProgress, 0)
    }

    func testBattleTimersHaveReasonablePositiveDefaults() {
        XCTAssertGreaterThan(BattleRules.startCountdownSeconds, 0)
        XCTAssertGreaterThan(BattleRules.turnDurationSeconds, 0)
        XCTAssertGreaterThan(BattleRules.roundResultDisplaySeconds, 0)
    }

    func testFloatingDamageReportsExactlyLostEnemyHP() throws {
        let card = try XCTUnwrap(CardDatabase.all.first)
        let enemy = try XCTUnwrap(CardDatabase.all.first { $0.id != card.id })
        let before = BattleState.newBattle(player: card, enemy: enemy)
        var after = before
        after.enemyHP = max(0, before.enemyHP - 25)
        XCTAssertEqual(
            BattleDamage.between(before: before, after: after),
            BattleDamage(target: .enemy, amount: before.enemyHP - after.enemyHP)
        )
    }

    func testFloatingDamageReportsActualRemainingHPOnFinishingBlow() throws {
        let card = try XCTUnwrap(CardDatabase.all.first)
        let enemy = try XCTUnwrap(CardDatabase.all.first { $0.id != card.id })
        var before = BattleState.newBattle(player: card, enemy: enemy)
        before.playerHP = 4
        var after = before
        after.playerHP = 0
        XCTAssertEqual(
            BattleDamage.between(before: before, after: after),
            BattleDamage(target: .player, amount: 4)
        )
    }

    func testFloatingDamageIsAbsentOnDrawOrNoHPLoss() throws {
        let card = try XCTUnwrap(CardDatabase.all.first)
        let enemy = try XCTUnwrap(CardDatabase.all.first { $0.id != card.id })
        let state = BattleState.newBattle(player: card, enemy: enemy)
        XCTAssertNil(BattleDamage.between(before: state, after: state))
    }

    func testFloatingDamageDoesNotShowAmbiguousDoubleDamage() throws {
        let card = try XCTUnwrap(CardDatabase.all.first)
        let enemy = try XCTUnwrap(CardDatabase.all.first { $0.id != card.id })
        let before = BattleState.newBattle(player: card, enemy: enemy)
        var after = before
        after.playerHP -= 2
        after.enemyHP -= 2
        XCTAssertNil(BattleDamage.between(before: before, after: after))
    }
}
