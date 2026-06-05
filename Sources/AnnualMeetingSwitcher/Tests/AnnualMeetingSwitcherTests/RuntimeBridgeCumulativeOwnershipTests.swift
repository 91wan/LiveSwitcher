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

    func testPPTOwnedModeOwnsAudioMediaBGMProjectionAndPPT() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.pptOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt]
        )
    }

    func testAutomationNoticeOwnedModeOwnsPriorDomainsAndAutomationNotice() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.automationNoticeOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice]
        )
    }

    func testSupportOwnedModeOwnsPriorDomainsAndSupport() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.supportOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support]
        )
    }

    func testAutomationCommandOwnedModeOwnsPriorDomainsAndAutomationCommand() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.automationCommandOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand]
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

    func testPPTOwnedModeDoesNotOwnAutomationOrSupport() {
        let mode = LiveRuntimeBridgeMode.pptOwned

        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.support))
    }

    func testAutomationNoticeOwnedModeDoesNotOwnAutomationExecutionOrSupport() {
        let mode = LiveRuntimeBridgeMode.automationNoticeOwned

        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.support))
    }

    func testSupportOwnedModeDoesNotOwnAutomationExecution() {
        let mode = LiveRuntimeBridgeMode.supportOwned

        XCTAssertFalse(mode.owns(.automation))
        XCTAssertFalse(mode.owns(.automationCommand))
    }

    func testAutomationCommandOwnedModeOwnsCommandButNotFullAutomation() {
        let mode = LiveRuntimeBridgeMode.automationCommandOwned

        XCTAssertTrue(mode.owns(.automationCommand))
        XCTAssertFalse(mode.owns(.automation))
    }
}
