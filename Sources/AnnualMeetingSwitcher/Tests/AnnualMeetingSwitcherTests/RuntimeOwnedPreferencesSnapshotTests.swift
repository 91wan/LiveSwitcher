import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedPreferencesSnapshotTests: XCTestCase {
    func testPersistenceOwnedSnapshotPreservesRuntimeConsoleMode() {
        var state = runtimePreferencesState()
        state.mode = .live
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.consoleMode = .setup
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeThemeOverride() {
        var state = runtimePreferencesState()
        state.preferences.themeOverride = .system
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.themeOverride = .dark
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .system)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeActiveWallpaperURL() {
        var state = runtimePreferencesState()
        state.preferences.activeWallpaperURL = runtimeWallpaperURL
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.activeWallpaperURL = facadeWallpaperURL
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, runtimeWallpaperURL)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeCornerLogoURL() {
        var state = runtimePreferencesState()
        state.preferences.cornerLogoURL = runtimeLogoURL
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.cornerLogoURL = facadeLogoURL
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoURL, runtimeLogoURL)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeAutoPlayNextVideoOnEnd() {
        var state = runtimePreferencesState()
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.autoPlayNextVideoOnEnd = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeAutoAdvanceAtScheduledTime() {
        var state = runtimePreferencesState()
        state.preferences.autoAdvanceAtScheduledTime = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.autoAdvanceAtScheduledTime = false
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.preferences.autoAdvanceAtScheduledTime)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeShowAgendaTimeline() {
        var state = runtimePreferencesState()
        state.preferences.showAgendaTimeline = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.showAgendaTimeline = true
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.preferences.showAgendaTimeline)
    }

    func testPersistenceOwnedSnapshotPreservesRuntimeCornerLogoPosition() {
        var state = runtimePreferencesState()
        state.preferences.cornerLogoPosition = .bottomLeft
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.cornerLogoPosition = .topRight
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomLeft)
    }

    func testPersistenceOwnedSnapshotDoesNotOverwriteRuntimePreferencesWithStaleFacade() {
        var state = runtimePreferencesState()
        state.mode = .live
        state.preferences.themeOverride = .system
        state.preferences.activeWallpaperURL = runtimeWallpaperURL
        state.preferences.cornerLogoURL = runtimeLogoURL
        state.preferences.autoPlayNextVideoOnEnd = true
        state.preferences.autoAdvanceAtScheduledTime = true
        state.preferences.showAgendaTimeline = false
        state.preferences.cornerLogoPosition = .bottomLeft
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .audioOwned) { viewModel in
            viewModel.consoleMode = .setup
            viewModel.themeOverride = .dark
            viewModel.activeWallpaperURL = facadeWallpaperURL
            viewModel.cornerLogoURL = facadeLogoURL
            viewModel.autoPlayNextVideoOnEnd = false
            viewModel.autoAdvanceAtScheduledTime = false
            viewModel.showAgendaTimeline = true
            viewModel.cornerLogoPosition = .topRight
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertEqual(viewModel.runtime.state.preferences, state.preferences)
    }

    func testNonPersistenceOwnedSnapshotUsesFacadeConsoleMode() {
        var state = runtimePreferencesState()
        state.mode = .live
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .recordingOnly) { viewModel in
            viewModel.consoleMode = .setup
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.mode, .setup)
    }

    func testNonPersistenceOwnedSnapshotUsesFacadePreferences() {
        let viewModel = makeViewModel(runtimeState: runtimePreferencesState(), bridgeMode: .recordingOnly) { viewModel in
            viewModel.themeOverride = .system
            viewModel.activeWallpaperURL = facadeWallpaperURL
            viewModel.cornerLogoURL = facadeLogoURL
            viewModel.autoPlayNextVideoOnEnd = true
            viewModel.autoAdvanceAtScheduledTime = true
            viewModel.showAgendaTimeline = false
            viewModel.cornerLogoPosition = .bottomRight
        }

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.preferences.themeOverride, .system)
        XCTAssertEqual(viewModel.runtime.state.preferences.activeWallpaperURL, facadeWallpaperURL)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoURL, facadeLogoURL)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(viewModel.runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertFalse(viewModel.runtime.state.preferences.showAgendaTimeline)
        XCTAssertEqual(viewModel.runtime.state.preferences.cornerLogoPosition, .bottomRight)
    }

    func testSyncPreferencesIntoRuntimeSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("syncPreferencesIntoRuntimeSnapshot"))
    }

    func testMakeRuntimeStateSnapshotDoesNotWritePreferencesDirectly() throws {
        let body = try functionBody(named: "makeRuntimeStateSnapshot", in: runtimeSnapshotSource())

        [
            "state.mode = consoleMode",
            "state.preferences.themeOverride = themeOverride",
            "state.preferences.activeWallpaperURL = activeWallpaperURL",
            "state.preferences.cornerLogoURL = cornerLogoURL",
            "state.preferences.autoPlayNextVideoOnEnd = autoPlayNextVideoOnEnd",
            "state.preferences.autoAdvanceAtScheduledTime = autoAdvanceAtScheduledTime",
            "state.preferences.showAgendaTimeline = showAgendaTimeline",
            "state.preferences.cornerLogoPosition = cornerLogoPosition"
        ].forEach { directWrite in
            XCTAssertFalse(body.contains(directWrite), directWrite)
        }
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode,
        configureFacade: (SwitcherViewModel) -> Void
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        configureFacade(viewModel)
        runtime.replaceStateForFacadeSync(runtimeState)
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

    private var facadeWallpaperURL: URL {
        URL(fileURLWithPath: "/tmp/facade-wallpaper.png")
    }

    private var facadeLogoURL: URL {
        URL(fileURLWithPath: "/tmp/facade-logo.png")
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift"
        )
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let range = source.range(of: "func \(name)") else {
            XCTFail("Missing function \(name)")
            return ""
        }
        var depth = 0
        var body = ""
        var hasEnteredBody = false
        for character in source[range.lowerBound...] {
            body.append(character)
            if character == "{" {
                depth += 1
                hasEnteredBody = true
            } else if character == "}" {
                depth -= 1
                if hasEnteredBody && depth == 0 {
                    break
                }
            }
        }
        return body
    }
}
