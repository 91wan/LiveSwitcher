import XCTest
@testable import LiveSwitcher

final class ProgramMonitorInfoBlockModelTests: XCTestCase {
    func testNextNilDoesNotDisplayNextBadge() {
        let model = ProgramMonitorInfoBlockModel.next(item: nil)

        XCTAssertEqual(model.value, "None")
        XCTAssertEqual(model.badgeText, "EMPTY")
        XCTAssertEqual(model.status, .idle)
    }

    func testNextExistsDisplaysNextBadge() {
        let item = ProgramItem(title: "Awards", subtitle: "MP4")
        let model = ProgramMonitorInfoBlockModel.next(item: item)

        XCTAssertEqual(model.value, "Awards")
        XCTAssertEqual(model.badgeText, "NEXT")
        XCTAssertEqual(model.status, .ready)
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
        XCTAssertEqual(onAir.badgeText, "ON AIR")
        XCTAssertEqual(onAir.status, .live)
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
}
