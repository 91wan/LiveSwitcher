import XCTest
@testable import LiveSwitcher

final class ProgramSelectionCompatibilityReducerTests: XCTestCase {
    func testProgramSelectionReducerOwnsFacadeCurrentProgramChanged() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeReducer.swift")

        XCTAssertTrue(source.contains("static func applyFacadeCurrentProgramChanged("))
        XCTAssertTrue(source.contains("state.program.currentID = id"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)"))
        XCTAssertTrue(source.contains("effects.append(.applyAudioRouting(reason: .programChanged))"))
    }

    func testLiveRuntimeReducerRoutesFacadeCurrentProgramChanged() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        assertCase(
            ".facadeCurrentProgramChanged(let id)",
            in: source,
            contains: [
                "guard isRuntimeOwned(.programSelection, in: bridgeMode) else { break }",
                "ProgramSelectionRuntimeReducer.applyFacadeCurrentProgramChanged("
            ]
        )
    }

    func testLiveRuntimeReducerDoesNotOwnFacadeCurrentProgramChangedMutationBody() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let body = try caseBody(".facadeCurrentProgramChanged(let id)", in: source)

        XCTAssertFalse(body.contains("state.program.currentID ="))
        XCTAssertFalse(body.contains("state.program.currentDetachedItem ="))
        XCTAssertFalse(body.contains("state.program.currentSwitchedAt ="))
        XCTAssertFalse(body.contains("state.audio.routingContext.isCurrentProgramMediaSource ="))
        XCTAssertFalse(body.contains("AudioRuntimeReducer.recalculateAudio"))
    }

    func testFacadeCurrentProgramChangedBehaviorRemainsOwnedAndCompatibilityOnly() {
        let state = programState()
        let newID = state.program.items[1].id

        let mutation = reduce(state, .facadeCurrentProgramChanged(newID), bridgeMode: .programSelectionOwned)

        XCTAssertEqual(mutation.state.program.currentID, newID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertEqual(mutation.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 100))
        XCTAssertTrue(mutation.state.audio.routingContext.isCurrentProgramMediaSource)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.facadeCurrentProgramChanged(newID)))
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
        contains expectedParts: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let body = try caseBody(casePattern, in: source)
            for expected in expectedParts {
                XCTAssertTrue(body.contains(expected), expected, file: file, line: line)
            }
        } catch {
            XCTFail(String(describing: error), file: file, line: line)
        }
    }

    private func caseBody(_ casePattern: String, in source: String) throws -> String {
        guard let range = source.range(of: "case \(casePattern):") else {
            throw NSError(domain: "Missing case \(casePattern)", code: 1)
        }
        let nextCase = source[range.upperBound...].range(of: "\n        case ")
        let end = nextCase?.lowerBound ?? source.endIndex
        return String(source[range.lowerBound..<end])
    }
}
