import XCTest
@testable import LiveSwitcher

final class AudioTransitionControlModelTests: XCTestCase {
    func testTransitionCardTextDescribesProgramTransitionNotBGMFade() {
        let model = ProgramTransitionControlModel(crossfadeDuration: 1.2)

        XCTAssertEqual(model.title, "Program transition")
        XCTAssertFalse(model.title.localizedCaseInsensitiveContains("BGM fade"))
        XCTAssertFalse(model.subtitle.localizedCaseInsensitiveContains("BGM fade"))
        XCTAssertTrue(model.subtitle.contains("节目画面"))
        XCTAssertEqual(model.statusText, "1.2s")
    }
}
