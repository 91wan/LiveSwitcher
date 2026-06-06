import XCTest
@testable import LiveSwitcher

final class PresentationQueryServiceTests: XCTestCase {
    func testScanKeynoteWindowNamesUsesExpectedActionName() throws {
        var capturedAction: String?
        var capturedScript: String?
        let service = PresentationQueryService(
            runAppleScript: { script, action in
                capturedScript = script
                capturedAction = action
                return NSAppleEventDescriptor.list()
            },
            scanOpenKeynoteFiles: { [] }
        )

        _ = try service.scanKeynoteWindowNames()

        XCTAssertEqual(capturedAction, "keynote.scan.windows")
        XCTAssertTrue(capturedScript?.contains("tell application \"System Events\"") == true)
        XCTAssertTrue(capturedScript?.contains("get name of every window of application process \"Keynote\"") == true)
    }

    func testScanKeynoteWindowNamesParsesDescriptorList() throws {
        let descriptor = NSAppleEventDescriptor.list()
        descriptor.insert(NSAppleEventDescriptor(string: "Opening.key"), at: 1)
        descriptor.insert(NSAppleEventDescriptor(string: "Finale.pptx"), at: 2)
        let service = PresentationQueryService(
            runAppleScript: { _, _ in descriptor },
            scanOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), ["Opening.key", "Finale.pptx"])
    }

    func testScanKeynoteWindowNamesParsesSingleString() throws {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor(string: "Solo.key") },
            scanOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), ["Solo.key"])
    }

    func testScanKeynoteWindowNamesReturnsEmptyArrayForEmptyDescriptor() throws {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor.list() },
            scanOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), [])
    }

    func testScanKeynoteWindowNamesPropagatesAppleScriptError() {
        let expected = AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "permission denied")
        let service = PresentationQueryService(
            runAppleScript: { _, _ in throw expected },
            scanOpenKeynoteFiles: { [] }
        )

        XCTAssertThrowsError(try service.scanKeynoteWindowNames()) { error in
            XCTAssertEqual(error as? AppleScriptError, expected)
        }
    }

    func testScanKeynoteWindowNamesDoesNotRecordSupport() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryService.swift"
        )

        XCTAssertFalse(source.contains("recordSupportEvent"))
        XCTAssertFalse(source.contains("showAutomationRuntimeNotice"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction"))
        XCTAssertFalse(source.contains("LiveRuntime"))
    }

    func testScanOpenKeynoteFilesUsesInjectedProvider() {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor.list() },
            scanOpenKeynoteFiles: { ["/tmp/Opening.key", "/tmp/Finale.pptx"] }
        )

        XCTAssertEqual(service.queryOpenKeynoteFiles(), ["/tmp/Opening.key", "/tmp/Finale.pptx"])
    }
}
