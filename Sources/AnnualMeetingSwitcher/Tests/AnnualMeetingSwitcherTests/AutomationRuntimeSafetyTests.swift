import XCTest
@testable import LiveSwitcher

final class AutomationRuntimeSafetyTests: XCTestCase {
    func testAppleScriptAutomationRunsOnMainActorInsteadOfDetachedThread() throws {
        let source = try sourceText("ViewModel.swift")
        let runAutomationScript = try XCTUnwrap(source.functionBody(named: "runAutomationScript"))
        let openPPTX = try XCTUnwrap(source.functionBody(named: "openPPTXWithKeynote"))

        XCTAssertFalse(runAutomationScript.contains("Task.detached(priority: .userInitiated)"))
        XCTAssertFalse(openPPTX.contains("Task.detached(priority: .userInitiated)"))
        XCTAssertTrue(runAutomationScript.contains("Task { @MainActor"))
        XCTAssertTrue(openPPTX.contains("Task { @MainActor"))
    }

    func testViewModelDeinitDoesNotAssumeMainActorExecutor() throws {
        let source = try sourceText("ViewModel.swift")
        let deinitBody = try XCTUnwrap(
            source.functionBodies(named: "deinit").first { $0.contains("avCoordinator") }
        )

        XCTAssertFalse(deinitBody.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(deinitBody.contains("Task { @MainActor"))
        XCTAssertTrue(deinitBody.contains("avCoordinator.shutdownNonisolated()"))
    }

    @MainActor
    func testAppleScriptFailuresUseSupportEventsWithoutModalAlerts() throws {
        let suiteName = "AutomationRuntimeSafetyTests.nonmodalAutomation.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
        let error = AppleScriptError.executionFailed(
            action: "keynote.next-slide",
            message: "mock failure"
        )

        for _ in 0..<10 {
            viewModel.handleAppleScriptFailure(error, action: "keynote.next-slide")
        }

        let appleScriptFailures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(appleScriptFailures.count, 10)
        XCTAssertTrue(appleScriptFailures.allSatisfy { $0.detail.contains("action=keynote.next-slide") })
    }

    @MainActor
    func testViewModelCanCreateAndReleaseRepeatedlyWithSynchronousCoordinatorShutdown() throws {
        let suiteName = "AutomationRuntimeSafetyTests.lifecycle.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        for _ in 0..<100 {
            autoreleasepool {
                let viewModel = SwitcherViewModel(
                    loadPersistedData: false,
                    enableSystemVolumeObserver: false,
                    userDefaults: userDefaults
                )
                XCTAssertFalse(viewModel.isBroadcasting)
            }
        }
    }

