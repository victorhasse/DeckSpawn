import XCTest
@testable import CardArenaAR

final class CardDatabaseTests: XCTestCase {

    func testRegisteredCharactersAreUniqueAndRetrievable() {
        let cards = CardDatabase.all
        XCTAssertGreaterThanOrEqual(cards.count, 4) // baseline, allows expanding the roster
        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
        for card in cards {
            XCTAssertEqual(CardDatabase.card(named: card.referenceImageName), card)
            XCTAssertFalse(card.displayName.isEmpty)
            XCTAssertFalse(card.collectionDescription.isEmpty)
        }
    }

    func testUnknownCardReturnsNil() {
        XCTAssertNil(CardDatabase.card(named: "not_a_real_card"))
    }

    func testEveryCharacterHasValidStatsAndAnimationDefinitions() {
        for card in CardDatabase.all {
            XCTAssertGreaterThan(card.maxHP, 0, card.displayName)
            XCTAssertGreaterThan(card.attackPower, 0, card.displayName)
            XCTAssertGreaterThan(card.modelHeight, 0, card.displayName)
            XCTAssertTrue(card.modelName.hasSuffix(".usdz"), card.displayName)
            XCTAssertNotNil(card.animations, card.displayName)
        }
    }

    func testAllRegisteredCardsCanStartABattle() {
        for player in CardDatabase.all {
            for enemy in CardDatabase.all where enemy.id != player.id {
                let battle = BattleState.newBattle(player: player, enemy: enemy)
                XCTAssertEqual(battle.playerHP, player.maxHP)
                XCTAssertEqual(battle.enemyHP, enemy.maxHP)
                XCTAssertNil(battle.winner)
            }
        }
    }
}
