import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimePortContractTests: XCTestCase {
    func testPresentationQueryPortRequiresExecutionContext() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )

        XCTAssertTrue(source.contains("protocol PresentationQueryPort"))
        XCTAssertTrue(source.contains("func scan(id: UUID, context: LiveRuntimeEffectExecutionContext)"))
    }

    func testClosurePresentationQueryPortForwardsIDAndContext() {
        let port = ClosurePresentationQueryPort()
        let id = UUID()
        var forwardedID: UUID?
        var didReadContextState = false
        port.scanHandler = { id, context in
            forwardedID = id
            didReadContextState = context.currentState().presentationQuery.activeRequestID == id
        }
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        port.scan(id: id, context: LiveRuntimeEffectExecutionContext(
            currentState: { state },
            dispatch: { _ in }
        ))

        XCTAssertEqual(forwardedID, id)
        XCTAssertTrue(didReadContextState)
    }

    func testPresentationQueryPortHasNoDefaultNoOpImplementation() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )

        XCTAssertFalse(source.contains("extension PresentationQueryPort"))
    }

    func testEffectRunnerWiresPresentationQueryPort() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectRunner.swift"
        )

        XCTAssertTrue(source.contains("private let presentationQuery"))
        XCTAssertTrue(source.contains("presentationQuery: PresentationQueryPort? = nil"))
        XCTAssertTrue(source.contains("presentationQuery?.scan(id: id, context: context)"))
    }

    func testEffectRunnerConnectedPortsIncludesPresentationQueryWhenWired() {
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, presentationQuery: ClosurePresentationQueryPort())

        XCTAssertTrue(runner.connectedPortKinds.contains(.presentationQuery))
    }

    func testProductionRuntimeWiresPresentationQueryPort() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.presentationQuery))
    }

    func testEffectRunnerPortFieldsRemainPrivate() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectRunner.swift"
        )

        XCTAssertTrue(source.contains("private let presentationQuery"))
        XCTAssertFalse(source.contains("var presentationQuery: PresentationQueryPort"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimePortContractTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
