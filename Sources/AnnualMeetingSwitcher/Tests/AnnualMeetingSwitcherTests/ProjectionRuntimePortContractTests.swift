import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimePortContractTests: XCTestCase {
    func testProjectionPortRequiresExplicitStartStop() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift")

        XCTAssertTrue(source.contains("func start()"))
        XCTAssertTrue(source.contains("func stop()"))
        XCTAssertFalse(source.contains("extension ProjectionPort"))
    }

    func testProjectionStartDoesNotAlsoEmitShowOutputWindow() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertEqual(mutation.effects, [.startProjection])
    }

    func testProjectionStopDoesNotAlsoEmitHideOutputWindow() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertEqual(mutation.effects, [.stopProjection])
    }

    func testProjectionStartEffectCallsStartOnly() {
        let projection = ProjectionRuntimePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.startProjection], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["start"])
    }

    func testProjectionStopEffectCallsStopOnly() {
        let projection = ProjectionRuntimePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.stopProjection], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["stop"])
    }

    func testLegacyShowHideEffectsRemainSeparate() {
        let projection = ProjectionRuntimePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.showOutputWindow, .hideOutputWindow], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["show", "hide"])
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class ProjectionRuntimePortSpy: ProjectionPort {
    var calls: [String] = []
    var hasExternalDisplay: Bool = true

    func start() { calls.append("start") }
    func stop() { calls.append("stop") }
    func show() { calls.append("show") }
    func hide() { calls.append("hide") }
}