    func testViewModelCleanupResourcesLiveInCleanupBagInsteadOfUnsafeActorState() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertFalse(source.contains("@ObservationIgnored nonisolated(unsafe)"))
        XCTAssertTrue(source.contains("final class ViewModelCleanupBag"))
        XCTAssertTrue(source.contains("@ObservationIgnored let cleanupBag = ViewModelCleanupBag()"))
    }

    func testExternalDisplayObserverDoesNotAddExtraMainActorTaskHop() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "setupExternalDisplayObserver"))

        XCTAssertTrue(body.contains("queue: .main"))
        XCTAssertTrue(body.contains("MainActor.assumeIsolated"))
        XCTAssertFalse(body.contains("Task { @MainActor"))
    }

    func testCleanupBagCancelsTrackedTasksSynchronously() {
        let bag = ViewModelCleanupBag()
        let mediaTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        let bgmTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        let transitionTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }

        bag.mediaVolumeFadeTask = mediaTask
        bag.bgmPlayerVolumeFadeTask = bgmTask
        bag.bgmTransitionTasks[UUID()] = transitionTask

        bag.cancelAll()

        XCTAssertTrue(mediaTask.isCancelled)
        XCTAssertTrue(bgmTask.isCancelled)
        XCTAssertTrue(transitionTask.isCancelled)
    }

    func testOnlyPermissionPromptsUseModalAutomationAlerts() throws {
        let source = try sourceText("ViewModel.swift")
        let runAutomationScriptBody = try XCTUnwrap(source.functionBody(named: "runAutomationScript"))
        let failureBody = try XCTUnwrap(source.functionBody(named: "handleAppleScriptFailure"))
        let startPageInterceptBody = try XCTUnwrap(source.functionBody(named: "startPageIntercept"))

        XCTAssertFalse(source.contains("automationFailureAlertHandler"))
        XCTAssertFalse(runAutomationScriptBody.contains("alertTitle"))
        XCTAssertTrue(source.contains("isPresentingAutomationAlert"))
        XCTAssertTrue(source.contains("presentAutomationAlert("))
        XCTAssertFalse(failureBody.contains("presentAutomationAlert("))
        XCTAssertTrue(startPageInterceptBody.contains("presentAutomationAlert("))
        XCTAssertFalse(startPageInterceptBody.contains("let alert = NSAlert()"))
    }

    func testWPSFallbackUsesNSWorkspaceInsteadOfProcessOpen() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "openWithWPSOffice"))

        XCTAssertFalse(body.contains("Process()"))
        XCTAssertFalse(body.contains("/usr/bin/open"))
        XCTAssertTrue(body.contains("NSWorkspace.shared.urlForApplication"))
        XCTAssertTrue(body.contains("NSWorkspace.shared.open("))
    }

    func testAVPlayerCoordinatorDeinitDoesNotScheduleObserverCleanupTask() throws {
        let source = try sourceText("Engines/AVPlayerCoordinator.swift")
        let deinitBody = try XCTUnwrap(source.functionBody(named: "deinit"))

        XCTAssertFalse(deinitBody.contains("Task { @MainActor"))
        XCTAssertTrue(source.contains("nonisolated func shutdownNonisolated()"))
        XCTAssertTrue(source.contains("Owners must call shutdown() before releasing"))
    }

    func testTickerEngineDoesNotCreateMainActorTaskPerFrameAndGuardsInvalidSizes() throws {
        let source = try sourceText("Views/LowerThirdOverlay.swift")
        let startBody = try XCTUnwrap(source.functionBody(named: "start"))

        XCTAssertFalse(startBody.contains("Task { @MainActor"))
        XCTAssertTrue(startBody.contains("guard textWidth > 0, containerWidth > 0"))
    }

    func testPersistentKeysAreCentralizedInUDKeys() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("static let pushListTitles"))
        XCTAssertTrue(source.contains("static let pushListSubtitles"))
        XCTAssertTrue(source.contains("static let bgmListTitles"))
        XCTAssertTrue(source.contains("static let bgmPlayMode"))
        XCTAssertFalse(source.contains("forKey: \"pushList_titles\""))
        XCTAssertFalse(source.contains("forKey: \"pushList_subtitles\""))
        XCTAssertFalse(source.contains("forKey: \"bgmList_titles\""))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}

private extension String {
    func functionBody(named functionName: String) -> String? {
        let marker = functionName == "deinit" ? "deinit {" : "func \(functionName)"
        guard let markerRange = range(of: marker),
              let openingBrace = self[markerRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }

    func functionBodies(named functionName: String) -> [String] {
        let marker = functionName == "deinit" ? "deinit {" : "func \(functionName)"
        var bodies: [String] = []
        var searchStart = startIndex

        while let markerRange = self[searchStart...].range(of: marker),
              let openingBrace = self[markerRange.lowerBound...].firstIndex(of: "{") {
            var depth = 0
            var index = openingBrace
            while index < endIndex {
                let character = self[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        bodies.append(String(self[openingBrace...index]))
                        searchStart = self.index(after: index)
                        break
                    }
                }
                index = self.index(after: index)
            }
            if index >= endIndex {
                break
            }
        }

        return bodies
    }
}
