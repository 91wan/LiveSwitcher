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
        XCTAssertEqual(result.dotLabel, "就绪")
        XCTAssertEqual(result.operatorMessage, "Keynote 已就绪。")
    }

    func testKeynoteMissingAppIsBlocked() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", sourceURL: url)
        let environment = PresentationReadinessEnvironment.fixture(existingFiles: [url])

        let result = PresentationReadinessProbe.probe(item: item, environment: environment)

        XCTAssertEqual(result, .missingApp("Keynote"))
        XCTAssertEqual(result.severity, .blocked)
        XCTAssertEqual(result.dotLabel, "不可用")
        XCTAssertEqual(result.operatorMessage, "未安装 Keynote。")
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

        XCTAssertEqual(result, .fileBroken("文件缺失。"))
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

        XCTAssertEqual(result, .fileBroken("演示文件缺失或损坏。"))
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
            .fileBroken("演示文件缺失或损坏。")
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
        XCTAssertEqual(result.dotLabel, "需检查")
        XCTAssertEqual(result.operatorMessage, "Keynote 自动化权限被拒绝，请在系统设置中允许。")
    }

    func testReadinessUserFacingCopyIsChinese() {
        let ready = PresentationReadinessResult.ready("Keynote")
        let missingApp = PresentationReadinessResult.missingApp("WPS Office / Keynote")
        let denied = PresentationReadinessResult.permissionDenied("Keynote")
        let unknown = PresentationReadinessResult.unknown("Keynote 自动化权限未确认。")

        XCTAssertEqual(ready.dotLabel, "就绪")
        XCTAssertEqual(missingApp.dotLabel, "不可用")
        XCTAssertEqual(denied.dotLabel, "需检查")
        XCTAssertEqual(unknown.dotLabel, "需检查")

        for result in [ready, missingApp, denied, unknown] {
            XCTAssertFalse(result.operatorMessage.contains("Ready"))
            XCTAssertFalse(result.operatorMessage.contains("Review"))
            XCTAssertFalse(result.operatorMessage.contains("Blocked"))
            XCTAssertFalse(result.operatorMessage.localizedStandardContains("automation permission"))
            XCTAssertFalse(result.operatorMessage.localizedStandardContains("is not installed"))
        }
    }

    func testRunQueueAndLiveRailsExposeReadinessIndicatorsWithoutLeftSummary() throws {
        let runQueueSource = try sourceText("Views/RunQueueView.swift")
        let leftPanelSource = try sourceText("Views/LeftPanel.swift")
        let liveModeSource = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(runQueueSource.contains("PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))"))
        XCTAssertFalse(leftPanelSource.contains("PresentationReadinessSummary"))
        XCTAssertFalse(leftPanelSource.contains("presentationReadinessSummaryRow"))
        XCTAssertTrue(liveModeSource.contains("PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))"))
        XCTAssertTrue(liveModeSource.contains("switchToProgramAfterReadinessConfirmation(item)"))
        XCTAssertTrue(leftPanelSource.contains("switchToProgramAfterReadinessConfirmation(item)"))
    }

    func testProductionReadinessSourceDoesNotKeepDeadSummaryModelOrEnglishStatusCopy() throws {
        let source = try sourceText("Engines/PresentationReadinessProbe.swift")

        XCTAssertFalse(source.contains("struct PresentationReadinessSummary"))
        XCTAssertFalse(source.contains("return \"Ready\""))
        XCTAssertFalse(source.contains("return \"Review\""))
        XCTAssertFalse(source.contains("return \"Blocked\""))
        XCTAssertFalse(source.localizedStandardContains("automation permission is not confirmed"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
