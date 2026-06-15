import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeFacadeSyncPolicyTests: XCTestCase {
    func testPreferenceActionsDoNotDispatchAudioInputs() {
        for action in preferenceActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testPreferenceActionsDoNotSyncBGMFacade() {
        assertPreferenceActionsDoNotSync(\.syncBGM)
    }

    func testPreferenceActionsDoNotSyncProjectionFacade() {
        assertPreferenceActionsDoNotSync(\.syncProjection)
    }

    func testPreferenceActionsDoNotSyncPPTFacade() {
        assertPreferenceActionsDoNotSync(\.syncPPT)
    }

    func testPreferenceActionsDoNotSyncAutomationNoticeFacade() {
        assertPreferenceActionsDoNotSync(\.syncAutomationNotice)
    }

    func testPreferenceActionsDoNotSyncSupportFacade() {
        assertPreferenceActionsDoNotSync(\.syncSupport)
    }

    func testPreferenceActionsDoNotSyncProgramQueueFacade() {
        assertPreferenceActionsDoNotSync(\.syncProgramQueue)
    }

    func testPreferenceActionsDoNotSyncCurrentProgramFacade() {
        assertPreferenceActionsDoNotSync(\.syncCurrentProgram)
    }

    func testPreferenceActionsDoNotSyncPanicFacade() {
        assertPreferenceActionsDoNotSync(\.syncPanic)
    }

    func testPreferenceActionsDoNotSyncUnrelatedFacades() {
        for action in preferenceActions {
            let options = LiveRuntimeFacadeSyncPolicy.options(for: action)

            XCTAssertFalse(options.syncBGM, action.redactedName)
            XCTAssertFalse(options.syncProjection, action.redactedName)
            XCTAssertFalse(options.syncPPT, action.redactedName)
            XCTAssertFalse(options.syncAutomationNotice, action.redactedName)
            XCTAssertFalse(options.syncSupport, action.redactedName)
            XCTAssertFalse(options.syncProgramQueue, action.redactedName)
            XCTAssertFalse(options.syncCurrentProgram, action.redactedName)
            XCTAssertFalse(options.syncPanic, action.redactedName)
        }
    }

    private var preferenceActions: [LiveRuntimeAction] {
        [
            .operatorSetConsoleMode(.live),
            .operatorSetThemeOverride(.system),
            .operatorSetActiveWallpaperURL(URL(fileURLWithPath: "/tmp/wallpaper.png")),
            .operatorSetCornerLogoURL(URL(fileURLWithPath: "/tmp/logo.png")),
            .operatorSetAutoPlayNextVideoOnEnd(true),
            .operatorSetAutoAdvanceAtScheduledTime(true),
            .operatorSetShowAgendaTimeline(true),
            .operatorSetCornerLogoPosition(.bottomLeft)
        ]
    }

    private func assertPreferenceActionsDoNotSync(
        _ keyPath: KeyPath<LiveRuntimeFacadeSyncOptions, Bool>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for action in preferenceActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action)[keyPath: keyPath], action.redactedName, file: file, line: line)
        }
    }
}
