import Foundation
import XCTest
@testable import CardArenaAR

final class MultiplayerPreparationTests: XCTestCase {
    private let match = MultiplayerArenaSelection(localCardID: "a", remoteCardID: "b")

    private func action(
        selection: MultiplayerArenaSelection?,
        requested: MultiplayerArenaSelection? = nil,
        active: Bool = true,
        matches: Bool = true,
        ready: Bool = false,
        announced: Bool = false,
        connected: Bool = true
    ) -> MultiplayerArenaAction {
        MultiplayerArenaGate.next(
            selection: selection,
            requested: requested,
            localCharacterActive: active,
            localCharacterMatches: matches,
            arReady: ready,
            announcedReady: announced,
            connected: connected
        )
    }

    func testWaitsForLocalARThenPrepares() {
        XCTAssertEqual(action(selection: match, active: false), .wait)
        XCTAssertEqual(action(selection: match), .prepare(match))
    }

    func testDoesNotPrepareBeforeBothPlayersConfirm() {
        XCTAssertEqual(action(selection: nil), .wait)
        XCTAssertEqual(action(selection: match, matches: false), .wait)
    }

    func testDoesNotRequestTheSameSummonTwice() {
        XCTAssertEqual(action(selection: match, requested: match, active: false), .wait)
    }

    func testArenaReadyIsAnnouncedOnlyOnce() {
        XCTAssertEqual(action(selection: match, requested: match, active: false, ready: true), .announceReady)
        XCTAssertEqual(action(selection: match, requested: match, active: false, ready: true, announced: true), .wait)
    }

    func testAbortsWhenOpponentCancelsOrChangesCard() {
        XCTAssertEqual(action(selection: nil, requested: match), .abort)
        let changed = MultiplayerArenaSelection(localCardID: "a", remoteCardID: "c")
        XCTAssertEqual(action(selection: changed, requested: match), .abort)
        XCTAssertEqual(action(selection: match, requested: match, matches: false), .abort)
    }

    func testDisconnectAbortsPreparation() {
        XCTAssertEqual(action(selection: match, requested: match, connected: false), .abort)
        XCTAssertEqual(action(selection: nil, connected: false), .abort)
    }

    func testFrameRoundTripAndLength() throws {
        let packet = try MultiplayerFrame.encode(["kind": "playerState"])
        let length = try XCTUnwrap(MultiplayerFrame.payloadLength(from: Data(packet.prefix(4))))
        XCTAssertEqual(length, packet.count - 4)
        let decoded = try JSONDecoder().decode([String: String].self, from: Data(packet.dropFirst(4)))
        XCTAssertEqual(decoded, ["kind": "playerState"])
    }

    func testConsecutiveFramesHaveIndependentBoundaries() throws {
        let first = try MultiplayerFrame.encode(["accepted": true])
        let second = try MultiplayerFrame.encode(["ready": true])
        let stream = first + second
        let length = try XCTUnwrap(MultiplayerFrame.payloadLength(from: Data(stream.prefix(4))))
        XCTAssertEqual(Data(stream.prefix(4 + length)), first)
        XCTAssertEqual(Data(stream.dropFirst(4 + length)), second)
    }

    func testRejectsInvalidFrameHeaders() {
        XCTAssertNil(MultiplayerFrame.payloadLength(from: Data([0, 0, 0])))
        XCTAssertNil(MultiplayerFrame.payloadLength(from: Data([0, 0, 0, 0])))
        XCTAssertNil(MultiplayerFrame.payloadLength(from: Data([0, 1, 0, 1])))
        XCTAssertNil(MultiplayerFrame.payloadLength(from: Data([255, 255, 255, 255])))
        XCTAssertEqual(MultiplayerFrame.payloadLength(from: Data([0, 1, 0, 0])), 65_536)
    }

    func testRejectsOversizedPayload() {
        XCTAssertThrowsError(try MultiplayerFrame.encode(String(repeating: "a", count: 65_537)))
    }
    func testHeartbeatWireRoundTrip() throws {
        let heartbeat = MultiplayerWireMessage(
            kind: MultiplayerWireKind.heartbeat, playerState: nil,
            battleStart: nil, move: nil, roundStart: nil, roundResult: nil
        )
        let frame = try MultiplayerFrame.encode(heartbeat)
        let decoded = try JSONDecoder().decode(MultiplayerWireMessage.self, from: Data(frame.dropFirst(4)))
        XCTAssertEqual(decoded.kind, MultiplayerWireKind.heartbeat)
        XCTAssertNil(decoded.playerState)
        XCTAssertNil(decoded.battleStart)
    }

    func testPeriodicPlayerStatesPreserveCardAndReady() throws {
        for (id, ready, arena) in [(nil as String?, false, false), ("goku_cardgame", false, false), ("goku_cardgame", true, false), ("goku_cardgame", true, true)] {
            let state = MultiplayerPlayerStateMessage(cardID: id, ready: ready, arenaReady: arena)
            let wire = MultiplayerWireMessage(kind: MultiplayerWireKind.playerState, playerState: state,
                battleStart: nil, move: nil, roundStart: nil, roundResult: nil)
            let frame = try MultiplayerFrame.encode(wire)
            XCTAssertEqual(MultiplayerFrame.payloadLength(from: Data(frame.prefix(4))), frame.count - 4)
            let decoded = try JSONDecoder().decode(MultiplayerWireMessage.self, from: Data(frame.dropFirst(4)))
            XCTAssertEqual(decoded.playerState?.cardID, id)
            XCTAssertEqual(decoded.playerState?.ready, ready)
            XCTAssertEqual(decoded.playerState?.arenaReady, arena)
        }
    }
}
