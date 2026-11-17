import Foundation
import XCTest
@testable import CardArenaAR

final class MultiplayerBattleParityTests: XCTestCase {
    @MainActor
    func testWaitsForBothArenasAndMinimumDisplayTime() {
        var gate = MultiplayerRoundGate(round: 3)
        XCTAssertFalse(gate.mark(.hostFinished, round: 3))
        XCTAssertFalse(gate.mark(.resultDisplayed, round: 3))
        XCTAssertTrue(gate.mark(.guestFinished, round: 3))
        XCTAssertTrue(gate.didScheduleRecovery)
    }

    @MainActor
    func testGuestCanFinishFirstButCannotUnlockWithoutResult() {
        var gate = MultiplayerRoundGate(round: 1)
        XCTAssertFalse(gate.mark(.guestFinished, round: 1))
        XCTAssertFalse(gate.mark(.hostFinished, round: 1))
        XCTAssertTrue(gate.mark(.resultDisplayed, round: 1))
    }

    @MainActor
    func testOldOrDuplicateAcknowledgmentsAreIgnored() {
        var gate = MultiplayerRoundGate(round: 2)
        XCTAssertFalse(gate.mark(.guestFinished, round: 1))
        XCTAssertFalse(gate.guestFinished)
        XCTAssertFalse(gate.mark(.guestFinished, round: 2))
        XCTAssertFalse(gate.mark(.guestFinished, round: 2))
        XCTAssertFalse(gate.mark(.hostFinished, round: 2))
        XCTAssertTrue(gate.mark(.resultDisplayed, round: 2))
        XCTAssertFalse(gate.mark(.watchdog, round: 2))
    }

    @MainActor
    func testWatchdogBoundsWaitingWithoutSkippingResult() {
        var gate = MultiplayerRoundGate(round: 8)
        XCTAssertFalse(gate.mark(.watchdog, round: 8))
        XCTAssertTrue(gate.mark(.resultDisplayed, round: 8))
        XCTAssertFalse(gate.mark(.guestFinished, round: 8))
    }

    @MainActor
    func testDamageMirrorsLocalPerspectiveOnBothPhones() {
        let host = BattleDamage.between(playerBefore: 80, enemyBefore: 6,
                                        playerAfter: 80, enemyAfter: 0)
        let guest = BattleDamage.between(playerBefore: 6, enemyBefore: 80,
                                         playerAfter: 0, enemyAfter: 80)
        XCTAssertEqual(host, BattleDamage(target: .enemy, amount: 6))
        XCTAssertEqual(guest, BattleDamage(target: .player, amount: 6))
    }

    @MainActor
    func testDrawAndInvalidDoubleDamageHaveNoDamageNumber() {
        XCTAssertNil(BattleDamage.between(playerBefore: 80, enemyBefore: 70,
                                          playerAfter: 80, enemyAfter: 70))
        XCTAssertNil(BattleDamage.between(playerBefore: 80, enemyBefore: 70,
                                          playerAfter: 75, enemyAfter: 65))
    }

    @MainActor
    func testAnimationAcknowledgmentSurvivesWireFraming() throws {
        let wire = MultiplayerWireMessage(kind: MultiplayerWireKind.animationsFinished,
            playerState: nil, battleStart: nil, move: nil, roundStart: nil,
            roundResult: nil, animationsFinishedRound: 7)
        let frame = try MultiplayerFrame.encode(wire)
        let decoded = try JSONDecoder().decode(MultiplayerWireMessage.self, from: Data(frame.dropFirst(4)))
        XCTAssertEqual(decoded.kind, MultiplayerWireKind.animationsFinished)
        XCTAssertEqual(decoded.animationsFinishedRound, 7)
        XCTAssertNil(decoded.move)
    }

    @MainActor
    func testExistingWireDoesNotRequireAnimationAcknowledgment() throws {
        let wire = MultiplayerWireMessage(kind: MultiplayerWireKind.heartbeat,
            playerState: nil, battleStart: nil, move: nil, roundStart: nil, roundResult: nil)
        let data = try JSONEncoder().encode(wire)
        let decoded = try JSONDecoder().decode(MultiplayerWireMessage.self, from: data)
        XCTAssertNil(decoded.animationsFinishedRound)
    }
}
