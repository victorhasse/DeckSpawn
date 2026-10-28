import XCTest
@testable import CardArenaAR

/// Tests synchronous state transitions. No AR session, networking or time delays needed.
final class GameFlowStateTests: XCTestCase {

    @MainActor
    func testSinglePlayerStartsInCardSelection() {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        XCTAssertEqual(flow.screen, .singlePlayer)
        XCTAssertEqual(flow.singlePlayerPhase, .choosingCard)
        XCTAssertNil(flow.playerCard)
        XCTAssertNil(flow.enemyCard)
        XCTAssertNil(flow.battleState)
        XCTAssertFalse(flow.isBattleStarted)
        XCTAssertFalse(flow.isShowingVersus)
    }

    @MainActor
    func testConfirmationSelectsDifferentOpponent() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        let opponent = try XCTUnwrap(flow.confirmPlayerCard(player))
        XCTAssertNotEqual(opponent.id, player.id)
        XCTAssertEqual(flow.playerCard, player)
        XCTAssertEqual(flow.enemyCard, opponent)
        XCTAssertEqual(flow.singlePlayerPhase, .summoningEnemy)
    }

    @MainActor
    func testSummonFailureReturnsToCardSelection() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFail()
        XCTAssertEqual(flow.singlePlayerPhase, .choosingCard)
        XCTAssertNil(flow.playerCard)
        XCTAssertNil(flow.enemyCard)
        XCTAssertNil(flow.battleState)
        XCTAssertFalse(flow.isShowingVersus)
    }

    @MainActor
    func testSuccessfulSummonStartsVersusIntro() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        XCTAssertEqual(flow.singlePlayerPhase, .battleReady)
        XCTAssertNotNil(flow.battleState)
        XCTAssertTrue(flow.isShowingVersus)
        XCTAssertFalse(flow.isBattleStarted)
        flow.returnToMainMenu() // cancels the delayed VS callback
    }

    @MainActor
    func testReturnToMenuResetsCombatState() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        flow.returnToMainMenu()
        XCTAssertEqual(flow.screen, .mainMenu)
        XCTAssertEqual(flow.singlePlayerPhase, .choosingCard)
        XCTAssertNil(flow.playerCard)
        XCTAssertNil(flow.enemyCard)
        XCTAssertNil(flow.battleState)
        XCTAssertNil(flow.battleCountdown)
        XCTAssertFalse(flow.isShowingVersus)
        XCTAssertFalse(flow.isBattleStarted)
        XCTAssertEqual(flow.turnSecondsRemaining, BattleRules.turnDurationSeconds)
    }

    @MainActor
    func testRematchRequiresFinishedDuel() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        XCTAssertFalse(flow.restartBattleWithSameCharacters())

        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        XCTAssertFalse(flow.restartBattleWithSameCharacters())
        flow.returnToMainMenu()
    }

    @MainActor
    func testRematchReusesCharactersResetsHPAndStartsVersus() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        let enemy = try XCTUnwrap(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        var previousBattle = try XCTUnwrap(flow.battleState)
        previousBattle.enemyHP = 0
        previousBattle.playerHP = 13
        previousBattle.round = 5
        previousBattle.winner = .player
        previousBattle.lastRoundResult = .playerWin
        flow.battleState = previousBattle

        XCTAssertTrue(flow.restartBattleWithSameCharacters())
        let newBattle = try XCTUnwrap(flow.battleState)
        XCTAssertEqual(newBattle.playerCard, player)
        XCTAssertEqual(newBattle.enemyCard, enemy)
        XCTAssertEqual(newBattle.playerHP, player.maxHP)
        XCTAssertEqual(newBattle.enemyHP, enemy.maxHP)
        XCTAssertEqual(newBattle.round, 1)
        XCTAssertNil(newBattle.winner)
        XCTAssertNil(newBattle.lastRoundResult)
        XCTAssertNil(newBattle.lastPlayerMove)
        XCTAssertNil(newBattle.lastEnemyMove)
        XCTAssertEqual(flow.singlePlayerPhase, .battleReady)
        XCTAssertTrue(flow.isShowingVersus)
        XCTAssertFalse(flow.isBattleStarted)
        XCTAssertNil(flow.battleCountdown)
        XCTAssertEqual(flow.turnSecondsRemaining, BattleRules.turnDurationSeconds)
        flow.returnToMainMenu()
    }

    @MainActor
    func testRematchCannotBeTriggeredTwice() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        var finished = try XCTUnwrap(flow.battleState)
        finished.winner = .enemy
        finished.playerHP = 0
        flow.battleState = finished

        XCTAssertTrue(flow.restartBattleWithSameCharacters())
        XCTAssertFalse(flow.restartBattleWithSameCharacters())
        flow.returnToMainMenu()
    }

    @MainActor
    func testNewSessionStartsCleanAfterLeavingDuringVersus() throws {
        let flow = GameFlowState()
        flow.startSinglePlayer()
        let player = try XCTUnwrap(CardDatabase.all.first)
        XCTAssertNotNil(flow.confirmPlayerCard(player))
        flow.enemySummonDidFinish()
        XCTAssertTrue(flow.isShowingVersus)
        flow.returnToMainMenu()
        flow.startSinglePlayer()
        XCTAssertEqual(flow.screen, .singlePlayer)
        XCTAssertFalse(flow.isShowingVersus)
        XCTAssertNil(flow.battleState)
        XCTAssertNil(flow.battleCountdown)
        XCTAssertFalse(flow.isBattleStarted)
    }
}
