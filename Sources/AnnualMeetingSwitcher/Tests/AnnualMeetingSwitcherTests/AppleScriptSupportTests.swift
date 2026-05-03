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
}
