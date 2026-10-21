import Foundation

enum CharacterAnimationKind: CaseIterable, Hashable {
    case idle
    case impact
    case technique
    case defense
    case hit
    case victory
    case defeat
}

enum CharacterAnimationSource: Hashable {
    case embedded
    case file(String)
    case firstAvailable([String])
}

struct CharacterAnimationSet: Hashable {

    let idle: CharacterAnimationSource?
    let impact: CharacterAnimationSource?
    let technique: CharacterAnimationSource?
    let defense: CharacterAnimationSource?
    let hit: CharacterAnimationSource?
    let victory: CharacterAnimationSource?
    let defeat: CharacterAnimationSource?

    subscript(
        kind: CharacterAnimationKind
    ) -> CharacterAnimationSource? {

        switch kind {
        case .idle:
            return idle

        case .impact:
            return impact

        case .technique:
            return technique

        case .defense:
            return defense

        case .hit:
            return hit

        case .victory:
            return victory

        case .defeat:
            return defeat
        }
    }

    static func standard(
        prefix: String
    ) -> CharacterAnimationSet {

        CharacterAnimationSet(
            idle: .embedded,
            impact: .file(
                "\(prefix)_Impact.usdz"
            ),
            technique: .firstAvailable([
                "\(prefix)_Technique.usdz",
                "\(prefix)_Tecnic.usdz"
            ]),
            defense: .firstAvailable([
                "\(prefix)_Guard.usdz",
                "\(prefix)_Defense.usdz"
            ]),
            hit: .file(
                "\(prefix)_Hit.usdz"
            ),
            victory: .file(
                "\(prefix)_Victory.usdz"
            ),
            defeat: .firstAvailable([
                "\(prefix)_Death.usdz",
                "\(prefix)_Defeat.usdz"
            ])
        )
    }
}
