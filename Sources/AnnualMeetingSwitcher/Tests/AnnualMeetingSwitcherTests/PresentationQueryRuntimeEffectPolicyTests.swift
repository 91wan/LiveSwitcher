import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeEffectPolicyTests: XCTestCase {
    func testScanPresentationQueryEffectRequiresPresentationQueryDomain() {
        XCTAssertEqual(LiveRuntimeEffect.scanPresentationQuery(id: UUID()).requiredBridgeDomain, .presentationQuery)
    }

    func testRequestPresentationQueryEmitsOnlyScanEffect() {
        let id = UUID()

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorRequestedPresentationQuery(id: id),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )

        XCTAssertEqual(mutation.effects, [.scanPresentationQuery(id: id)])
    }
}
