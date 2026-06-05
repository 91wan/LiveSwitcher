import XCTest

final class ViewModelLiveOutputEncapsulationTests: XCTestCase {
    func testOutputWindowControllerIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private var outputWindowController: OutputWindowControlling?"))
        XCTAssertFalse(source.contains("\n    var outputWindowController: OutputWindowControlling?"))
    }

    func testExternalDisplayAvailabilityIsPrivateSet() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private(set) var isExternalDisplayAvailable: Bool = false"))
        XCTAssertFalse(source.contains("\n    var isExternalDisplayAvailable: Bool = false"))
    }

    func testProjectionOutputExtensionUsesProjectionOutputAccessors() throws {
        let source = try projectionOutputSource()

        [
            "updateExternalDisplayAvailabilityForProjection(isAvailable)",
            "currentOutputWindowControllerForProjection()",
            "makeOutputWindowControllerForProjection()",
            "setOutputWindowControllerForProjection(controller)",
            "currentOutputWindowControllerForProjection()?.show",
            "currentOutputWindowControllerForProjection()?.hide"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testOnlyProjectionOutputFileTouchesOutputWindowController() throws {
        let offenders = try sourceFiles(containing: "outputWindowController")
            .filter { !$0.hasSuffix("ViewModel.swift") }
            .filter { !$0.hasSuffix("ViewModel+ProjectionOutput.swift") }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func testOnlyProjectionOutputFileMutatesExternalDisplayAvailability() throws {
        let offenders = try viewModelSourceFiles().flatMap { path -> [String] in
            try repositorySource(path)
                .split(separator: "\n")
                .map(String.init)
                .filter { line in
                    line.contains("isExternalDisplayAvailable =")
                        && !line.contains("private(set) var isExternalDisplayAvailable")
                        && !path.hasSuffix("ViewModel.swift")
                        && !path.hasSuffix("ViewModel+ProjectionOutput.swift")
                }
                .map { "\(path): \($0.trimmingCharacters(in: .whitespaces))" }
        }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func testPageInterceptEventTapIsNotBroadMutableViewModelState() throws {
        try assertPrivateViewModelStorage("pageInterceptEventTap: CFMachPort?")
    }

    func testPageInterceptRunLoopSourceIsNotBroadMutableViewModelState() throws {
        try assertPrivateViewModelStorage("pageInterceptRunLoopSource: CFRunLoopSource?")
    }

    func testPageInterceptSelfRefconIsNotBroadMutableViewModelState() throws {
        try assertPrivateViewModelStorage("pageInterceptSelfRefcon: UnsafeMutableRawPointer?")
    }

    func testPendingPPTToggleSourceIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored private var pendingPPTToggleSource: PPTModeToggleSource?"))
        XCTAssertFalse(source.contains("@ObservationIgnored var pendingPPTToggleSource: PPTModeToggleSource?"))
    }

    func testPageInterceptRuntimeIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("nonisolated private let pageInterceptRuntime = PageInterceptRuntime()"))
        XCTAssertFalse(source.contains("nonisolated let pageInterceptRuntime = PageInterceptRuntime()"))
    }

    func testWPSApplicationMonitorIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("nonisolated private let wpsApplicationMonitor = WPSApplicationMonitor()"))
        XCTAssertFalse(source.contains("nonisolated let wpsApplicationMonitor = WPSApplicationMonitor()"))
    }

    func testPPTEventTapExtensionUsesNarrowTapAccessors() throws {
        let source = try pptEventTapSource()

        [
            "currentPendingPPTToggleSource()",
            "consumePendingPPTToggleSource()",
            "currentPageInterceptTapForRuntime()",
            "enableCurrentPageInterceptTapForRuntime()",
            "installPageInterceptTapForRuntime(",
            "clearPageInterceptTapForRuntime()",
            "updatePageInterceptRuntimeTap(",
            "currentWPSProcessIdentifierForPageForwarding()"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testOnlyPPTEventTapFileTouchesRawEventTapStorage() throws {
        let rawStorageNames = [
            "pageInterceptEventTap",
            "pageInterceptRunLoopSource",
            "pageInterceptSelfRefcon",
            "pageInterceptRuntime",
            "wpsApplicationMonitor"
        ]
        let offenders = try viewModelSourceFiles().flatMap { path -> [String] in
            guard !path.hasSuffix("ViewModel.swift"),
                  !path.hasSuffix("ViewModel+PPTEventTap.swift")
            else { return [] }
            let source = try repositorySource(path)
            return rawStorageNames
                .filter { source.contains($0) }
                .map { "\(path): \($0)" }
        }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func testRuntimeSnapshotStillUsesReadOnlyTapActiveAccessor() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")

        XCTAssertTrue(source.contains("state.ppt.isEventTapActive = isPageInterceptEventTapActiveForRuntimeSnapshot"))
    }

    func testBGMTransitionGenerationIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private var bgmTransitionGeneration: Int = 0"))
        XCTAssertFalse(source.contains("\n    var bgmTransitionGeneration: Int = 0"))
    }

    func testActiveBGMTimerGenerationIsNotBroadMutableViewModelState() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored private var activeBGMTimerGeneration: Int?"))
        XCTAssertFalse(source.contains("@ObservationIgnored var activeBGMTimerGeneration: Int?"))
    }

    func testLastAudioRoutingTransitionIsPrivateSetOrNarrowlyApplied() throws {
        let source = try viewModelSource()
        let audioRouting = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+AudioRouting.swift")

        XCTAssertTrue(source.contains("private(set) var lastAudioRoutingTransition: AudioRoutingTransition?"))
        XCTAssertFalse(source.contains("\n    var lastAudioRoutingTransition: AudioRoutingTransition?"))
        XCTAssertTrue(audioRouting.contains("applyLastAudioRoutingTransitionFromRuntime(transition)"))
    }

    func testBGMRuntimePlaybackUsesGenerationAccessors() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")

        [
            "setBGMTransitionGenerationForRuntime(generation)",
            "currentBGMTransitionGenerationForRuntime()",
            "setActiveBGMTimerGenerationForRuntime(generation)",
            "activeBGMTimerGenerationForRuntime()"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testNoNewLooseViewModelTestHooksWereAdded() throws {
        let source = try viewModelSource()
        let allowedHooks = [
            "pageInterceptStartOverride",
            "scanOpenKeynoteFilesForTesting",
            "scanKeynoteWindowNamesForTesting",
            "automationCommandRunnerForTesting",
            "automationCommandDidFinishForTesting",
            "saveDataDidRun"
        ]
        let hookLines = source
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("ForTesting") || $0.contains("Override") || $0.contains("DidRun") || $0.contains("DidFinish") }
            .filter { line in
                allowedHooks.contains { line.contains($0) }
            }

        XCTAssertEqual(hookLines.count, allowedHooks.count)
    }

    func testExistingLooseTestHooksAreExplicitlyAllowedOnlyForCompatibility() throws {
        let source = try viewModelSource()

        [
            "pageInterceptStartOverride",
            "scanOpenKeynoteFilesForTesting",
            "scanKeynoteWindowNamesForTesting",
            "automationCommandRunnerForTesting",
            "automationCommandDidFinishForTesting",
            "saveDataDidRun"
        ].forEach { hook in
            XCTAssertTrue(source.contains(hook), hook)
        }
    }

    private func assertPrivateViewModelStorage(_ declaration: String) throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private var \(declaration)"))
        XCTAssertFalse(source.contains("\n    var \(declaration)"))
    }

    private func sourceFiles(containing needle: String) throws -> [String] {
        try viewModelSourceFiles().filter { try repositorySource($0).contains(needle) }
    }

    private func viewModelSourceFiles() throws -> [String] {
        let root = try repositoryRoot()
        let sourceRoot = root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let urls = try FileManager.default.contentsOfDirectory(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.lastPathComponent.hasPrefix("ViewModel") && $0.pathExtension == "swift" }
            .map { "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\($0.lastPathComponent)" }
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func projectionOutputSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift")
    }

    private func pptEventTapSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTEventTap.swift")
    }
}
