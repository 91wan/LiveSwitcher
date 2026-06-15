import XCTest
@testable import LiveSwitcher

final class SupportRuntimeFacadeSyncPolicyTests: XCTestCase {
    func testSupportEventRecordedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options.dispatchAudioInputsChanged)
    }

    func testSupportEventRecordedStillSyncsSupportFacade() {
        XCTAssertTrue(options.syncSupport)
    }

    func testSupportEventRecordedDoesNotSyncBGMFacade() {
        XCTAssertFalse(options.syncBGM)
    }

    func testSupportEventRecordedDoesNotSyncProjectionFacade() {
        XCTAssertFalse(options.syncProjection)
    }

    func testSupportEventRecordedDoesNotSyncPPTFacade() {
        XCTAssertFalse(options.syncPPT)
    }

    func testSupportEventRecordedDoesNotSyncAutomationNoticeFacade() {
        XCTAssertFalse(options.syncAutomationNotice)
    }

    func testSupportEventRecordedDoesNotSyncProgramQueueFacade() {
        XCTAssertFalse(options.syncProgramQueue)
    }

    func testSupportEventRecordedDoesNotSyncCurrentProgramFacade() {
        XCTAssertFalse(options.syncCurrentProgram)
    }

    func testSupportEventRecordedDoesNotSyncPanicFacade() {
        XCTAssertFalse(options.syncPanic)
    }

    func testSupportEventRecordedDoesNotSyncUnrelatedFacades() {
        XCTAssertFalse(options.syncBGM)
        XCTAssertFalse(options.syncProjection)
        XCTAssertFalse(options.syncPPT)
        XCTAssertFalse(options.syncAutomationNotice)
        XCTAssertFalse(options.syncProgramQueue)
        XCTAssertFalse(options.syncCurrentProgram)
        XCTAssertFalse(options.syncPanic)
    }

    private var options: LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncPolicy.options(for: .supportEventRecorded(supportEvent))
    }

    private var supportEvent: LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )
    }
}
