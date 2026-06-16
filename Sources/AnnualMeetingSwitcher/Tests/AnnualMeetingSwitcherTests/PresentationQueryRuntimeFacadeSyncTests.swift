import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeFacadeSyncTests: XCTestCase {
    func testPresentationQueryActionsDoNotDispatchAudioInputs() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncBGMFacade() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncBGM, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncProjectionFacade() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncProjection, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncPPTFacade() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncPPT, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncAutomationNoticeFacade() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncAutomationNotice, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncSupportFacade() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncSupport, action.redactedName)
        }
    }

    func testPresentationQueryResultConsumedStillSyncsProgramQueueFacade() {
        XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: .presentationQueryResultConsumed(id: UUID())).syncProgramQueue)
    }

    private var presentationQueryActions: [LiveRuntimeAction] {
        let id = UUID()
        return [
            .operatorRequestedPresentationQuery(id: id),
            .presentationQueryCompleted(id: id, result: .empty),
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied"),
            .presentationQueryResultConsumed(id: id)
        ]
    }
}
