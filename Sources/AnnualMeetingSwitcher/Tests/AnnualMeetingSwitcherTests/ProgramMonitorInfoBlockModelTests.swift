import XCTest
@testable import LiveSwitcher

final class ProgramMonitorInfoBlockModelTests: XCTestCase {
    func testNextNilDoesNotDisplayNextBadge() {
        let model = ProgramMonitorInfoBlockModel.next(item: nil)

        XCTAssertEqual(model.value, "None")
        XCTAssertEqual(model.badgeText, "EMPTY")
        XCTAssertEqual(model.status, .idle)
        XCTAssertEqual(model.accessibilityLabel, "Next: None, Queue empty, EMPTY")
    }

    func testNextExistsDisplaysNextBadge() {
        let item = ProgramItem(title: "Awards", subtitle: "MP4")
        let model = ProgramMonitorInfoBlockModel.next(item: item)

        XCTAssertEqual(model.value, "Awards")
        XCTAssertEqual(model.badgeText, "NEXT")
        XCTAssertEqual(model.status, .ready)
        XCTAssertEqual(model.accessibilityLabel, "Next: Awards, MP4, NEXT")
    }

    func testCurrentNilDisplaysEmpty() {
        let model = ProgramMonitorInfoBlockModel.current(
            item: nil,
            isBroadcasting: false,
            isPlaying: false,
            isHTMLLoaded: false
        )

        XCTAssertEqual(model.value, "No Program")
        XCTAssertEqual(model.badgeText, "EMPTY")
        XCTAssertEqual(model.status, .idle)
        XCTAssertEqual(model.accessibilityLabel, "Current: No Program, Standby, EMPTY")
    }

    func testCurrentPreviewAndOnAirStates() {
        let item = ProgramItem(title: "Opening", subtitle: "MP4")

        let preview = ProgramMonitorInfoBlockModel.current(
            item: item,
            isBroadcasting: false,
            isPlaying: false,
            isHTMLLoaded: false
        )
        let onAir = ProgramMonitorInfoBlockModel.current(
            item: item,
            isBroadcasting: true,
            isPlaying: false,
            isHTMLLoaded: false
        )

        XCTAssertEqual(preview.badgeText, "PREVIEW")
        XCTAssertEqual(preview.status, .idle)
        XCTAssertEqual(preview.accessibilityLabel, "Current: Opening, MP4, PREVIEW")
        XCTAssertEqual(onAir.badgeText, "ON AIR")
        XCTAssertEqual(onAir.status, .live)
        XCTAssertEqual(onAir.accessibilityLabel, "Current: Opening, MP4, ON AIR")
    }

    func testMonitorStandbyIsIdleNotWarning() {
        let standby = ProgramMonitorStateModel.make(isBroadcasting: false, currentItem: nil)
        let preview = ProgramMonitorStateModel.make(
            isBroadcasting: false,
            currentItem: ProgramItem(title: "Opening", subtitle: "MP4")
        )
        let onAir = ProgramMonitorStateModel.make(
            isBroadcasting: true,
            currentItem: ProgramItem(title: "Opening", subtitle: "MP4")
        )

        XCTAssertEqual(standby.label, "STANDBY")
        XCTAssertEqual(standby.kind, .idle)
        XCTAssertEqual(preview.label, "PREVIEW")
        XCTAssertEqual(preview.kind, .idle)
        XCTAssertEqual(onAir.label, "ON AIR")
        XCTAssertEqual(onAir.kind, .live)
    }

    func testMonitorChromeLayoutDowngradesBeforeInlineStatusWraps() {
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 700).variant, .full)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 375).variant, .compact)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 280).variant, .stateOnly)
    }
}
