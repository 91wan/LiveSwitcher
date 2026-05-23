import XCTest
@testable import LiveSwitcher

final class PreflightActionRoutingModelTests: XCTestCase {
    func testSafeOneClickActionsStayInPopoverAndMutateState() {
        let clear = PreflightActionRoutingModel.make(action: .clearOverlays)
        let panic = PreflightActionRoutingModel.make(action: .turnOffPanic)

        XCTAssertFalse(clear.shouldDismissPopover)
        XCTAssertTrue(clear.shouldMutateState)
        XCTAssertNil(clear.destinationTab)
        XCTAssertFalse(panic.shouldDismissPopover)
        XCTAssertTrue(panic.shouldMutateState)
        XCTAssertNil(panic.destinationTab)
    }

    func testNavigationActionsDismissAndRouteToTabs() {
        let preview = PreflightActionRoutingModel.make(action: .openPreview)
        let audio = PreflightActionRoutingModel.make(action: .openAudioMixer)
        let overlays = PreflightActionRoutingModel.make(action: .openOverlays)

        XCTAssertTrue(preview.shouldDismissPopover)
        XCTAssertFalse(preview.shouldMutateState)
        XCTAssertEqual(preview.destinationTab, .preview)
        XCTAssertEqual(audio.destinationTab, .audioMixer)
        XCTAssertEqual(overlays.destinationTab, .overlays)
    }

    func testGuidanceActionsStayOpenWithoutMutation() {
        let hardware = PreflightActionRoutingModel.make(action: .needsHardware)
        let manual = PreflightActionRoutingModel.make(action: .manualReview)

        XCTAssertFalse(hardware.shouldDismissPopover)
        XCTAssertFalse(hardware.shouldMutateState)
        XCTAssertNil(hardware.destinationTab)
        XCTAssertFalse(manual.shouldDismissPopover)
        XCTAssertFalse(manual.shouldMutateState)
        XCTAssertNil(manual.destinationTab)
    }
}
