import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeCumulativeOwnershipTests: XCTestCase {
    func testBridgeModeOwnedDomainsMatchContractMatrix() {
        let expected: [(LiveRuntimeBridgeMode, Set<LiveRuntimeDomain>)] = [
            (.recordingOnly, []),
            (.audioOwned, [.audio, .imageAssets, .persistence]),
            (.mediaOwned, [.audio, .media, .imageAssets, .persistence]),
            (.bgmOwned, [.audio, .media, .bgm, .imageAssets, .persistence]),
            (.projectionOwned, [.audio, .media, .bgm, .projection, .imageAssets, .persistence]),
            (.pptOwned, [.audio, .media, .bgm, .projection, .ppt, .imageAssets, .persistence]),
            (.automationNoticeOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .imageAssets, .persistence]),
            (.supportOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .imageAssets, .persistence]),
            (.automationCommandOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .imageAssets, .persistence]),
            (.presentationQueryOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .imageAssets, .persistence]),
            (.programQueueOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .imageAssets, .persistence]),
            (.programSelectionOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .imageAssets, .persistence]),
            (.programActivationOwned, [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .programActivation, .imageAssets, .persistence]),
            (.panicOwned, [.audio, .media, .bgm, .projection, .panic, .ppt, .automationNotice, .support, .automationCommand, .presentationQuery, .programQueue, .programSelection, .programActivation, .imageAssets, .persistence])
        ]

        for (mode, domains) in expected {
            XCTAssertEqual(mode.ownedDomains, domains, "\(mode)")
        }
    }

    func testFullRuntimeOwnsAllDomains() {
        XCTAssertEqual(LiveRuntimeBridgeMode.fullRuntime.ownedDomains, Set(LiveRuntimeDomain.allCases))
    }

    func testBridgeModesSeparateOwnershipFromInfrastructurePorts() {
        XCTAssertFalse(LiveRuntimeBridgeMode.panicOwned.owns(.automation))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.automationCommand))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.imageAssets))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.persistence))
    }
}
