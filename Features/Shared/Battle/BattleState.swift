import Foundation

enum BattleWinner: Equatable {
    case player
    case enemy
}

enum BattleRoundResult: Equatable {
    case playerWin
    case enemyWin
    case draw
}

struct BattleState: Equatable {

    let playerCard: CardDefinition
    let enemyCard: CardDefinition

    var playerHP: Int
    var enemyHP: Int

    var round: Int = 1

    var lastPlayerMove: BattleMove?
    var lastEnemyMove: BattleMove?
    var lastRoundResult: BattleRoundResult?

    var winner: BattleWinner?

    var playerHPProgress: Double {
        guard playerCard.maxHP > 0 else {
            return 0
        }

        return Double(playerHP)
            / Double(playerCard.maxHP)
    }

    var enemyHPProgress: Double {
        guard enemyCard.maxHP > 0 else {
            return 0
        }

        return Double(enemyHP)
            / Double(enemyCard.maxHP)
    }

    static func newBattle(
        player: CardDefinition,
        enemy: CardDefinition
    ) -> BattleState {

        BattleState(
            playerCard: player,
            enemyCard: enemy,
            playerHP: player.maxHP,
            enemyHP: enemy.maxHP
        )
    }
}

struct BattleTurnResolution {

    let state: BattleState
    let message: String
}
