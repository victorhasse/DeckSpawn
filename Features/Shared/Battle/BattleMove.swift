import Foundation

enum BattleMove: String, CaseIterable, Identifiable {
    case impact
    case technique
    case defense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .impact: return DeckSpawnL10n.text("IMPACTO")
        case .technique: return DeckSpawnL10n.text("TÉCNICA")
        case .defense: return DeckSpawnL10n.text("GUARDA")
        }
    }

    var systemImage: String {
        switch self {
        case .impact: return "burst.fill"
        case .technique: return "sparkles"
        case .defense: return "shield.fill"
        }
    }

    func beats(_ other: BattleMove) -> Bool {
        switch (self, other) {
        case (.impact, .technique),
             (.technique, .defense),
             (.defense, .impact):
            return true
        default:
            return false
        }
    }
}
