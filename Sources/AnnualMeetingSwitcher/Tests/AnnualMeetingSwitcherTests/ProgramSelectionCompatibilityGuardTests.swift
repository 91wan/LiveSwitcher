import XCTest
@testable import LiveSwitcher

final class ProgramSelectionCompatibilityGuardTests: XCTestCase {
    func testFacadeCurrentProgramChangedNoopsBeforeProgramSelectionOwnership() {
        let state = programState()
        let mutation = reduce(state, .facadeCurrentProgramChanged(state.program.items[1].id), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program, state.program)
        XCTAssertEqual(mutation.state.audio, state.audio)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testFacadeCurrentProgramChangedDoesNotMutateCurrentIDBeforeOwnership() {
        let state = programState()
        let mutation = reduce(state, .facadeCurrentProgramChanged(state.program.items[1].id), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.currentID, state.program.currentID)
    }

    func testFacadeCurrentProgramChangedDoesNotEmitAudioRoutingBeforeOwnership() {
        let state = programState()
        let mutation = reduce(state, .facadeCurrentProgramChanged(state.program.items[1].id), bridgeMode: .programQueueOwned)

        XCTAssertFalse(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
    }

    func testFacadeCurrentProgramChangedMutatesWhenProgramSelectionOwned() {
        let state = programState()
        let newID = state.program.items[1].id
        let mutation = reduce(state, .facadeCurrentProgramChanged(newID), bridgeMode: .programSelectionOwned)

        XCTAssertEqual(mutation.state.program.currentID, newID)
    }

    func testFacadeCurrentProgramChangedStillClearsDetachedItemWhenNeeded() {
        let state = programStateWithDetachedCurrent()
        let queuedID = state.program.items[0].id
        let mutation = reduce(state, .facadeCurrentProgramChanged(queuedID), bridgeMode: .programSelectionOwned)

        XCTAssertNil(mutation.state.program.currentDetachedItem)
    }

    func testFacadeCurrentProgramChangedStillUpdatesSwitchedAtWhenOwned() {
        let state = programState()
        let newID = state.program.items[1].id
        let mutation = reduce(state, .facadeCurrentProgramChanged(newID), bridgeMode: .programSelectionOwned)

        XCTAssertEqual(mutation.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 100))
    }

    func testFacadeCurrentProgramChangedStillAppliesAudioRoutingWhenOwned() {
        let state = programState()
        let mutation = reduce(state, .facadeCurrentProgramChanged(state.program.items[1].id), bridgeMode: .programSelectionOwned)

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
    }

    func testFacadeCurrentProgramChangedIsStillCompatibilityOnly() {
        let action = LiveRuntimeAction.facadeCurrentProgramChanged(UUID())

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(action))
    }

    func testFacadeCurrentProgramChangedCaseHasExplicitProgramSelectionOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        assertCase(
            ".facadeCurrentProgramChanged(let id)",
            in: source,
            contains: "guard isRuntimeOwned(.programSelection, in: bridgeMode) else { break }"
        )
    }

    private func programState() -> LiveRuntimeState {
        let first = ProgramItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "First",
            subtitle: "MEDIA",
            sourceURL: URL(fileURLWithPath: "/tmp/first.mp4")
        )
        let second = ProgramItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Second",
            subtitle: "MEDIA",
            sourceURL: URL(fileURLWithPath: "/tmp/second.mp4")
        )
        var state = LiveRuntimeState()
        state.program.items = [first, second]
        state.program.currentID = first.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)
        state.audio.routingContext.isCurrentProgramMediaSource = true
        return state
    }

    private func programStateWithDetachedCurrent() -> LiveRuntimeState {
        var state = programState()
        let detached = ProgramItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Detached",
            subtitle: "MEDIA",
            sourceURL: URL(fileURLWithPath: "/tmp/detached.mp4")
        )
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached
        return state
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func assertCase(
        _ casePattern: String,
        in source: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let range = source.range(of: "case \(casePattern):") else {
            return XCTFail("Missing case \(casePattern)", file: file, line: line)
        }
        let endIndex = source.index(range.lowerBound, offsetBy: 460, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains(expected), "Missing program selection ownership guard", file: file, line: line)
    }
}
