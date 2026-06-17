import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimePreferencesSnapshotOwnershipBoundaryTests: XCTestCase {
    func testPersistenceOwnedOperatorSetConsoleModeStillUpdatesRuntimeMode() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.consoleMode = .setup })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
    }

    func testPersistenceOwnedOperatorSetThemeOverrideStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.themeOverride = .dark })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetThemeOverride(.system))

        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .system)
    }

    func testPersistenceOwnedOperatorSetActiveWallpaperURLStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.activeWallpaperURL = staleWallpaperURL })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetActiveWallpaperURL(runtimeWallpaperURL))

        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, runtimeWallpaperURL)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.loadBackgroundImage(runtimeWallpaperURL)))
    }

    func testPersistenceOwnedOperatorSetCornerLogoURLStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.cornerLogoURL = staleLogoURL })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetCornerLogoURL(runtimeLogoURL))

        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoURL, runtimeLogoURL)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.loadCornerLogoImage(runtimeLogoURL)))
    }

    func testPersistenceOwnedOperatorSetAutoPlayNextVideoStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.autoPlayNextVideoOnEnd = false })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetAutoPlayNextVideoOnEnd(true))

        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
    }

    func testPersistenceOwnedOperatorSetAutoAdvanceStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.autoAdvanceAtScheduledTime = false })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetAutoAdvanceAtScheduledTime(true))

        XCTAssertTrue(viewModel.runtime.state.preferences.autoAdvanceAtScheduledTime)
    }

    func testPersistenceOwnedOperatorSetShowAgendaTimelineStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.showAgendaTimeline = true })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(false))

        XCTAssertFalse(viewModel.runtime.state.preferences.showAgendaTimeline)
    }

    func testPersistenceOwnedOperatorSetCornerLogoPositionStillUpdatesRuntimePreference() {
        let viewModel = makePersistenceOwnedViewModel(staleFacade: { $0.cornerLogoPosition = .topRight })

        viewModel.dispatchRuntimeFacadeAction(.operatorSetCornerLogoPosition(.bottomLeft))

        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomLeft)
    }

    func testUnrelatedRuntimeActionDoesNotOverwritePersistenceOwnedPreferencesFromFacade() {
        var state = runtimePreferencesState()
        state.mode = .live
        state.preferences.themeOverride = .system
        state.preferences.activeWallpaperURL = runtimeWallpaperURL
        state.preferences.cornerLogoURL = runtimeLogoURL
        state.preferences.autoPlayNextVideoOnEnd = true
        state.preferences.autoAdvanceAtScheduledTime = true
        state.preferences.showAgendaTimeline = false
        state.preferences.cornerLogoPosition = .bottomLeft
        let expectedPreferences = state.preferences
        let viewModel = makePersistenceOwnedViewModel(runtimeState: state) { viewModel in
            viewModel.consoleMode = .setup
            viewModel.themeOverride = .dark
            viewModel.activeWallpaperURL = staleWallpaperURL
            viewModel.cornerLogoURL = staleLogoURL
            viewModel.autoPlayNextVideoOnEnd = false
            viewModel.autoAdvanceAtScheduledTime = false
            viewModel.showAgendaTimeline = true
            viewModel.cornerLogoPosition = .topRight
        }

        viewModel.dispatchRuntimeFacadeAction(.operatorChangedMasterVolume(0.25))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences, expectedPreferences)
    }

    private func makePersistenceOwnedViewModel(
        runtimeState: LiveRuntimeState? = nil,
        staleFacade: (SwitcherViewModel) -> Void
    ) -> SwitcherViewModel {
        let state = runtimeState ?? runtimePreferencesState()
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        staleFacade(viewModel)
        runtime.replaceStateForFacadeSync(state)
        return viewModel
    }

    private func runtimePreferencesState() -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.mode = .setup
        state.preferences.themeOverride = .dark
        state.preferences.activeWallpaperURL = URL(fileURLWithPath: "/tmp/runtime-existing-wallpaper.png")
        state.preferences.cornerLogoURL = URL(fileURLWithPath: "/tmp/runtime-existing-logo.png")
        state.preferences.autoPlayNextVideoOnEnd = false
        state.preferences.autoAdvanceAtScheduledTime = false
        state.preferences.showAgendaTimeline = true
        state.preferences.cornerLogoPosition = .topLeft
        return state
    }

    private var runtimeWallpaperURL: URL {
        URL(fileURLWithPath: "/tmp/runtime-wallpaper.png")
    }

    private var runtimeLogoURL: URL {
        URL(fileURLWithPath: "/tmp/runtime-logo.png")
    }

    private var staleWallpaperURL: URL {
        URL(fileURLWithPath: "/tmp/stale-wallpaper.png")
    }

    private var staleLogoURL: URL {
        URL(fileURLWithPath: "/tmp/stale-logo.png")
    }
}
