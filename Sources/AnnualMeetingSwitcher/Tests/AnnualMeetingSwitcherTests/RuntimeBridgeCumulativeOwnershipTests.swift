import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeCumulativeOwnershipTests: XCTestCase {
    func testRecordingOnlyOwnsNoDomains() {
        XCTAssertEqual(LiveRuntimeBridgeMode.recordingOnly.ownedDomains, [])
    }

    func testAudioOwnedOwnsOnlyAudio() {
        XCTAssertEqual(LiveRuntimeBridgeMode.audioOwned.ownedDomains, [.audio])
    }

    func testMediaOwnedOwnsAudioAndMedia() {
        XCTAssertEqual(LiveRuntimeBridgeMode.mediaOwned.ownedDomains, [.audio, .media])
    }

    func testBGMOwningModeOwnsAudioMediaAndBGM() {
        XCTAssertEqual(LiveRuntimeBridgeMode.bgmOwned.ownedDomains, [.audio, .media, .bgm])
    }

    func testProjectionOwningModeOwnsAudioMediaBGMAndProjection() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.projectionOwned.ownedDomains,
            [.audio, .media, .bgm, .projection]
        )
    }

    func testFullRuntimeOwnsAllDomains() {
        XCTAssertEqual(LiveRuntimeBridgeMode.fullRuntime.ownedDomains, Set(LiveRuntimeDomain.allCases))
    }

    func testBGMOwningModeDoesNotOwnProjectionPPTAutomationSupport() {
        let mode = LiveRuntimeBridgeMode.bgmOwned

        XCTAssertFalse(mode.owns(.projection))
        XCTAssertFalse(mode.owns(.ppt))
        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.support))
    }

    func testProjectionOwningModeDoesNotOwnPPTAutomationSupport() {
        let mode = LiveRuntimeBridgeMode.projectionOwned

        XCTAssertFalse(mode.owns(.ppt))
        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.support))
    }
}
