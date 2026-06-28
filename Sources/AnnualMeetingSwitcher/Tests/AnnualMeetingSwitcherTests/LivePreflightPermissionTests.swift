import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightPermissionTests: XCTestCase {
    func testNoExternalDisplayIsNotReadyAndWarnsAgainstProjection() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.externalScreenProvider = { nil }

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let display = livePreflightCheck("display.external", in: checks)

        XCTAssertEqual(display.group, .display)
        XCTAssertEqual(display.status, .fail)
        XCTAssertEqual(display.actionKind, .needsHardware)
        XCTAssertEqual(display.actionLabel, "需要硬件")
        XCTAssertTrue(display.message.localizedStandardContains("需要硬件"))
        XCTAssertTrue(display.message.localizedStandardContains("请勿投射"))

        let beforeSnapshot = viewModel.livePreflightSnapshot
        XCTAssertFalse(viewModel.performLivePreflightAction(.needsHardware))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testExternalDisplayPresentPassesDisplayReadiness() {
        let viewModel = makeLivePreflightTestViewModel()

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let display = livePreflightCheck("display.external", in: checks)

        XCTAssertEqual(display.group, .display)
        XCTAssertEqual(display.status, .pass)
        XCTAssertTrue(display.message.localizedStandardContains("已检测到外接显示器"))
    }

    func testNavigationActionsDoNotMutateViewModelState() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.startTicker(text: "Welcome")
        let beforeSnapshot = viewModel.livePreflightSnapshot

        XCTAssertFalse(viewModel.performLivePreflightAction(.openPreview))
        XCTAssertFalse(viewModel.performLivePreflightAction(.openAudioMixer))
        XCTAssertFalse(viewModel.performLivePreflightAction(.openOverlays))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testSafetyCockpitNoExternalDisplayCreatesNotReadyDisplayCard() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false
        let checks = LivePreflightCheck.build(from: snapshot)

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: []
        )
        let displaySection = cockpit.sections.first { $0.group == .display }

        XCTAssertEqual(cockpit.summary.title, "未就绪")
        XCTAssertNotNil(displaySection)
        XCTAssertTrue(displaySection?.checks.contains { check in
            check.id == "display.external" &&
                check.status == .fail &&
                check.actionKind == .needsHardware
        } ?? false)
    }

    func testPreflightNavigationActionsMapToMainConsoleTabs() {
        XCTAssertEqual(LivePreflightActionKind.openPreview.mainConsoleDestination, .preview)
        XCTAssertEqual(LivePreflightActionKind.openAudioMixer.mainConsoleDestination, .audioMixer)
        XCTAssertEqual(LivePreflightActionKind.openOverlays.mainConsoleDestination, .overlays)
    }

    func testSafeMutatingAndManualPreflightActionsDoNotMapToMainConsoleTabs() {
        XCTAssertNil(LivePreflightActionKind.clearOverlays.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.turnOffPanic.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.needsHardware.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.manualReview.mainConsoleDestination)
    }

    func testPreflightActionPresentationSeparatesButtonsFromGuidance() {
        XCTAssertEqual(LivePreflightActionKind.clearOverlays.presentationRole, .safeOneClick)
        XCTAssertEqual(LivePreflightActionKind.turnOffPanic.presentationRole, .safeOneClick)
        XCTAssertEqual(LivePreflightActionKind.openPreview.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.openAudioMixer.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.openOverlays.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.needsHardware.presentationRole, .operatorGuidance)
        XCTAssertEqual(LivePreflightActionKind.manualReview.presentationRole, .operatorGuidance)

        XCTAssertTrue(LivePreflightActionKind.clearOverlays.shouldRenderAsButton)
        XCTAssertTrue(LivePreflightActionKind.openPreview.shouldRenderAsButton)
        XCTAssertFalse(LivePreflightActionKind.needsHardware.shouldRenderAsButton)
        XCTAssertFalse(LivePreflightActionKind.manualReview.shouldRenderAsButton)
    }
}
