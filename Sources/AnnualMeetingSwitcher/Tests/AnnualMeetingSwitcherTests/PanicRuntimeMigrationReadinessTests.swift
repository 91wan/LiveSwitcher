import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeMigrationReadinessTests: XCTestCase {
    func testProductionViewModelRuntimeBridgeModeRemainsProgramActivationOwned() {
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .programActivationOwned)
    }

    func testProductionConnectedPortsRemainProgramActivationOwnedSet() {
        XCTAssertEqual(
            makeViewModel().runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProgramActivationOwnedModeDoesNotOwnPanic() {
        XCTAssertFalse(LiveRuntimeBridgeMode.programActivationOwned.owns(.panic))
    }

    func testNoPanicOwnedBridgeModeYet() {
        XCTAssertFalse(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == "panicOwned" })
        XCTAssertFalse(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == "panicTransitionOwned" })
    }

    func testNoProductionPanicOwningEnvironmentYet() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")

        XCTAssertFalse(source.contains("productionPanicOwning"))
    }

    func testNoPanicPortYet() throws {
        let ports = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertFalse(ports.contains("PanicPort"))
    }

    func testRuntimeCanNowRepresentDelayedBGMPause() throws {
        let effects = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")
        let actions = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")
        let ports = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(effects.contains("schedulePanicBGMPause"))
        XCTAssertTrue(effects.contains("cancelPanicBGMPause"))
        XCTAssertTrue(actions.contains("panicBGMPauseDelayElapsed"))
        XCTAssertTrue(ports.contains("PanicDelayPort"))
    }

    func testViewModelPanicStillOwnsDelayedBGMPauseTask() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertTrue(source.contains("cleanupBag.panicAudioPauseTask"))
        XCTAssertTrue(source.contains("Task.sleep"))
    }

    func testRuntimePanicReducerIsNotProductionOwnedYet() throws {
        let source = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(source.localizedStandardContains("Runtime `.panic` domain exists but is not production-owned yet"))
    }

    func testRuntimePanicReducerSchedulesDelayedBGMPauseWhenFadeDurationPositive() {
        var state = LiveRuntimeState()
        let bgm = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.isPlaying = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(true),
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 1.0)
        )

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(where: { effect in
            if case .schedulePanicBGMPause = effect { return true }
            return false
        }))
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .pauseBGM = effect { return true }
            return false
        }))
    }

    func testViewModelPanicPolicyDelaysBGMPauseWhenFadeDurationPositive() {
        let viewModel = makeViewModel()
        let bgm = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testPanicMigrationBlockedUntilProductionPanicDelayPortIsWired() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.localizedStandardContains("Panic migration is blocked until production PanicDelayPort is wired"))
    }

    func testProductionRuntimeDoesNotWirePanicDelayPortYet() throws {
        let bundle = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/SwitcherRuntimePortBundle.swift")

        XCTAssertFalse(makeViewModel().runtimeConnectedPortKinds.contains(.panicDelay))
        XCTAssertFalse(bundle.contains("panicDelay"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }
}
