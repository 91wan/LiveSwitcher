import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentLoadDispatchSuppressionTests: XCTestCase {
    func testRuntimeFacadeDispatchIsSuppressedInsideScopedProjection() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.withRuntimeFacadeDispatchSuppressed {
            viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))
        }

        XCTAssertEqual(viewModel.runtime.state.mode, .setup)
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testRuntimeFacadeDispatchRunsOutsideScopedProjection() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetConsoleMode" })
    }

    func testRuntimeFacadeDispatchSuppressionDepthReturnsToZero() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.withRuntimeFacadeDispatchSuppressed {
            XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 1)
        }

        XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 0)
    }

    func testNestedRuntimeFacadeDispatchSuppressionBalancesDepth() {
        let viewModel = makeViewModel(bridgeMode: .panicOwned)

        viewModel.withRuntimeFacadeDispatchSuppressed {
            XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 1)
            viewModel.withRuntimeFacadeDispatchSuppressed {
                XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 2)
            }
            XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 1)
        }

        XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 0)
    }

    func testSuppressionGuardRunsBeforeSyncPolicyAndSnapshot() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeFacadeAction"))
        let guardRange = try XCTUnwrap(body.range(of: "guard runtimeFacadeDispatchSuppressionDepth == 0 else { return }"))
        let policyRange = try XCTUnwrap(body.range(of: "LiveRuntimeFacadeSyncPolicy.options"))
        let syncRange = try XCTUnwrap(body.range(of: "syncRuntimeStateFromFacade"))
        let dispatchRange = try XCTUnwrap(body.range(of: "runtime.dispatch(action)"))

        XCTAssertLessThan(guardRange.lowerBound, policyRange.lowerBound)
        XCTAssertLessThan(guardRange.lowerBound, syncRange.lowerBound)
        XCTAssertLessThan(guardRange.lowerBound, dispatchRange.lowerBound)
    }

    func testSuppressionUsesDefer() throws {
        let viewModelSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let facadeSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
        let suppressionBody = try XCTUnwrap(facadeSource.extractedRuntimeFunctionBody(named: "withRuntimeFacadeDispatchSuppressed"))

        XCTAssertTrue(viewModelSource.contains("runtimeFacadeDispatchSuppressionDepth"))
        XCTAssertTrue(suppressionBody.contains("runtimeFacadeDispatchSuppressionDepth += 1"))
        XCTAssertTrue(suppressionBody.contains("defer"))
        XCTAssertTrue(suppressionBody.contains("runtimeFacadeDispatchSuppressionDepth -= 1"))
    }

    private func makeViewModel(bridgeMode: LiveRuntimeBridgeMode) -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: LiveRuntimeStore(
                effectRunner: .recording(),
                environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
            )
        )
    }
}
