import UIKit

/// Padrões de feedback tátil para eventos de jogo.
/// Usa a mesma preferência `hapticsEnabled` da tela de Configurações.
@MainActor
enum GameHaptics {

    private static var enabled: Bool {
        let stored = UserDefaults.standard.object(forKey: "hapticsEnabled")
        return (stored as? Bool) ?? true
    }

    static func selectedMove(_ move: BattleMove) {
        guard enabled else { return }
        switch move {
        case .impact:
            impact(.medium)
        case .technique:
            impact(.light)
            after(0.12) { impact(.light) }
        case .defense:
            impact(.rigid)
        }
    }

    static func timeWarning(secondsRemaining: Int) {
        guard enabled else { return }
        switch secondsRemaining {
        case 3:
            UISelectionFeedbackGenerator().selectionChanged()
        case 1:
            impact(.light)
        default:
            break
        }
    }

    static func timeExpired() {
        notification(.warning)
    }

    static func roundResult(_ result: BattleRoundResult, winner: BattleWinner?) {
        guard enabled else { return }

        if let winner {
            switch winner {
            case .player:
                notification(.success)
                after(0.22) { impact(.medium) }
            case .enemy:
                notification(.error)
            }
            return
        }

        switch result {
        case .playerWin:
            impact(.medium)
        case .enemyWin:
            impact(.heavy)
        case .draw:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static func notification(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(kind)
    }

    private static func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard enabled else { return }
            action()
        }
    }
}
