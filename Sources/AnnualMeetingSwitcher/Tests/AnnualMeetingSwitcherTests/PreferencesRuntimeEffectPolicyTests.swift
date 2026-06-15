import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeEffectPolicyTests: XCTestCase {
    func testSaveConsoleModeRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveConsoleMode(.live).requiredBridgeDomain, .persistence)
    }

    func testSaveThemeOverrideRequiresPersistence() {
        XCTAssertEqual(LiveRuntimeEffect.saveThemeOverride(.dark).requiredBridgeDomain, .persistence)
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
}
