import Foundation

enum BattleEngine {
    static func resolveTurn(
        state: BattleState,
        playerMove: BattleMove,
        enemyMove: BattleMove
    ) -> BattleTurnResolution {
        var updatedState = state
        updatedState.lastPlayerMove = playerMove
        updatedState.lastEnemyMove = enemyMove

        if playerMove == enemyMove {
            updatedState.lastRoundResult = .draw
            updatedState.round += 1

            return BattleTurnResolution(
                state: updatedState,
                message: DeckSpawnL10n.format(
                    "%@ contra %@: empate. Ninguém sofreu dano.",
                    playerMove.displayName,
                    enemyMove.displayName
                )
            )
        }

        if playerMove.beats(enemyMove) {
            updatedState.lastRoundResult = .playerWin
            updatedState.enemyHP = max(
                0,
                updatedState.enemyHP - state.playerCard.attackPower
            )

            if updatedState.enemyHP == 0 {
                updatedState.winner = .player
            } else {
                updatedState.round += 1
            }

            return BattleTurnResolution(
                state: updatedState,
                message: DeckSpawnL10n.format(
                    "%@ venceu %@. %@ perdeu %lld HP.",
                    playerMove.displayName,
                    enemyMove.displayName,
                    state.enemyCard.displayName,
                    Int64(state.playerCard.attackPower)
                )
            )
        }

        updatedState.lastRoundResult = .enemyWin
        updatedState.playerHP = max(
            0,
            updatedState.playerHP - state.enemyCard.attackPower
        )

        if updatedState.playerHP == 0 {
            updatedState.winner = .enemy
        } else {
            updatedState.round += 1
        }

        return BattleTurnResolution(
            state: updatedState,
            message: DeckSpawnL10n.format(
                "%@ venceu %@. %@ perdeu %lld HP.",
                enemyMove.displayName,
                playerMove.displayName,
                state.playerCard.displayName,
                Int64(state.enemyCard.attackPower)
            )
        )
    }
}
