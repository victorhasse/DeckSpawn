import Foundation

/// Host-side barrier: the result must be visible and both arenas must finish
/// before the next round. A watchdog bounds the wait if AR loses a callback.
struct MultiplayerRoundGate {
    let round: Int
    private(set) var resultDisplayed = false
    private(set) var hostFinished = false
    private(set) var guestFinished = false
    private(set) var didScheduleRecovery = false

    enum Event { case resultDisplayed, hostFinished, guestFinished, watchdog }

    mutating func mark(_ event: Event, round: Int) -> Bool {
        guard self.round == round, !didScheduleRecovery else { return false }
        switch event {
        case .resultDisplayed: resultDisplayed = true
        case .hostFinished: hostFinished = true
        case .guestFinished: guestFinished = true
        case .watchdog: hostFinished = true; guestFinished = true
        }
        guard resultDisplayed, hostFinished, guestFinished else { return false }
        didScheduleRecovery = true
        return true
    }
}
