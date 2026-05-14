import XCTest
@testable import LiveSwitcher

final class AppleScriptSupportTests: XCTestCase {
    func testQuotedStringEscapesQuotesBackslashesAndPreservesSpaces() {
        let path = "/tmp/show files/keynote \"final\" \\ deck.key"

        XCTAssertEqual(
            AppleScriptSupport.quotedString(path),
            "\"/tmp/show files/keynote \\\"final\\\" \\\\ deck.key\""
        )
    }

    func testPOSIXFileExpressionUsesEscapedQuotedPath() {
        let path = "/tmp/show files/keynote \"final\" \\ deck.key"

        XCTAssertEqual(
            AppleScriptSupport.posixFileExpression(path: path),
            "POSIX file \"/tmp/show files/keynote \\\"final\\\" \\\\ deck.key\""
        )
    }

    func testPresentationAutomationScriptsUseSharedPOSIXFileEscaping() {
        let url = URL(fileURLWithPath: "/tmp/show files/keynote \"final\" \\ deck.key")

        let keynoteScript = PresentationAutomationService.keynoteStartScript(url: url)
        let wpsScript = PresentationAutomationService.wpsOpenScript(url: url)

        XCTAssertTrue(keynoteScript.contains("open POSIX file \"/tmp/show files/keynote \\\"final\\\" \\\\ deck.key\""))
        XCTAssertTrue(wpsScript.contains("open POSIX file \"/tmp/show files/keynote \\\"final\\\" \\\\ deck.key\""))
        XCTAssertFalse(keynoteScript.contains("open POSIX file \"\\(path)\""))
        XCTAssertFalse(wpsScript.contains("open POSIX file \"\\(path)\""))
    }
}
