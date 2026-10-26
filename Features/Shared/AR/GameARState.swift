import SwiftUI
import Combine

enum CardScanPhase: Equatable {
    case searching
    case aligning
    case holding
    case scanning
    case confirmed
    case summoning
    case lost
    case failed
    case active
    case removing
    case waitingForCardRemoval
    case enemySummoning
    case battleReady
}

final class GameARState: ObservableObject {

    @Published var phase: CardScanPhase = .searching
    @Published var holdProgress: CGFloat = 0
    @Published var scanProgress: CGFloat = 0
    @Published var scanSecondsRemaining: Double = 0
    @Published var recognizedCardName: String?
    @Published var activeCard: CardDefinition?

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                soundEnabled,
                forKey: "soundEnabled"
            )
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                hapticsEnabled,
                forKey: "hapticsEnabled"
            )
        }
    }

    // Identifica qual tela AR pode receber/enviar callbacks nesta sessao.
    private var activeARCoordinatorID: UUID?

    func attachARCoordinator(_ id: UUID) {
        activeARCoordinatorID = id
    }

    func isCurrentARCoordinator(_ id: UUID) -> Bool {
        activeARCoordinatorID == id
    }

    func detachARCoordinator(_ id: UUID) {
        // Uma tela antiga nao pode remover handlers da nova.
        guard activeARCoordinatorID == id else { return }
        activeARCoordinatorID = nil
        onRemoveCharacter = nil
        onPrepareBattle = nil
        onBattleTurnAnimation = nil
    }

    // Impede reproducoes duplicadas caso o encerramento seja recebido duas vezes.
    private var finalBattleAudioHandled = false

    var onRemoveCharacter: (() -> Void)?
    var onPrepareBattle: ((CardDefinition) -> Void)?

    var onBattleTurnAnimation:
        ((
            BattleMove,
            BattleMove,
            BattleRoundResult,
            BattleWinner?
        ) -> Void)?

    init() {
        if UserDefaults.standard.object(
            forKey: "soundEnabled"
        ) == nil {
            soundEnabled = true
        } else {
            soundEnabled = UserDefaults.standard.bool(
                forKey: "soundEnabled"
            )
        }

        if UserDefaults.standard.object(
            forKey: "hapticsEnabled"
        ) == nil {
            hapticsEnabled = true
        } else {
            hapticsEnabled = UserDefaults.standard.bool(
                forKey: "hapticsEnabled"
            )
        }
    }

    func removeCharacter() {
        guard phase == .active else { return }

        phase = .removing
        onRemoveCharacter?()
    }

    func prepareBattle(
        against enemy: CardDefinition
    ) {
        guard phase == .active else { return }

        finalBattleAudioHandled = false
        SoundManager.shared.stopBattleResult()
        phase = .enemySummoning
        onPrepareBattle?(enemy)
    }

    /// Recebe o resultado FINAL, ja convertido para a perspectiva do iPhone local.
    /// Para multiplayer, calcule `didWin` comparando o ID do vencedor com o ID local.
    /// Chame na thread principal, como as demais atualizacoes de estado de SwiftUI.
    func announceLocalBattleResult(didWin: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.announceLocalBattleResult(didWin: didWin)
            }
            return
        }

        guard !finalBattleAudioHandled else { return }
        finalBattleAudioHandled = true
        SoundManager.shared.playBattleResult(
            didWin: didWin,
            enabled: soundEnabled
        )
    }

    func animateBattleTurn(
        playerMove: BattleMove,
        enemyMove: BattleMove,
        result: BattleRoundResult,
        winner: BattleWinner?
    ) {
        // BattleWinner e relativo a este aparelho: player = personagem local.
        // O som nao depende de o Coordinator AR ainda existir.
        if let winner {
            announceLocalBattleResult(didWin: winner == .player)
        }

        onBattleTurnAnimation?(
            playerMove,
            enemyMove,
            result,
            winner
        )
    }

    func resetForNewSession() {
        activeARCoordinatorID = nil
        finalBattleAudioHandled = false
        SoundManager.shared.stopBattleResult()
        phase = .searching
        holdProgress = 0
        scanProgress = 0
        scanSecondsRemaining = 0
        recognizedCardName = nil
        activeCard = nil
        onRemoveCharacter = nil
        onPrepareBattle = nil
        onBattleTurnAnimation = nil
    }
}

enum ScanLayout {

    static func guideRect(
        in size: CGSize
    ) -> CGRect {

        let width = min(
            size.width * 0.52,
            210
        )

        let height = width * 1.40

        let centerX = size.width / 2
        let centerY = size.height * 0.68

        return CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }
}
