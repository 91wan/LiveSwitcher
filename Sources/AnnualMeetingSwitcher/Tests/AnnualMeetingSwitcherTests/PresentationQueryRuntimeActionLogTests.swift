import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimeActionLogTests: XCTestCase {
    func testOperatorRequestedPresentationQueryActionLogPolicyUnchanged() {
        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.operatorRequestedPresentationQuery(id: UUID())))
    }

    func testPresentationQueryCompletedIsNotLogged() {
        let id = UUID()
        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryCompleted(id: id, result: .empty)))
    }

    func testPresentationQueryResultConsumedIsNotLogged() {
        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryResultConsumed(id: UUID())))
    }

    func testPresentationQueryFailedActionLogPolicyUnchanged() {
        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryFailed(
            id: UUID(),
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        )))
    }

    func testPresentationQueryFailureSanitizedMessageDoesNotLeakIntoActionLog() {
        let id = UUID()
        let runtime = runtime()

        runtime.dispatch(.operatorRequestedPresentationQuery(id: id))
        runtime.dispatch(.presentationQueryFailed(
            id: id,
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied/private/path"
        ))

        XCTAssertFalse(actionLogText(runtime).contains("permissionDenied/private/path"))
    }

    func testPresentationQueryResultTitleDoesNotLeakIntoActionLog() {
        let id = UUID()
        let runtime = runtime()

        runtime.dispatch(.operatorRequestedPresentationQuery(id: id))
        runtime.dispatch(.presentationQueryCompleted(
            id: id,
            result: PresentationQueryResult(openFilePaths: ["/tmp/private/Opening.key"], windowNames: ["Opening.key"])
        ))

        XCTAssertFalse(actionLogText(runtime).contains("Opening.key"))
        XCTAssertFalse(actionLogText(runtime).contains("/tmp/private"))
    }

    private func runtime() -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )
    }

    private func actionLogText(_ runtime: LiveRuntimeStore) -> String {
        runtime.actionLog
            .flatMap { [$0.actionName, $0.oldStateSummary, $0.newStateSummary] }
            .joined(separator: "\n")
    }
}
