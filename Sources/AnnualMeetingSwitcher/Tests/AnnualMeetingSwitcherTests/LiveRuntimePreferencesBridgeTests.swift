import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimePreferencesBridgeTests: XCTestCase {
    func testRuntimePreferenceActionsRequestSpecificPersistenceEffects() {
        let autoPlay = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetAutoPlayNextVideoOnEnd(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )
        let scheduledAdvance = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetAutoAdvanceAtScheduledTime(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )
        let agendaTimeline = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetShowAgendaTimeline(true),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(autoPlay.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(autoPlay.effects.contains(.saveAutoPlayNextVideoOnEnd(true)))
        XCTAssertTrue(scheduledAdvance.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(scheduledAdvance.effects.contains(.saveAutoAdvanceAtScheduledTime(true)))
        XCTAssertTrue(agendaTimeline.state.preferences.showAgendaTimeline)
        XCTAssertTrue(agendaTimeline.effects.contains(.saveShowAgendaTimeline(true)))
    }

    func testEffectRunnerInvokesInjectedPreferencePersistencePort() {
        let persistence = PreferencePersistencePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence)

        runner.run(
            [
                .saveAutoPlayNextVideoOnEnd(true),
                .saveAutoAdvanceAtScheduledTime(false),
                .saveShowAgendaTimeline(true)
            ],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Preference persistence effects should not dispatch actions") }
        )

        XCTAssertEqual(persistence.savedAutoPlayNextVideoOnEnd, [true])
        XCTAssertEqual(persistence.savedAutoAdvanceAtScheduledTime, [false])
        XCTAssertEqual(persistence.savedShowAgendaTimeline, [true])
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

        XCTAssertTrue(runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(runtime.state.preferences.showAgendaTimeline)
        XCTAssertEqual(persistence.savedAutoPlayNextVideoOnEnd, [true])
        XCTAssertEqual(persistence.savedAutoAdvanceAtScheduledTime, [true])
        XCTAssertEqual(persistence.savedShowAgendaTimeline, [true])
        XCTAssertNil(defaults.object(forKey: "autoPlayNextVideoOnEnd"))
        XCTAssertNil(defaults.object(forKey: "autoAdvanceAtScheduledTime"))
        XCTAssertNil(defaults.object(forKey: "showAgendaTimeline"))
    }
}

private final class PreferencePersistencePortSpy: PersistencePort {
    private(set) var saveCount = 0
    private(set) var savedAutoPlayNextVideoOnEnd: [Bool] = []
    private(set) var savedAutoAdvanceAtScheduledTime: [Bool] = []
    private(set) var savedShowAgendaTimeline: [Bool] = []

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
}
