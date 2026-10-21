import Foundation
import Combine

enum AppScreen {
    case mainMenu
    case singlePlayer
    case multiplayer
}

enum SinglePlayerPhase {
    case choosingCard
    case summoningEnemy
    case battleReady
}

@MainActor
final class GameFlowState: ObservableObject {
    @Published var screen: AppScreen = .mainMenu
    @Published var singlePlayerPhase: SinglePlayerPhase = .choosingCard

    @Published var playerCard: CardDefinition?
    @Published var enemyCard: CardDefinition?
    @Published var battleState: BattleState?
    @Published var isResolvingTurn = false
    @Published var lastTurnMessage: String?

    @Published var battleCountdown: Int?
    @Published var isBattleStarted = false
    @Published var turnSecondsRemaining = BattleRules.turnDurationSeconds

    var onBattleTurnResolved: ((BattleMove, BattleMove, BattleRoundResult, BattleWinner?) -> Void)?

    private var countdownGeneration = 0
    private var turnGeneration = 0

    func startSinglePlayer() {
        resetBattleClocks()
        playerCard = nil
        enemyCard = nil
        battleState = nil
        lastTurnMessage = nil
        isResolvingTurn = false
        battleCountdown = nil
        isBattleStarted = false
        turnSecondsRemaining = BattleRules.turnDurationSeconds
        singlePlayerPhase = .choosingCard
        screen = .singlePlayer
    }

    func startMultiplayer() {
        resetBattleClocks()
        screen = .multiplayer
    }

    func returnToMainMenu() {
        resetBattleClocks()
        playerCard = nil
        enemyCard = nil
        battleState = nil
        lastTurnMessage = nil
        isResolvingTurn = false
        battleCountdown = nil
        isBattleStarted = false
        turnSecondsRemaining = BattleRules.turnDurationSeconds
        singlePlayerPhase = .choosingCard
        screen = .mainMenu
    }

    func confirmPlayerCard(_ card: CardDefinition) -> CardDefinition? {
        let possibleEnemies = CardDatabase.all.filter { $0.id != card.id }
        guard let enemy = possibleEnemies.randomElement() else { return nil }
        resetBattleClocks()
        playerCard = card
        enemyCard = enemy
        battleState = nil
        lastTurnMessage = nil
        isResolvingTurn = false
        battleCountdown = nil
        isBattleStarted = false
        singlePlayerPhase = .summoningEnemy
        return enemy
    }

    func enemySummonDidFinish() {
        guard let playerCard, let enemyCard else { return }
        battleState = BattleState.newBattle(player: playerCard, enemy: enemyCard)
        singlePlayerPhase = .battleReady
        startBattleCountdown()
    }

    func playTurn(playerMove: BattleMove) {
        resolvePlayerTurn(playerMove, automatic: false)
    }

    private func resolvePlayerTurn(_ playerMove: BattleMove, automatic: Bool) {
        guard isBattleStarted,
              !isResolvingTurn,
              let battleState,
              battleState.winner == nil else { return }

        guard let enemyMove = BattleMove.allCases.randomElement() else { return }

        turnGeneration += 1
        isResolvingTurn = true

        if automatic {
            GameHaptics.timeExpired()
        } else {
            GameHaptics.selectedMove(playerMove)
        }

        if automatic {
            lastTurnMessage = DeckSpawnL10n.format(
                "Tempo esgotado. %@ foi escolhido automaticamente.",
                playerMove.displayName
            )
        } else {
            lastTurnMessage = DeckSpawnL10n.format(
                "Você escolheu %@. CPU está escolhendo...",
                playerMove.displayName
            )
        }

        let currentState = battleState
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { [weak self] in
            guard let self else { return }
            let resolution = BattleEngine.resolveTurn(
                state: currentState,
                playerMove: playerMove,
                enemyMove: enemyMove
            )
            self.battleState = resolution.state
            self.lastTurnMessage = resolution.message

            if let roundResult = resolution.state.lastRoundResult {
                GameHaptics.roundResult(roundResult, winner: resolution.state.winner)
                self.onBattleTurnResolved?(
                    playerMove,
                    enemyMove,
                    roundResult,
                    resolution.state.winner
                )
            }

            if resolution.state.winner != nil {
                self.isResolvingTurn = false
                self.isBattleStarted = false
                self.turnSecondsRemaining = 0
                self.turnGeneration += 1
                return
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + BattleRules.roundResultDisplaySeconds
            ) { [weak self] in
                guard let self else { return }
                self.isResolvingTurn = false
                self.lastTurnMessage = DeckSpawnL10n.text("Escolha sua próxima ação.")
                self.startTurnTimer()
            }
        }
    }

    private func startBattleCountdown() {
        countdownGeneration += 1
        let generation = countdownGeneration
        isBattleStarted = false
        battleCountdown = BattleRules.startCountdownSeconds
        runCountdown(
            remaining: BattleRules.startCountdownSeconds,
            generation: generation
        )
    }

    private func runCountdown(remaining: Int, generation: Int) {
        guard generation == countdownGeneration else { return }
        guard remaining > 0 else {
            battleCountdown = nil
            isBattleStarted = true
            lastTurnMessage = DeckSpawnL10n.text("Escolha sua primeira ação.")
            startTurnTimer()
            return
        }

        battleCountdown = remaining
        lastTurnMessage = DeckSpawnL10n.format(
            "A batalha começa em %lld...",
            Int64(remaining)
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.runCountdown(remaining: remaining - 1, generation: generation)
        }
    }

    private func startTurnTimer() {
        turnGeneration += 1
        let generation = turnGeneration
        turnSecondsRemaining = BattleRules.turnDurationSeconds
        runTurnTimer(remaining: BattleRules.turnDurationSeconds, generation: generation)
    }

    private func runTurnTimer(remaining: Int, generation: Int) {
        guard generation == turnGeneration,
              isBattleStarted,
              !isResolvingTurn,
              battleState?.winner == nil else { return }
        turnSecondsRemaining = max(remaining, 0)

        if remaining == 3 || remaining == 1 {
            GameHaptics.timeWarning(secondsRemaining: remaining)
        }

        guard remaining > 0 else {
            guard let automaticMove = BattleMove.allCases.randomElement() else { return }
            resolvePlayerTurn(automaticMove, automatic: true)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.runTurnTimer(remaining: remaining - 1, generation: generation)
        }
    }

    private func resetBattleClocks() {
        countdownGeneration += 1
        turnGeneration += 1
    }
}
