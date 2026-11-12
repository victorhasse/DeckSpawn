import XCTest
@testable import CardArenaAR

final class SpiderManVFXTimingTests: XCTestCase {
    func testWebLaunchConnectAndRetractAreOrdered() {
        let timing = SpiderManVFXTiming(clipDuration: 2)
        XCTAssertLessThan(timing.webLaunchAt, timing.webConnectAt)
        XCTAssertLessThan(timing.webConnectAt, timing.webRetractAt)
        XCTAssertLessThan(timing.webRetractAt, timing.webEndAt)
        XCTAssertLessThan(timing.webEndAt, 2)
    }

    func testWebStartsAtWristReachesTargetAndRetracts() {
        let timing = SpiderManVFXTiming(clipDuration: 2)
        XCTAssertEqual(timing.webExtension(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(timing.webExtension(at: timing.webLaunchAt), 0, accuracy: 0.0001)
        XCTAssertEqual(timing.webExtension(at: timing.webConnectAt), 1, accuracy: 0.0001)
        XCTAssertEqual(timing.webExtension(at: timing.webRetractAt), 1, accuracy: 0.0001)
        XCTAssertEqual(timing.webExtension(at: timing.webEndAt), 0, accuracy: 0.0001)
    }

    func testWebProgressDoesNotOvershoot() {
        let timing = SpiderManVFXTiming(clipDuration: 1.1)
        for i in 0...100 {
            let fraction = timing.webExtension(at: Double(i) / 100 * 1.1)
            XCTAssertGreaterThanOrEqual(fraction, 0)
            XCTAssertLessThanOrEqual(fraction, 1)
        }
    }

    func testKickAccentIsInsideKickWindow() {
        let timing = SpiderManVFXTiming(clipDuration: 1.6)
        XCTAssertLessThan(timing.kickStartAt, timing.kickArcAt)
        XCTAssertLessThan(timing.kickArcAt, timing.kickSecondArcAt)
        XCTAssertLessThan(timing.kickSecondArcAt, timing.kickEndAt)
        XCTAssertLessThan(timing.kickEndAt, 1.6)
    }

    func testKickAccentsStayVisibleForShortClips() {
        let timing = SpiderManVFXTiming(clipDuration: 0.35)
        XCTAssertGreaterThan(timing.kickSecondArcAt, timing.kickArcAt)
        XCTAssertLessThan(timing.kickEndAt, timing.clipDuration)
        XCTAssertGreaterThan(timing.kickEndAt + 0.43, timing.clipDuration)
    }

    func testShortClipUsesMinimumSafeDuration() {
        let timing = SpiderManVFXTiming(clipDuration: 0.05)
        XCTAssertGreaterThanOrEqual(timing.webEndAt, 0.25)
        XCTAssertGreaterThan(timing.kickEndAt, timing.kickArcAt)
    }
}
