import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeOwnershipGuardTests: XCTestCase {
    func testPresentationQueryActionsNoopBeforePresentationQueryOwnership() {
        for (state, action) in preOwnershipScenarios {
            let mutation = reduce(state, action, bridgeMode: .automationCommandOwned)

            XCTAssertEqual(mutation.state.presentationQuery, state.presentationQuery, action.redactedName)
            XCTAssertTrue(mutation.effects.isEmpty, action.redactedName)
        }
    }

    func testPresentationQueryActionsMutateWhenPresentationQueryOwned() {
        for (state, action) in ownedMutationScenarios {
            let mutation = reduce(state, action, bridgeMode: .presentationQueryOwned)

            XCTAssertNotEqual(mutation.state.presentationQuery, state.presentationQuery, action.redactedName)
        }
    }

    func testPresentationQueryCallbacksNoopBeforePresentationQueryOwnership() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        for action in [
            LiveRuntimeAction.presentationQueryCompleted(id: id, result: .empty),
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
        ] {
            let mutation = reduce(state, action, bridgeMode: .automationCommandOwned)

            XCTAssertEqual(mutation.state.presentationQuery, state.presentationQuery, action.redactedName)
            XCTAssertTrue(mutation.effects.isEmpty, action.redactedName)
        }
    }

    func testAllPresentationQueryCasesHaveExplicitPresentationQueryOwnershipGuard() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/AutomationRuntimeActionDispatcher.swift"
        )

        for casePattern in [
            ".operatorRequestedPresentationQuery(let id)",
            ".presentationQueryCompleted(let id, let result)",
            ".presentationQueryFailed(let id, let action, let sanitizedMessage)",
            ".presentationQueryResultConsumed(let id)"
        ] {
            let body = try caseBody(casePattern, in: source)
            XCTAssertTrue(
                body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.presentationQuery, in: bridgeMode) else { return true }"),
                casePattern
            )
        }
    }

    private var preOwnershipScenarios: [(LiveRuntimeState, LiveRuntimeAction)] {
        let id = UUID()
        var active = LiveRuntimeState()
        active.presentationQuery.activeRequestID = id
        return [
            (LiveRuntimeState(), .operatorRequestedPresentationQuery(id: id)),
            (active, .presentationQueryCompleted(id: id, result: .empty)),
            (active, .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")),
            (LiveRuntimeState(), .presentationQueryResultConsumed(id: id))
        ]
    }

    private var ownedMutationScenarios: [(LiveRuntimeState, LiveRuntimeAction)] {
        let id = UUID()
        var activeForComplete = LiveRuntimeState()
        activeForComplete.presentationQuery.activeRequestID = id
        var activeForFailure = LiveRuntimeState()
        activeForFailure.presentationQuery.activeRequestID = id
        return [
            (LiveRuntimeState(), .operatorRequestedPresentationQuery(id: id)),
            (activeForComplete, .presentationQueryCompleted(id: id, result: .empty)),
            (activeForFailure, .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")),
            (LiveRuntimeState(), .presentationQueryResultConsumed(id: id))
        ]
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
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
