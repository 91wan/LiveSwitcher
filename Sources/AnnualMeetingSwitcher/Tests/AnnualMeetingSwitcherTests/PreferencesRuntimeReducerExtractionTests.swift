import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeReducerExtractionTests: XCTestCase {
    func testPreferencesRuntimeReducerFileExists() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PreferencesRuntimeReducer.swift")

        XCTAssertTrue(source.contains("enum PreferencesRuntimeReducer"))
    }

    func testPreferencesRuntimeReducerOwnsConsoleModeLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("state.mode = mode"))
        XCTAssertTrue(source.contains("effects.append(.saveConsoleMode(mode))"))
    }

    func testPreferencesRuntimeReducerOwnsThemeOverrideLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("state.preferences.themeOverride = theme"))
        XCTAssertTrue(source.contains("effects.append(.saveThemeOverride(theme))"))
    }

    func testPreferencesRuntimeReducerOwnsWallpaperLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("state.preferences.activeWallpaperURL = url"))
        XCTAssertTrue(source.contains("effects.append(.loadBackgroundImage(url))"))
    }

    func testPreferencesRuntimeReducerOwnsCornerLogoLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("state.preferences.cornerLogoURL = url"))
        XCTAssertTrue(source.contains("effects.append(.loadCornerLogoImage(url))"))
    }

    func testPreferencesRuntimeReducerOwnsAutoPlayNextVideoLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("state.preferences.autoPlayNextVideoOnEnd = isEnabled"))
        XCTAssertTrue(source.contains("effects.append(.saveAutoPlayNextVideoOnEnd(isEnabled))"))
    }

    func testLiveRuntimeReducerDelegatesConsoleMode() throws {
        let source = try liveRuntimeReducerSource()

        XCTAssertTrue(source.contains("PreferencesRuntimeReducer.setConsoleMode("))
    }

    func testLiveRuntimeReducerDelegatesThemeOverride() throws {
        let source = try liveRuntimeReducerSource()

        XCTAssertTrue(source.contains("PreferencesRuntimeReducer.setThemeOverride("))
    }

    func testLiveRuntimeReducerDelegatesWallpaperURL() throws {
        let source = try liveRuntimeReducerSource()

        XCTAssertTrue(source.contains("PreferencesRuntimeReducer.setActiveWallpaperURL("))
    }

    func testLiveRuntimeReducerDelegatesCornerLogoURL() throws {
        let source = try liveRuntimeReducerSource()

        XCTAssertTrue(source.contains("PreferencesRuntimeReducer.setCornerLogoURL("))
    }

    func testLiveRuntimeReducerDoesNotContainPreferenceMutationBodies() throws {
        let source = try liveRuntimeReducerSource()
        [
            "state.mode =",
            "state.preferences.themeOverride =",
            "state.preferences.activeWallpaperURL =",
            "state.preferences.cornerLogoURL =",
            "state.preferences.autoPlayNextVideoOnEnd =",
            "state.preferences.isAgendaTimeReminderEnabled =",
            "state.preferences.showAgendaTimeline =",
            "state.preferences.cornerLogoPosition =",
            "effects.append(.saveConsoleMode",
            "effects.append(.saveThemeOverride",
            "effects.append(.loadBackgroundImage",
            "effects.append(.loadCornerLogoImage",
            "effects.append(.saveAutoPlayNextVideoOnEnd",
            "effects.append(.saveAgendaTimeReminderEnabled",
            "effects.append(.saveShowAgendaTimeline",
            "effects.append(.saveCornerLogoPosition"
        ].forEach { forbidden in
            XCTAssertFalse(source.contains(forbidden), "LiveRuntimeReducer still owns preference mutation body: \(forbidden)")
        }
    }

    private func reducerSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PreferencesRuntimeReducer.swift")
    }

    private func liveRuntimeReducerSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
    }
}
