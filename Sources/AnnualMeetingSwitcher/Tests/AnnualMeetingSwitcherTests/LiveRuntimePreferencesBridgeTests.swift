import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimePreferencesBridgeTests: XCTestCase {
    func testRuntimePreferenceActionsRequestSpecificPersistenceEffects() {
        let autoPlay = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetAutoPlayNextVideoOnEnd(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let scheduledAdvance = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetAutoAdvanceAtScheduledTime(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let agendaTimeline = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetShowAgendaTimeline(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let logoPosition = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetCornerLogoPosition(.bottomLeft),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let consoleMode = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetConsoleMode(.live),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let themeOverride = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetThemeOverride(.system),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(autoPlay.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(autoPlay.effects.contains(.saveAutoPlayNextVideoOnEnd(true)))
        XCTAssertTrue(scheduledAdvance.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(scheduledAdvance.effects.contains(.saveAutoAdvanceAtScheduledTime(true)))
        XCTAssertTrue(agendaTimeline.state.preferences.showAgendaTimeline)
        XCTAssertTrue(agendaTimeline.effects.contains(.saveShowAgendaTimeline(true)))
        XCTAssertEqual(logoPosition.state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertTrue(logoPosition.effects.contains(.saveCornerLogoPosition(.bottomLeft)))
        XCTAssertEqual(consoleMode.state.mode, .live)
        XCTAssertTrue(consoleMode.effects.contains(.saveConsoleMode(.live)))
        XCTAssertEqual(themeOverride.state.preferences.themeOverride, .system)
        XCTAssertTrue(themeOverride.effects.contains(.saveThemeOverride(.system)))
    }

    func testEffectRunnerInvokesInjectedPreferencePersistencePort() {
        let persistence = PreferencePersistencePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence)

        runner.run(
            [
                .saveAutoPlayNextVideoOnEnd(true),
                .saveAutoAdvanceAtScheduledTime(false),
                .saveShowAgendaTimeline(true),
                .saveCornerLogoPosition(.bottomRight),
                .saveConsoleMode(.live),
                .saveThemeOverride(.light)
            ],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Preference persistence effects should not dispatch actions") }
        )

        XCTAssertEqual(persistence.savedAutoPlayNextVideoOnEnd, [true])
        XCTAssertEqual(persistence.savedAutoAdvanceAtScheduledTime, [false])
        XCTAssertEqual(persistence.savedShowAgendaTimeline, [true])
        XCTAssertEqual(persistence.savedCornerLogoPositions, [.bottomRight])
        XCTAssertEqual(persistence.savedConsoleModes, [.live])
        XCTAssertEqual(persistence.savedThemeOverrides, [.light])
    }

    func testViewModelPreferenceSettersRoutePersistenceThroughRuntimePort() {
        let suiteName = "LiveRuntimePreferencesBridgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = PreferencePersistencePortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )

        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.autoAdvanceAtScheduledTime = true
        viewModel.showAgendaTimeline = true
        viewModel.cornerLogoPosition = .bottomLeft
        viewModel.consoleMode = .live
        viewModel.themeOverride = .system

        XCTAssertTrue(runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(runtime.state.preferences.showAgendaTimeline)
        XCTAssertEqual(runtime.state.preferences.cornerLogoPosition, .bottomLeft)
        XCTAssertEqual(runtime.state.mode, .live)
        XCTAssertEqual(runtime.state.preferences.themeOverride, .system)
        XCTAssertEqual(persistence.savedAutoPlayNextVideoOnEnd, [true])
        XCTAssertEqual(persistence.savedAutoAdvanceAtScheduledTime, [true])
        XCTAssertEqual(persistence.savedShowAgendaTimeline, [true])
        XCTAssertEqual(persistence.savedCornerLogoPositions, [.bottomLeft])
        XCTAssertEqual(persistence.savedConsoleModes, [.live])
        XCTAssertEqual(persistence.savedThemeOverrides, [.system])
        XCTAssertNil(defaults.object(forKey: "autoPlayNextVideoOnEnd"))
        XCTAssertNil(defaults.object(forKey: "autoAdvanceAtScheduledTime"))
        XCTAssertNil(defaults.object(forKey: "showAgendaTimeline"))
        XCTAssertNil(defaults.object(forKey: "cornerLogo_position"))
        XCTAssertNil(defaults.object(forKey: "consoleMode"))
        XCTAssertNil(defaults.object(forKey: "themeOverride"))
    }
}

private final class PreferencePersistencePortSpy: PersistencePort {
    private(set) var saveCount = 0
    private(set) var savedAutoPlayNextVideoOnEnd: [Bool] = []
    private(set) var savedAutoAdvanceAtScheduledTime: [Bool] = []
    private(set) var savedShowAgendaTimeline: [Bool] = []
    private(set) var savedCornerLogoPositions: [CornerLogoPosition] = []
    private(set) var savedConsoleModes: [ConsoleMode] = []
    private(set) var savedThemeOverrides: [ThemeOverride] = []

    func save() {
        saveCount += 1
    }

    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {
        savedAutoPlayNextVideoOnEnd.append(isEnabled)
    }

    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {
        savedAutoAdvanceAtScheduledTime.append(isEnabled)
    }

    func saveShowAgendaTimeline(_ isEnabled: Bool) {
        savedShowAgendaTimeline.append(isEnabled)
    }

    func saveCornerLogoPosition(_ position: CornerLogoPosition) {
        savedCornerLogoPositions.append(position)
    }

    func saveConsoleMode(_ mode: ConsoleMode) {
        savedConsoleModes.append(mode)
    }

    func saveThemeOverride(_ theme: ThemeOverride) {
        savedThemeOverrides.append(theme)
    }
}
