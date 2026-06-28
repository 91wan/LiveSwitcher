import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeReducerExtractionTests: XCTestCase {
    func testRuntimePreferenceActionsPersistConsoleThemeAndCompanyName() {
        let consoleMode = reduce(.operatorSetConsoleMode(.live))
        XCTAssertEqual(consoleMode.state.mode, .live)
        XCTAssertEqual(consoleMode.effects, [.saveConsoleMode(.live)])

        let theme = reduce(.operatorSetThemeOverride(.system))
        XCTAssertEqual(theme.state.preferences.themeOverride, .system)
        XCTAssertEqual(theme.effects, [.saveThemeOverride(.system)])

        let companyName = reduce(.operatorSetCompanyDisplayName("  Acme   Live  "))
        XCTAssertEqual(companyName.state.preferences.companyDisplayName, "Acme Live")
        XCTAssertEqual(companyName.effects, [.saveCompanyDisplayName("Acme Live")])
    }

    func testWallpaperAndCornerLogoActionsLoadAssetsAndPersistVisibility() {
        let wallpaper = URL(fileURLWithPath: "/tmp/wallpaper.png")
        let background = reduce(.operatorSetActiveWallpaperURL(wallpaper))
        XCTAssertEqual(background.state.preferences.activeWallpaperURL, wallpaper)
        XCTAssertEqual(background.effects, [.loadBackgroundImage(wallpaper)])

        let logo = URL(fileURLWithPath: "/tmp/logo.png")
        let logoAdded = reduce(.operatorSetCornerLogoURL(logo))
        XCTAssertEqual(logoAdded.state.preferences.cornerLogoURL, logo)
        XCTAssertTrue(logoAdded.state.preferences.isCornerLogoVisible)
        XCTAssertEqual(logoAdded.effects, [
            .loadCornerLogoImage(logo),
            .saveCornerLogoVisible(true)
        ] as [LiveRuntimeEffect])

        let logoHidden = reduce(logoAdded.state, .operatorSetCornerLogoVisible(false))
        XCTAssertFalse(logoHidden.state.preferences.isCornerLogoVisible)
        XCTAssertEqual(logoHidden.effects, [.saveCornerLogoVisible(false)])

        let logoRemoved = reduce(logoAdded.state, .operatorSetCornerLogoURL(nil))
        XCTAssertNil(logoRemoved.state.preferences.cornerLogoURL)
        XCTAssertFalse(logoRemoved.state.preferences.isCornerLogoVisible)
        XCTAssertEqual(logoRemoved.effects, [
            .loadCornerLogoImage(nil),
            .saveCornerLogoVisible(false)
        ] as [LiveRuntimeEffect])
    }

    func testPlaybackAgendaAndLogoPositionActionsEmitSinglePersistenceEffects() {
        let autoNext = reduce(.operatorSetAutoPlayNextVideoOnEnd(true))
        XCTAssertTrue(autoNext.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertEqual(autoNext.effects, [.saveAutoPlayNextVideoOnEnd(true)])

        let reminder = reduce(.operatorSetAgendaTimeReminderEnabled(true))
        XCTAssertTrue(reminder.state.preferences.isAgendaTimeReminderEnabled)
        XCTAssertEqual(reminder.effects, [.saveAgendaTimeReminderEnabled(true)])

        let timeline = reduce(.operatorSetShowAgendaTimeline(true))
        XCTAssertTrue(timeline.state.preferences.showAgendaTimeline)
        XCTAssertEqual(timeline.effects, [.saveShowAgendaTimeline(true)])

        let logoPosition = reduce(.operatorSetCornerLogoPosition(.bottomLeft))
        XCTAssertEqual(logoPosition.state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertEqual(logoPosition.effects, [.saveCornerLogoPosition(.bottomLeft)])
    }

    func testInvalidCompanyNameDoesNotMutateOrPersist() {
        var state = LiveRuntimeState()
        state.preferences.companyDisplayName = "Acme"
        let tooLongName = String(repeating: "A", count: BrandingDisplayNamePolicy.maximumCharacterCount + 1)

        let mutation = reduce(state, .operatorSetCompanyDisplayName(tooLongName))

        XCTAssertEqual(mutation.state.preferences.companyDisplayName, "Acme")
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPreferenceActionsNoopWhenPersistenceBridgeIsNotRuntimeOwned() {
        let state = LiveRuntimeState()

        let mutation = reduce(
            state,
            .operatorSetConsoleMode(.live),
            environment: .recordingOnlyForTests()
        )

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .fullRuntimeForTests()
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, environment: environment)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .fullRuntimeForTests()
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
    }
}
