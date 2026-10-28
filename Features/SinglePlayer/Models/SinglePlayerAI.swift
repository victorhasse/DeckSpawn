import Foundation

/// Difficulty controls only the CPU's move selection; BattleEngine keeps all battle rules.
enum AIDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    static let preferenceKey = "deckspawn.singleplayer.difficulty"

    var id: String { rawValue }
}

/// Value-type CPU opponent. It only sees *completed* player moves.
/// The caller must commit the CPU move at the beginning of each round.
struct SinglePlayerAI {
    private(set) var playerHistory: [BattleMove] = []
    private(set) var previousCPUMove: BattleMove?

    // Configurable balance. A random part is always preserved on Hard.
    static let easyRepeatPercent = 75
    static let hardCounterPercent = 65
    static let historyWindow = 6

    mutating func reset() {
        playerHistory.removeAll()
        previousCPUMove = nil
    }

    mutating func recordCompletedPlayerMove(_ move: BattleMove) {
        playerHistory.append(move)
        if playerHistory.count > Self.historyWindow {
            playerHistory.removeFirst(playerHistory.count - Self.historyWindow)
        }
    }

    /// `pick` is injectable so tests can exercise probability branches deterministically.
    /// Its argument is an exclusive upper bound; return a value in 0..<upperBound.
    mutating func chooseMove(
        difficulty: AIDifficulty,
        pick: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> BattleMove {
        let moves = BattleMove.allCases
        func randomMove() -> BattleMove { moves[pick(moves.count)] }
        let choice: BattleMove

        switch difficulty {
        case .easy:
            if let previousCPUMove, pick(100) < Self.easyRepeatPercent {
                choice = previousCPUMove
            } else {
                choice = randomMove()
            }
        case .normal:
            choice = randomMove()
        case .hard:
            if playerHistory.count >= 2,
               let predicted = predictedPlayerMove(),
               pick(100) < Self.hardCounterPercent {
                // Only a *past* pattern is available; never inspect the current move.
                choice = moves.first(where: { $0.beats(predicted) }) ?? randomMove()
            } else {
                choice = randomMove()
            }
        }

        previousCPUMove = choice
        return choice
    }

    private func predictedPlayerMove() -> BattleMove? {
        guard let mostRecent = playerHistory.last else { return nil }
        // Highest frequency over the recent window. In ties, choose the latest
        // move among the tied candidates, keeping the prediction reproducible.
        let counts = BattleMove.allCases.map { move in
            (move, playerHistory.filter { $0 == move }.count)
        }
        guard let topCount = counts.map(\.1).max() else { return nil }
        let topMoves = counts.filter { $0.1 == topCount }.map(\.0)
        if topMoves.contains(mostRecent) { return mostRecent }
        return playerHistory.reversed().first(where: { topMoves.contains($0) })
    }
}
