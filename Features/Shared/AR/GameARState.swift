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

enum BattlePreparationFailure: Equatable {
    case arenaUnavailable
    case enemyModelUnavailable
}

struct BattlePreparationFailureEvent: Equatable {
    // Cada tentativa possui seu proprio ID, mesmo se falhar pelo mesmo motivo.
    let id = UUID()
    let failure: BattlePreparationFailure
}

/// One visible number above one fighter; the position is updated while the
/// camera moves, without changing the underlying battle state.
struct FloatingDamageEvent: Identifiable {
    let id: UUID
    let amount: Int
    var screenPoint: CGPoint?
}

final class GameARState: ObservableObject {

    @Published private(set) var floatingDamageEvent: FloatingDamageEvent?

    func showFloatingDamage(id: UUID, amount: Int, at point: CGPoint?) {
        guard amount > 0 else { return }
        floatingDamageEvent = FloatingDamageEvent(id: id, amount: amount, screenPoint: point)
    }

    func updateFloatingDamagePosition(_ point: CGPoint?, id: UUID) {
        guard floatingDamageEvent?.id == id else { return }
        floatingDamageEvent?.screenPoint = point
    }

    func clearFloatingDamage(id: UUID? = nil) {
        guard id == nil || floatingDamageEvent?.id == id else { return }
        floatingDamageEvent = nil
    }

    @Published var phase: CardScanPhase = .searching
    @Published var holdProgress: CGFloat = 0
    @Published var scanProgress: CGFloat = 0
    @Published var scanSecondsRemaining: Double = 0
    @Published var recognizedCardName: String?
    @Published var activeCard: CardDefinition?
    // Uma mudanca observavel especifica evita perder falhas sincrona na RA.
    @Published private(set) var battlePreparationFailureEvent: BattlePreparationFailureEvent?

    func reportBattlePreparationFailure(_ failure: BattlePreparationFailure) {
        battlePreparationFailureEvent = BattlePreparationFailureEvent(failure: failure)
    }

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
        onPrepareRematch = nil
        onBattleTurnAnimation = nil
        clearFloatingDamage()
    }

    // Impede reproducoes duplicadas caso o encerramento seja recebido duas vezes.
    private var finalBattleAudioHandled = false

    var onRemoveCharacter: (() -> Void)?
    var onPrepareBattle: ((CardDefinition) -> Void)?
    /// Reset the existing AR combatants to Idle without scanning/loading again.
    /// Returns false if the scene or tracking can no longer be reused.
    var onPrepareRematch: (() -> Bool)?

    var onBattleTurnAnimation:
        ((
            BattleMove,
            BattleMove,
            BattleRoundResult,
            BattleWinner?,
            BattleDamage?
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
        battlePreparationFailureEvent = nil
        SoundManager.shared.stopBattleResult()
        guard let onPrepareBattle else {
            phase = .active
            reportBattlePreparationFailure(.arenaUnavailable)
            return
        }
        phase = .enemySummoning
        onPrepareBattle(enemy)
    }

    /// Called only after a finished duel and before resetting the battle model.
    /// A failed preparation leaves the finished battle intact.
    @discardableResult
    func prepareRematch() -> Bool {
        guard phase == .battleReady,
              let onPrepareRematch,
              onPrepareRematch() else { return false }
        // Stop the previous victory/defeat sound and permit the next result.
        SoundManager.shared.stopBattleResult()
        finalBattleAudioHandled = false
        clearFloatingDamage()
        return true
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
        winner: BattleWinner?,
        damage: BattleDamage? = nil
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
            winner,
            damage
        )
    }

    func resetForNewSession() {
        clearFloatingDamage()
        activeARCoordinatorID = nil
        finalBattleAudioHandled = false
        SoundManager.shared.stopBattleResult()
        phase = .searching
        holdProgress = 0
        scanProgress = 0
        scanSecondsRemaining = 0
        recognizedCardName = nil
        activeCard = nil
        battlePreparationFailureEvent = nil
        onRemoveCharacter = nil
        onPrepareBattle = nil
        onPrepareRematch = nil
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
