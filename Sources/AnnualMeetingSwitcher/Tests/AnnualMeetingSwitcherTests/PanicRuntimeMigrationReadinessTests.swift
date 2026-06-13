import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeMigrationReadinessTests: XCTestCase {
    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsIncludePanicDelaySet() {
        XCTAssertEqual(
            makeViewModel().runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProgramActivationOwnedModeStillDoesNotOwnPanic() {
        XCTAssertFalse(LiveRuntimeBridgeMode.programActivationOwned.owns(.panic))
    }

    func testPanicOwnedBridgeModeExistsAndOwnsPanic() {
        XCTAssertTrue(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == "panicOwned" })
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.panic))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.programActivation))
        XCTAssertFalse(LiveRuntimeBridgeMode.allCases.contains { $0.rawValue == "panicTransitionOwned" })
    }

    func testProductionPanicOwningEnvironmentExists() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")

        XCTAssertTrue(source.contains("productionPanicOwning"))
        XCTAssertEqual(LiveRuntimeEnvironment.productionPanicOwning().bridgeMode, .panicOwned)
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

    func testViewModelPanicDelegatesDelayedBGMPauseTaskToRuntimePort() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
        let wiring = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PanicDelayRuntimeWiring.swift")
        let toggleBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePanicMode"))

        XCTAssertTrue(toggleBody.contains("runtime.bridgeMode.owns(.panic)"))
        XCTAssertTrue(toggleBody.contains("dispatchRuntimeFacadeAction(.operatorSetPanic"))
        XCTAssertTrue(wiring.contains("cleanupBag.panicAudioPauseTask"))
        XCTAssertTrue(wiring.contains("Task.sleep"))
        XCTAssertTrue(wiring.contains("context.dispatch(.panicBGMPauseDelayElapsed"))
    }

    func testRuntimePanicReducerIsProductionOwned() throws {
        let source = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(source.localizedStandardContains("Production bridge mode is `.panicOwned`"))
        XCTAssertTrue(source.localizedStandardContains("Panic transition orchestration is runtime-owned"))
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
        viewModel.bgmItems = [bgm]
        viewModel.toggleBGM(bgm)
        XCTAssertTrue(viewModel.isBGMPlaying)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testPanicMigrationNoLongerDocumentsPanicDelayPortBlocker() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertFalse(docs.localizedStandardContains("Panic migration is blocked until production PanicDelayPort is wired"))
    }

    func testProductionRuntimeWiresPanicDelayPort() throws {
        let bundle = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/SwitcherRuntimePortBundle.swift")

        XCTAssertTrue(makeViewModel().runtimeConnectedPortKinds.contains(.panicDelay))
        XCTAssertTrue(bundle.contains("panicDelay"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }
}
