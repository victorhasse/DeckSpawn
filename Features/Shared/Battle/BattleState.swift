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


/// The actual HP lost by exactly one fighter in a resolved round.
/// Independent of the advertised attack power, so a finishing blow cannot
/// display more damage than the remaining HP.
struct BattleDamage: Equatable {
    enum Target: Equatable {
        case player
        case enemy
    }

    let target: Target
    let amount: Int

    static func between(before: BattleState, after: BattleState) -> BattleDamage? {
        let lostByPlayer = max(0, before.playerHP - after.playerHP)
        let lostByEnemy = max(0, before.enemyHP - after.enemyHP)

        // A draw inflicts no damage. The current battle engine only damages
        // one fighter per round; avoid displaying ambiguous double damage.
        if lostByPlayer > 0 && lostByEnemy == 0 {
            return BattleDamage(target: .player, amount: lostByPlayer)
        }
        if lostByEnemy > 0 && lostByPlayer == 0 {
            return BattleDamage(target: .enemy, amount: lostByEnemy)
        }
        return nil
    }
}
