import Foundation
import Combine

enum AppScreen {
    case mainMenu
    case singlePlayerSetup
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
    @Published private(set) var selectedDifficulty: AIDifficulty

    private let preferences: UserDefaults
    private var cpuAI = SinglePlayerAI()
    // The move is selected at the START of each round, before player input.
    private(set) var committedCPUMove: BattleMove?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        self.selectedDifficulty = AIDifficulty(
            rawValue: preferences.string(forKey: AIDifficulty.preferenceKey) ?? ""
        ) ?? .normal
    }

    func openSinglePlayerSetup() {
        resetBattleClocks()
        screen = .singlePlayerSetup
    }

    func startSinglePlayer(difficulty: AIDifficulty) {
        selectedDifficulty = difficulty
        preferences.set(difficulty.rawValue, forKey: AIDifficulty.preferenceKey)
        startSinglePlayer()
    }

    @Published var playerCard: CardDefinition?
    @Published var enemyCard: CardDefinition?
    @Published var battleState: BattleState?
    @Published var isResolvingTurn = false
    @Published var lastTurnMessage: String?

    @Published var battleCountdown: Int?
    @Published private(set) var isShowingVersus = false
    @Published var isBattleStarted = false
    @Published var turnSecondsRemaining = BattleRules.turnDurationSeconds

    var onBattleTurnResolved: ((BattleMove, BattleMove, BattleRoundResult, BattleWinner?, BattleDamage?) -> Void)?

    private var countdownGeneration = 0
    private var turnGeneration = 0
    // Invalida resoluções atrasadas quando a batalha ou a tela muda.
    private var battleGeneration = 0
    // The VS intro must never outlive its battle.
    private var versusGeneration = 0
    private let versusDuration: TimeInterval = 2.5

    func startSinglePlayer() {
        resetBattleClocks()
        playerCard = nil
        enemyCard = nil
        battleState = nil
        lastTurnMessage = nil
        isResolvingTurn = false
        battleCountdown = nil
        isShowingVersus = false
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
        isShowingVersus = false
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
        isShowingVersus = false
        isBattleStarted = false
        singlePlayerPhase = .summoningEnemy
        return enemy
    }

    func enemySummonDidFail() {
        guard screen == .singlePlayer,
              singlePlayerPhase == .summoningEnemy else { return }
        resetBattleClocks()
        playerCard = nil
        enemyCard = nil
        battleState = nil
        lastTurnMessage = nil
        isResolvingTurn = false
        battleCountdown = nil
        isShowingVersus = false
        isBattleStarted = false
        turnSecondsRemaining = BattleRules.turnDurationSeconds
        singlePlayerPhase = .choosingCard
    }

    func enemySummonDidFinish() {
        guard let playerCard, let enemyCard else { return }
        battleState = BattleState.newBattle(player: playerCard, enemy: enemyCard)
        singlePlayerPhase = .battleReady
        startVersusIntro()
    }

    /// Starts a new duel using the same cards and the existing AR scene.
    /// The caller must first verify/reset the RealityKit scene with GameARState.
    @discardableResult
    func restartBattleWithSameCharacters() -> Bool {
        guard screen == .singlePlayer,
              singlePlayerPhase == .battleReady,
              battleState?.winner != nil,
              let playerCard, let enemyCard else { return false }

        // Invalidate delayed turn results, countdowns and old VS callbacks.
        resetBattleClocks()
        battleState = BattleState.newBattle(player: playerCard, enemy: enemyCard)
        lastTurnMessage = nil
        isResolvingTurn = false
        isBattleStarted = false
        battleCountdown = nil
        turnSecondsRemaining = BattleRules.turnDurationSeconds
        startVersusIntro()
        return true
    }

    private func startVersusIntro() {
        guard screen == .singlePlayer, battleState != nil else { return }
        versusGeneration += 1
        let generation = versusGeneration
        isShowingVersus = true
        isBattleStarted = false
        battleCountdown = nil
        lastTurnMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + versusDuration) { [weak self] in
            guard let self,
                  self.versusGeneration == generation,
                  self.screen == .singlePlayer,
                  self.singlePlayerPhase == .battleReady,
                  self.battleState != nil else { return }
            self.isShowingVersus = false
            self.startBattleCountdown()
        }
    }

    func playTurn(playerMove: BattleMove) {
        resolvePlayerTurn(playerMove, automatic: false)
    }

    private func resolvePlayerTurn(_ playerMove: BattleMove, automatic: Bool) {
        guard isBattleStarted,
              !isResolvingTurn,
              let battleState,
              battleState.winner == nil else { return }

        // Precommitted at the beginning of the round: the CPU never sees
        // the player's current choice before deciding its own.
        guard let enemyMove = committedCPUMove else { return }
        committedCPUMove = nil

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
                "Você escolheu %@. Revelando ações...",
                playerMove.displayName
            )
        }

        let currentState = battleState
        let generation = battleGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { [weak self] in
            guard let self, self.battleGeneration == generation else { return }
            let resolution = BattleEngine.resolveTurn(
                state: currentState,
                playerMove: playerMove,
                enemyMove: enemyMove
            )
            self.battleState = resolution.state
            self.lastTurnMessage = resolution.message
            // Update the predictor only after the round actually finishes.
            self.cpuAI.recordCompletedPlayerMove(playerMove)

            if let roundResult = resolution.state.lastRoundResult {
                GameHaptics.roundResult(roundResult, winner: resolution.state.winner)
                self.onBattleTurnResolved?(
                    playerMove,
                    enemyMove,
                    roundResult,
                    resolution.state.winner,
                    BattleDamage.between(before: currentState, after: resolution.state)
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
                guard let self, self.battleGeneration == generation else { return }
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
        // Commit before enabling the next player action / timeout timer.
        committedCPUMove = cpuAI.chooseMove(difficulty: selectedDifficulty)
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
        versusGeneration += 1
        isShowingVersus = false
        countdownGeneration += 1
        turnGeneration += 1
        battleGeneration += 1
        cpuAI.reset()
        committedCPUMove = nil
    }
}
