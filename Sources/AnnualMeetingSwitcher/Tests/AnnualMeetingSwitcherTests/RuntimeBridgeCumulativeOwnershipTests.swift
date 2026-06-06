import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeCumulativeOwnershipTests: XCTestCase {
    func testRecordingOnlyOwnsNoDomains() {
        XCTAssertEqual(LiveRuntimeBridgeMode.recordingOnly.ownedDomains, [])
    }

    func testAudioOwnedOwnsOnlyAudioAndInfrastructure() {
        XCTAssertEqual(LiveRuntimeBridgeMode.audioOwned.ownedDomains, [.audio, .imageAssets, .persistence])
    }

    func testMediaOwnedOwnsAudioMediaAndInfrastructure() {
        XCTAssertEqual(LiveRuntimeBridgeMode.mediaOwned.ownedDomains, [.audio, .media, .imageAssets, .persistence])
    }

    func testBGMOwningModeOwnsAudioMediaBGMAndInfrastructure() {
        XCTAssertEqual(LiveRuntimeBridgeMode.bgmOwned.ownedDomains, [.audio, .media, .bgm, .imageAssets, .persistence])
    }

    func testProjectionOwningModeOwnsAudioMediaBGMAndProjection() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.projectionOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .imageAssets, .persistence]
        )
    }

    func testPPTOwnedModeOwnsAudioMediaBGMProjectionAndPPT() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.pptOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .imageAssets, .persistence]
        )
    }

    func testAutomationNoticeOwnedModeOwnsPriorDomainsAndAutomationNotice() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.automationNoticeOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .imageAssets, .persistence]
        )
    }

    func testSupportOwnedModeOwnsPriorDomainsAndSupport() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.supportOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .imageAssets, .persistence]
        )
    }

    func testAutomationCommandOwnedModeOwnsPriorDomainsAndAutomationCommand() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.automationCommandOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .imageAssets, .persistence]
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

    func testEveryProductionOwnedModeIncludesImageAssetsAndPersistence() {
        for mode in LiveRuntimeBridgeMode.allCases where mode != .recordingOnly && mode != .fullRuntime {
            XCTAssertTrue(mode.owns(.imageAssets), "\(mode)")
            XCTAssertTrue(mode.owns(.persistence), "\(mode)")
        }
    }

    func testAutomationCommandOwnedStillOwnsPriorDomains() {
        let mode = LiveRuntimeBridgeMode.automationCommandOwned

        for domain in [LiveRuntimeDomain.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand] {
            XCTAssertTrue(mode.owns(domain), "\(domain)")
        }
    }

    func testAutomationCommandOwnedStillDoesNotOwnAutomationQuery() {
        XCTAssertFalse(LiveRuntimeDomain.allCases.contains { $0.rawValue == "automationQuery" })
    }
}
