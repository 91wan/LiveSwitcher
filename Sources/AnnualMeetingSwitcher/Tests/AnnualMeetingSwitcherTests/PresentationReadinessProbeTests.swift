import Foundation
import XCTest
@testable import LiveSwitcher

final class PresentationReadinessProbeTests: XCTestCase {
    func testNonPresentationItemsDoNotRenderReadiness() {
        let item = ProgramItem(title: "Opening", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))

        let result = PresentationReadinessProbe.probe(item: item, environment: .fixture())

        XCTAssertEqual(result, .notPresentation)
        XCTAssertEqual(result.severity, .notApplicable)
        XCTAssertNil(result.dotLabel)
    }

    func testKeynoteReadyRequiresExistingFileInstalledAppAndAutomationAccess() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(
            existingFiles: [url],
            installedBundleIDs: [PresentationReadinessProbe.keynoteBundleIdentifier],
            automationPermission: .allowed
        )

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .ready("Keynote"))
        XCTAssertEqual(result.severity, .ready)
        XCTAssertEqual(result.dotLabel, "Ready")
    }

    func testKeynoteMissingAppIsBlocked() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(existingFiles: [url])

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .missingApp("Keynote"))
        XCTAssertEqual(result.severity, .blocked)
        XCTAssertTrue(result.operatorMessage.contains("Keynote"))
    }

    func testPPTXUsesWPSOrKeynoteFallback() {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let keynoteFallback = PresentationReadinessEnvironment.fixture(
            existingFiles: [url],
            installedBundleIDs: [PresentationReadinessProbe.keynoteBundleIdentifier],
            automationPermission: .allowed
        )
        let wpsPreferred = PresentationReadinessEnvironment.fixture(
            existingFiles: [url],
            installedBundleIDs: [
                PresentationReadinessProbe.wpsBundleIdentifier,
                PresentationReadinessProbe.keynoteBundleIdentifier
            ],
            automationPermission: .allowed
        )

        XCTAssertEqual(PresentationReadinessProbe.probe(item: item, environment: keynoteFallback), .ready("Keynote"))
        XCTAssertEqual(PresentationReadinessProbe.probe(item: item, environment: wpsPreferred), .ready("WPS Office"))
    }

    func testBrokenPresentationFileIsBlockedBeforeAppChecks() {
        let url = URL(fileURLWithPath: "/tmp/missing.pptx")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(
            installedBundleIDs: [PresentationReadinessProbe.wpsBundleIdentifier],
            automationPermission: .allowed
        )

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .fileBroken("File missing"))
        XCTAssertEqual(result.severity, .blocked)
    }

    func testInvalidPresentationFileIsBlockedBeforeAppChecks() {
        let url = URL(fileURLWithPath: "/tmp/directory.pptx")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(
            existingFiles: [url],
            invalidPresentationFiles: [url],
            installedBundleIDs: [PresentationReadinessProbe.wpsBundleIdentifier],
            automationPermission: .allowed
        )

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .fileBroken("Presentation file is invalid"))
        XCTAssertEqual(result.severity, .blocked)
    }

    func testCachedReadinessRefreshesWhenSamePathFileChanges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PresentationReadinessProbeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Deck.key")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        try Data("bad".utf8).write(to: url)
        let environment = PresentationReadinessEnvironment(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            presentationDocumentIsValid: { url, _ in
                (try? String(contentsOf: url, encoding: .utf8)) == "valid"
            },
            applicationDisplayName: { _ in "Keynote" },
            applicationInstalled: { _ in true },
            automationPermission: { _ in .allowed },
            usesCache: true
        )

        XCTAssertEqual(
            PresentationReadinessProbe.probe(item: item, environment: environment),
            .fileBroken("Presentation file is invalid")
        )

        try Data("valid".utf8).write(to: url)

        XCTAssertEqual(PresentationReadinessProbe.probe(item: item, environment: environment), .ready("Keynote"))
    }

    func testAutomationPermissionDeniedIsWarning() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(
            existingFiles: [url],
            installedBundleIDs: [PresentationReadinessProbe.keynoteBundleIdentifier],
            automationPermission: .denied
        )

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .permissionDenied("Keynote"))
        XCTAssertEqual(result.severity, .warning)
        XCTAssertTrue(result.operatorMessage.contains("Automation"))
    }

    func testSummaryCountsReadyWarningsAndBlockedPresentationItems() {
        let ready = ProgramItem(title: "Ready", sourceURL: URL(fileURLWithPath: "/tmp/ready.key"))
        let warning = ProgramItem(title: "Warn", sourceURL: URL(fileURLWithPath: "/tmp/warn.key"))
        let blocked = ProgramItem(title: "Blocked", sourceURL: URL(fileURLWithPath: "/tmp/blocked.pptx"))
        let media = ProgramItem(title: "Video", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        let environment = PresentationReadinessEnvironment { item in
            switch item.title {
            case "Ready":
                return .ready("Keynote")
            case "Warn":
                return .permissionDenied("Keynote")
            case "Blocked":
                return .missingApp("WPS Office / Keynote")
            default:
                return .notPresentation
            }
        }

        let summary = PresentationReadinessSummary.make(
            items: [ready, warning, blocked, media],
            environment: environment
        )

        XCTAssertEqual(summary.readyCount, 1)
        XCTAssertEqual(summary.warningCount, 1)
        XCTAssertEqual(summary.blockedCount, 1)
        XCTAssertEqual(summary.displayText, "1 ready · 1 warn · 1 blocked")
        XCTAssertEqual(summary.statusKind, .fail)
    }

    func testRunQueueAndLiveRailsExposeReadinessIndicators() throws {
        let runQueueSource = try sourceText("Views/RunQueueView.swift")
        let leftPanelSource = try sourceText("Views/LeftPanel.swift")
        let liveModeSource = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(runQueueSource.contains("PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))"))
        XCTAssertTrue(leftPanelSource.contains("PresentationReadinessSummary.make(items: viewModel.programItems)"))
        XCTAssertTrue(liveModeSource.contains("PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))"))
        XCTAssertTrue(liveModeSource.contains("switchToProgramAfterReadinessConfirmation(item)"))
        XCTAssertTrue(leftPanelSource.contains("switchToProgramAfterReadinessConfirmation(item)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}

private extension PresentationReadinessEnvironment {
    static func fixture(
        existingFiles: Set<URL> = [],
        invalidPresentationFiles: Set<URL> = [],
        installedBundleIDs: Set<String> = [],
        automationPermission: PresentationAutomationPermission = .unknown
    ) -> PresentationReadinessEnvironment {
        PresentationReadinessEnvironment(
            fileExists: { existingFiles.contains($0) },
            presentationDocumentIsValid: { url, _ in
                existingFiles.contains(url) && !invalidPresentationFiles.contains(url)
            },
            applicationDisplayName: { bundleID in
                bundleID == PresentationReadinessProbe.wpsBundleIdentifier ? "WPS Office" : "Keynote"
            },
            applicationInstalled: { installedBundleIDs.contains($0) },
            automationPermission: { _ in automationPermission },
            usesCache: false
        )
    }
}
