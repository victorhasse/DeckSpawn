import Foundation

enum CardDatabase {

    static let all: [CardDefinition] = [

        CardDefinition(
            referenceImageName: "spiderman_cardgame",
            displayName: "Spiderman",
            modelName: "Spiderman_Idle.usdz",
            collectionDescription: "Herói ágil que usa reflexos e movimentos acrobáticos para superar os adversários.",
            modelHeight: 0.60,
            yawOffset: 0,
            maxHP: 100,
            attackPower: 25,
            animations: .standard(
                prefix: "Spiderman"
            )
        ),

        CardDefinition(
            referenceImageName: "stormtrooper_cardgame",
            displayName: "Stormtrooper",
            modelName: "Stormtrooper_Idle.usdz",
            collectionDescription: "Soldado de armadura branca, preparado para enfrentar desafios com disciplina.",
            modelHeight: 0.60,
            yawOffset: 0,
            maxHP: 100,
            attackPower: 25,
            animations: .standard(
                prefix: "Stormtrooper"
            )
        ),
        
        CardDefinition(
            referenceImageName: "goku_cardgame",
            displayName: "Goku",
            modelName: "Goku_Idle.usdz",
            collectionDescription: "Guerreiro determinado que está sempre em busca de superar seus próprios limites.",
            modelHeight: 0.60,
            yawOffset: 0,
            maxHP: 100,
            attackPower: 25,
            animations: .standard(
                prefix: "Goku"
            )
        ),
        
        CardDefinition(
            referenceImageName: "mrsincredible_cardgame",
            displayName: "Mrs. Incredible",
            modelName: "MrsIncredible_Idle.usdz",
            collectionDescription: "Heroína versátil que combina elasticidade, coragem e criatividade nas batalhas.",
            modelHeight: 0.55,
            yawOffset: 0,
            maxHP: 100,
            attackPower: 25,
            animations: .standard(
                prefix: "MrsIncredible"
            )
        )
    ]

    private static let cardsByReferenceImageName:
        [String: CardDefinition] = {

            Dictionary(
                uniqueKeysWithValues:
                    all.map {
                        (
                            $0.referenceImageName,
                            $0
                        )
                    }
            )
        }()

    static func card(
        named referenceImageName: String
    ) -> CardDefinition? {

        cardsByReferenceImageName[
            referenceImageName
        ]
    }
}
