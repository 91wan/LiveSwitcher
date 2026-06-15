import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeReducerBehaviorTests: XCTestCase {
    func testSetConsoleModeUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setConsoleMode(.live, state: &state, effects: &effects)

        XCTAssertEqual(state.mode, .live)
        XCTAssertEqual(effects, [.saveConsoleMode(.live)])
    }

    func testSetThemeOverrideUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setThemeOverride(.system, state: &state, effects: &effects)

        XCTAssertEqual(state.preferences.themeOverride, .system)
        XCTAssertEqual(effects, [.saveThemeOverride(.system)])
    }

    func testSetActiveWallpaperURLUpdatesStateAndEmitsLoadBackground() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        let url = URL(fileURLWithPath: "/tmp/wallpaper.png")

        PreferencesRuntimeReducer.setActiveWallpaperURL(url, state: &state, effects: &effects)

        XCTAssertEqual(state.preferences.activeWallpaperURL, url)
        XCTAssertEqual(effects, [.loadBackgroundImage(url)])
    }

    func testSetActiveWallpaperNilUpdatesStateAndEmitsLoadBackgroundNil() {
        var state = LiveRuntimeState()
        state.preferences.activeWallpaperURL = URL(fileURLWithPath: "/tmp/wallpaper.png")
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setActiveWallpaperURL(nil, state: &state, effects: &effects)

        XCTAssertNil(state.preferences.activeWallpaperURL)
        XCTAssertEqual(effects, [.loadBackgroundImage(nil)])
    }

    func testSetCornerLogoURLUpdatesStateAndEmitsLoadCornerLogo() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        let url = URL(fileURLWithPath: "/tmp/logo.png")

        PreferencesRuntimeReducer.setCornerLogoURL(url, state: &state, effects: &effects)

        XCTAssertEqual(state.preferences.cornerLogoURL, url)
        XCTAssertEqual(effects, [.loadCornerLogoImage(url)])
    }

    func testSetCornerLogoNilUpdatesStateAndEmitsLoadCornerLogoNil() {
        var state = LiveRuntimeState()
        state.preferences.cornerLogoURL = URL(fileURLWithPath: "/tmp/logo.png")
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setCornerLogoURL(nil, state: &state, effects: &effects)

        XCTAssertNil(state.preferences.cornerLogoURL)
        XCTAssertEqual(effects, [.loadCornerLogoImage(nil)])
    }

    func testSetAutoPlayNextVideoUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setAutoPlayNextVideoOnEnd(true, state: &state, effects: &effects)

        XCTAssertTrue(state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertEqual(effects, [.saveAutoPlayNextVideoOnEnd(true)])
    }

    func testSetAutoAdvanceUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setAutoAdvanceAtScheduledTime(true, state: &state, effects: &effects)

        XCTAssertTrue(state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertEqual(effects, [.saveAutoAdvanceAtScheduledTime(true)])
    }

    func testSetShowAgendaTimelineUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setShowAgendaTimeline(true, state: &state, effects: &effects)

        XCTAssertTrue(state.preferences.showAgendaTimeline)
        XCTAssertEqual(effects, [.saveShowAgendaTimeline(true)])
    }

    func testSetCornerLogoPositionUpdatesStateAndEmitsSave() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setCornerLogoPosition(.bottomLeft, state: &state, effects: &effects)

        XCTAssertEqual(state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertEqual(effects, [.saveCornerLogoPosition(.bottomLeft)])
    }
}
