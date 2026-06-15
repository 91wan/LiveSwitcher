import XCTest
@testable import LiveSwitcher

final class AssetRuntimeEffectPolicyTests: XCTestCase {
    func testLoadBackgroundImageRequiresImageAssets() {
        XCTAssertEqual(
            LiveRuntimeEffect.loadBackgroundImage(URL(fileURLWithPath: "/tmp/wallpaper.png")).requiredBridgeDomain,
            .imageAssets
        )
    }

    func testLoadCornerLogoImageRequiresImageAssets() {
        XCTAssertEqual(
            LiveRuntimeEffect.loadCornerLogoImage(URL(fileURLWithPath: "/tmp/logo.png")).requiredBridgeDomain,
            .imageAssets
        )
    }
}
