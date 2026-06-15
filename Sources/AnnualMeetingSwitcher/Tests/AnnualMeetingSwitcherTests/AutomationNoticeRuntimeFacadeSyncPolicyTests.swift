import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeFacadeSyncPolicyTests: XCTestCase {
    func testAutomationFailedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options(for: .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed")).dispatchAudioInputsChanged)
    }

    func testAutomationNoticeRequestedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options(for: .automationNoticeRequested(action: "keynote.next-slide")).dispatchAudioInputsChanged)
    }

    func testAutomationNoticeExpiredDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options(for: .automationNoticeExpired(UUID())).dispatchAudioInputsChanged)
    }

    func testAutomationNoticeDismissedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options(for: .automationNoticeDismissed).dispatchAudioInputsChanged)
    }

    func testAutomationNoticeActionsStillSyncAutomationNoticeFacade() {
        automationNoticeActions.forEach { action in
            XCTAssertTrue(options(for: action).syncAutomationNotice, "\(action.redactedName) should sync automation notice facade")
        }
    }

    func testAutomationNoticeActionsDoNotSyncUnrelatedFacades() {
        automationNoticeActions.forEach { action in
            let options = options(for: action)
            XCTAssertFalse(options.syncBGM)
            XCTAssertFalse(options.syncProjection)
            XCTAssertFalse(options.syncPPT)
            XCTAssertFalse(options.syncSupport)
            XCTAssertFalse(options.syncProgramQueue)
            XCTAssertFalse(options.syncCurrentProgram)
            XCTAssertFalse(options.syncPanic)
        }
    }

    private var automationNoticeActions: [LiveRuntimeAction] {
        [
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            .automationNoticeRequested(action: "keynote.next-slide"),
            .automationNoticeExpired(UUID()),
            .automationNoticeDismissed
        ]
    }

    private func options(for action: LiveRuntimeAction) -> LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncPolicy.options(for: action)
    }
}
