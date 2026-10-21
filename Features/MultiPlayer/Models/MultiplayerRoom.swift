import Foundation
import Network

enum RoomPrivacy: String, Codable, CaseIterable, Identifiable {
    case open
    case privateRoom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return DeckSpawnL10n.text("Aberta")
        case .privateRoom: return DeckSpawnL10n.text("Privada")
        }
    }

    var systemImage: String {
        switch self {
        case .open: return "lock.open.fill"
        case .privateRoom: return "lock.fill"
        }
    }
}

struct HostedRoom: Equatable {
    let id: String
    let name: String
    let privacy: RoomPrivacy
    let joinCode: String?
}

struct DiscoveredRoom: Identifiable {
    let id: String
    let name: String
    let privacy: RoomPrivacy
    let endpoint: NWEndpoint
}

enum MultiplayerConnectionState: Equatable {
    case idle
    case hosting
    case browsing
    case connecting
    case connected
    case failed(String)
}

enum MultiplayerBattlePhase: Equatable {
    case waitingForArena
    case countdown
    case choosingMove
    case showingResult
    case finished
}

enum MultiplayerWinner: Equatable {
    case host
    case guest
}

nonisolated struct JoinRequest: Codable, Sendable {
    let roomID: String
    let code: String?
}

nonisolated struct JoinResponse: Codable, Sendable {
    let accepted: Bool
    let message: String
}

nonisolated struct MultiplayerPlayerStateMessage: Codable, Sendable {
    let cardID: String?
    let ready: Bool
    let arenaReady: Bool
}

nonisolated struct MultiplayerBattleStartMessage: Codable, Sendable {
    let hostCardID: String
    let guestCardID: String
    let hostHP: Int
    let guestHP: Int
    let countdownStartsAt: Double
    let countdownSeconds: Int
    let turnDurationSeconds: Int
}

nonisolated struct MultiplayerMoveMessage: Codable, Sendable {
    let round: Int
    let moveRawValue: String
}

nonisolated struct MultiplayerRoundStartMessage: Codable, Sendable {
    let round: Int
    let startsAt: Double
    let turnDurationSeconds: Int
}

nonisolated struct MultiplayerRoundResultMessage: Codable, Sendable {
    let round: Int
    let hostMoveRawValue: String
    let guestMoveRawValue: String
    let hostHP: Int
    let guestHP: Int
    let nextRound: Int
    let winner: String?
    let message: String

    // Optional for compatibility with older messages/clients.
    let hostWasAutomatic: Bool?
    let guestWasAutomatic: Bool?

    // Defaults avoid breaking any other creation sites in the project.
    init(
        round: Int,
        hostMoveRawValue: String,
        guestMoveRawValue: String,
        hostHP: Int,
        guestHP: Int,
        nextRound: Int,
        winner: String?,
        message: String,
        hostWasAutomatic: Bool? = nil,
        guestWasAutomatic: Bool? = nil
    ) {
        self.round = round
        self.hostMoveRawValue = hostMoveRawValue
        self.guestMoveRawValue = guestMoveRawValue
        self.hostHP = hostHP
        self.guestHP = guestHP
        self.nextRound = nextRound
        self.winner = winner
        self.message = message
        self.hostWasAutomatic = hostWasAutomatic
        self.guestWasAutomatic = guestWasAutomatic
    }
}

nonisolated struct MultiplayerWireMessage: Codable, Sendable {
    let kind: String
    let playerState: MultiplayerPlayerStateMessage?
    let battleStart: MultiplayerBattleStartMessage?
    let move: MultiplayerMoveMessage?
    let roundStart: MultiplayerRoundStartMessage?
    let roundResult: MultiplayerRoundResultMessage?
}

nonisolated enum MultiplayerWireKind {
    static let playerState = "playerState"
    static let battleStart = "battleStart"
    static let submitMove = "submitMove"
    static let roundStart = "roundStart"
    static let roundResult = "roundResult"
}
