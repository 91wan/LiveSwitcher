import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeFacadeSyncPolicyTests: XCTestCase {
    func testAutomationScriptRequestedDoesNotDispatchAudioInputs() {
        XCTAssertFalse(options.dispatchAudioInputsChanged)
    }

    func testAutomationScriptRequestedDoesNotSyncBGMFacade() {
        XCTAssertFalse(options.syncBGM)
    }

    func testAutomationScriptRequestedDoesNotSyncProjectionFacade() {
        XCTAssertFalse(options.syncProjection)
    }

    func testAutomationScriptRequestedDoesNotSyncPPTFacade() {
        XCTAssertFalse(options.syncPPT)
    }

    func testAutomationScriptRequestedDoesNotSyncAutomationNoticeFacade() {
        XCTAssertFalse(options.syncAutomationNotice)
    }

    func testAutomationScriptRequestedDoesNotSyncSupportFacade() {
        XCTAssertFalse(options.syncSupport)
    }

    func testAutomationScriptRequestedDoesNotSyncProgramQueueFacade() {
        XCTAssertFalse(options.syncProgramQueue)
    }

    func testAutomationScriptRequestedDoesNotSyncCurrentProgramFacade() {
        XCTAssertFalse(options.syncCurrentProgram)
    }

    func testAutomationScriptRequestedDoesNotSyncPanicFacade() {
        XCTAssertFalse(options.syncPanic)
    }

    private var options: LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncPolicy.options(for: .automationScriptRequested(
            script: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\"",
            action: "keynote.open.present"
        ))
    }
}
