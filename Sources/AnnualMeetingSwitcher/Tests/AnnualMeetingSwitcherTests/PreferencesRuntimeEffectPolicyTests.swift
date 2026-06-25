import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeEffectPolicyTests: XCTestCase {
    func testSaveConsoleModeRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveConsoleMode(.live).requiredBridgeDomain, .persistence)
    }

    func testSaveThemeOverrideRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveThemeOverride(.dark).requiredBridgeDomain, .persistence)
    }

    func testSaveCompanyDisplayNameRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveCompanyDisplayName("示例科技").requiredBridgeDomain, .persistence)
    }

    func testSaveAutoPlayNextVideoRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveAutoPlayNextVideoOnEnd(true).requiredBridgeDomain, .persistence)
    }

    func testSaveAutoAdvanceRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveAutoAdvanceAtScheduledTime(true).requiredBridgeDomain, .persistence)
    }

    func testSaveShowAgendaTimelineRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveShowAgendaTimeline(true).requiredBridgeDomain, .persistence)
    }

    func testSaveCornerLogoPositionRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveCornerLogoPosition(.bottomLeft).requiredBridgeDomain, .persistence)
    }

    func testSaveCornerLogoVisibleRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveCornerLogoVisible(true).requiredBridgeDomain, .persistence)
    }
}
