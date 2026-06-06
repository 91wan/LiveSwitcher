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
            queryOpenKeynoteFiles: { [] }
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
            queryOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), ["Opening.key", "Finale.pptx"])
    }

    func testScanKeynoteWindowNamesParsesSingleString() throws {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor(string: "Solo.key") },
            queryOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), ["Solo.key"])
    }

    func testScanKeynoteWindowNamesReturnsEmptyArrayForEmptyDescriptor() throws {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor.list() },
            queryOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), [])
    }

    func testScanKeynoteWindowNamesPropagatesAppleScriptError() {
        let expected = AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "permission denied")
        let service = PresentationQueryService(
            runAppleScript: { _, _ in throw expected },
            queryOpenKeynoteFiles: { [] }
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

    func testPresentationQueryServiceDoesNotReferenceKeynoteController() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryService.swift"
        )

        XCTAssertFalse(source.contains("KeynoteController"))
        XCTAssertFalse(source.contains("init(keynoteController:"))
    }

    func testPresentationQueryServiceUsesInjectedAppleScriptRunner() throws {
        var didRunAppleScript = false
        let service = PresentationQueryService(
            runAppleScript: { _, _ in
                didRunAppleScript = true
                return NSAppleEventDescriptor(string: "Opening.key")
            },
            queryOpenKeynoteFiles: { [] }
        )

        XCTAssertEqual(try service.scanKeynoteWindowNames(), ["Opening.key"])
        XCTAssertTrue(didRunAppleScript)
    }

    func testPresentationQueryServiceUsesInjectedOpenFileProvider() {
        let service = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor.list() },
            queryOpenKeynoteFiles: { ["/tmp/Opening.key", "/tmp/Finale.pptx"] }
        )

        XCTAssertEqual(service.queryOpenKeynoteFiles(), ["/tmp/Opening.key", "/tmp/Finale.pptx"])
    }

    func testScanPresentationQueryScansWindowNamesBeforeOpenFiles() throws {
        var events: [String] = []
        let service = PresentationQueryService(
            runAppleScript: { _, _ in
                events.append("windows")
                return NSAppleEventDescriptor(string: "Opening.key")
            },
            queryOpenKeynoteFiles: {
                events.append("files")
                return ["/tmp/show/Opening.key"]
            }
        )

        let result = try service.scanPresentationQuery()

        XCTAssertEqual(events, ["windows", "files"])
        XCTAssertEqual(result, PresentationQueryResult(
            openFilePaths: ["/tmp/show/Opening.key"],
            windowNames: ["Opening.key"]
        ))
    }

    func testScanPresentationQueryPropagatesWindowScanFailure() {
        let expected = AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "failed")
        let service = PresentationQueryService(
            runAppleScript: { _, _ in throw expected },
            queryOpenKeynoteFiles: { ["/tmp/show/Opening.key"] }
        )

        XCTAssertThrowsError(try service.scanPresentationQuery()) { error in
            XCTAssertEqual(error as? AppleScriptError, expected)
        }
    }

    func testScanPresentationQueryDoesNotQueryOpenFilesWhenWindowScanFails() {
        var didQueryOpenFiles = false
        let service = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "failed")
            },
            queryOpenKeynoteFiles: {
                didQueryOpenFiles = true
                return []
            }
        )

        XCTAssertThrowsError(try service.scanPresentationQuery())
        XCTAssertFalse(didQueryOpenFiles)
    }
}
