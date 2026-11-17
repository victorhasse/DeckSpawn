import Foundation

/// Identifies the exact pair of cards for which the local AR scene was prepared.
nonisolated struct MultiplayerArenaSelection: Equatable, Hashable, Sendable {
    let localCardID: String
    let remoteCardID: String
}

nonisolated enum MultiplayerArenaAction: Equatable, Sendable {
    case wait
    case prepare(MultiplayerArenaSelection)
    case announceReady
    case abort
}

nonisolated enum MultiplayerArenaGate {
    static func next(
        selection: MultiplayerArenaSelection?,
        requested: MultiplayerArenaSelection?,
        localCharacterActive: Bool,
        localCharacterMatches: Bool,
        arReady: Bool,
        announcedReady: Bool,
        connected: Bool
    ) -> MultiplayerArenaAction {
        guard connected else { return .abort }
        if let requested {
            guard selection == requested, localCharacterMatches else { return .abort }
            return arReady && !announcedReady ? .announceReady : .wait
        }
        guard let selection, localCharacterActive, localCharacterMatches else { return .wait }
        return .prepare(selection)
    }
}
