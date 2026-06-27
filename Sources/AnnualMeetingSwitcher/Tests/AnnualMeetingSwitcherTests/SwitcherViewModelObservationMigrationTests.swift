import XCTest

final class SwitcherViewModelObservationMigrationTests: XCTestCase {
    func testSwitcherViewModelUsesObservationInsteadOfObservableObjectPublishedFanout() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("import Observation"))
        XCTAssertTrue(source.contains("@Observable"))
        XCTAssertTrue(source.contains("final class SwitcherViewModel {"))
        XCTAssertFalse(source.contains("final class SwitcherViewModel: ObservableObject"))
        XCTAssertFalse(source.contains("@Published"))
    }

    func testAppOwnsSwitcherViewModelWithStableStateObservation() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("@State private var viewModel: SwitcherViewModel"))
        XCTAssertTrue(app.contains(".environment(viewModel)"))
        XCTAssertFalse(app.contains("@StateObject private var viewModel"))
        XCTAssertFalse(app.contains(".environmentObject(viewModel)"))
    }

    func testViewsNoLongerObserveWholeSwitcherViewModelThroughEnvironmentObject() throws {
        let sourceTree = try sourceTreeText()

        XCTAssertFalse(sourceTree.regexMatches(of: "@EnvironmentObject[^\n]*SwitcherViewModel").isEmpty == false)
        XCTAssertFalse(sourceTree.regexMatches(of: "@ObservedObject[^\n]*SwitcherViewModel").isEmpty == false)
        XCTAssertFalse(sourceTree.contains(".environmentObject(SwitcherViewModel())"))
        XCTAssertTrue(sourceTree.contains("@Environment(SwitcherViewModel.self)"))
        XCTAssertTrue(sourceTree.contains(".environment(SwitcherViewModel())"))
    }

    func testButtonActionHelpersCallingSwitcherViewModelStayMainActorIsolated() throws {
        let safetyCockpit = try sourceText("Views/Support/SafetyCockpitView.swift")
        let preflightPopover = try sourceText("Views/Support/PreflightPopoverView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(safetyCockpit.contains("@MainActor\n    private func performAction"))
        XCTAssertTrue(safetyCockpit.contains("@MainActor\n    private func copySupportReport"))
        XCTAssertTrue(safetyCockpit.contains("@MainActor\n    private func saveSupportReport"))
        XCTAssertTrue(preflightPopover.contains("@MainActor\n    private func handlePreflightRowAction"))
        XCTAssertTrue(preflightPopover.contains("@MainActor\n    private func copyPreflightReport"))
        XCTAssertTrue(preflightPopover.contains("@MainActor\n    private func copySupportReport"))
        XCTAssertTrue(preflightPopover.contains("@MainActor\n    private func saveSupportReport"))
        XCTAssertTrue(toolbar.contains("@MainActor\n    private func handlePreflightAction"))
        XCTAssertTrue(content.contains("@MainActor\n    private func togglePanic"))
    }

    func testSwiftFiveTenViewBoundariesStayMainActorIsolated() throws {
        let viewFiles = [
            "ContentView.swift": ["struct ContentView: View"],
            "Views/AppShell/GlobalKeyMonitor.swift": ["struct GlobalKeyMonitor: NSViewRepresentable"],
            "Views/Setup/LeftPanel.swift": ["struct LeftPanel: View"],
            "Views/ProgramMonitor/ProgramMonitorView.swift": ["struct ProgramMonitorView: View"],
            "Views/LiveModeView.swift": ["struct LiveModeView: View"],
            "Views/LiveSourceRail.swift": ["struct LiveSourceRail: View"],
            "Views/LiveAudioStrip.swift": ["struct LiveAudioStrip: View"],
            "Views/LiveQuickRail.swift": ["struct LiveQuickRail: View"],
            "Views/LiveRuntimeStatusBar.swift": ["struct LiveRuntimeStatusBar: View"],
            "Views/LiveOpsPanel.swift": ["struct LiveOpsPanel: View"],
            "Views/MainToolbar.swift": ["struct MainToolbar: View"],
            "Views/Support/PreflightPopoverView.swift": [
                "struct PreflightPopoverView: View"
            ],
            "Views/Support/PreflightCheckRow.swift": [
                "struct PreflightGroupView: View",
                "struct PreflightRowView: View"
            ],
            "Views/Support/SafetyCockpitView.swift": [
                "struct SafetyCockpitView: View"
            ],
            "Views/Support/SafetyCockpitRiskRow.swift": [
                "struct SafetySectionCard: View",
                "struct SafetyCheckRow: View"
            ],
            "Views/SetupAudioDock.swift": ["struct SetupAudioDock: View"],
            "Views/BGMPlaylistPanel.swift": ["struct BGMPlaylistPanel: View"],
            "Views/BGM/BGMTrackList.swift": ["struct BGMTrackList: View"],
            "Views/BGM/BGMTrackRow.swift": ["struct BGMTrackRow: View"],
            "Views/AudioMixerView.swift": ["struct AudioMixerView: View"],
            "Views/OverlayControlPanel.swift": ["struct OverlayControlPanel: View"],
            "Views/Overlays/LowerThirdComposerCard.swift": ["struct LowerThirdComposerCard: View"],
            "Views/Overlays/CountdownComposerCard.swift": ["struct CountdownComposerCard: View"],
            "Views/Overlays/TickerComposerCard.swift": ["struct TickerComposerCard: View"],
            "Views/Overlays/OverlayLivePreviewColumn.swift": ["struct OverlayLivePreviewColumn: View"],
            "Views/Overlays/OverlayActiveStatusCard.swift": ["struct OverlayActiveStatusCard: View"],
            "Views/WallpaperGalleryRow.swift": ["struct WallpaperGalleryRow: View"],
            "Views/CornerLogoCard.swift": ["struct CornerLogoCard: View"],
            "Views/CountdownOverlay.swift": ["struct CountdownOverlay: View"],
            "Views/LowerThirdOverlay.swift": ["struct TickerOverlay: View"],
            "Output/OutputWindowController.swift": ["struct OutputView: View"]
        ]

        for (file, declarations) in viewFiles {
            let source = try sourceText(file)
            for declaration in declarations {
                XCTAssertTrue(
                    source.contains("@MainActor\n\(declaration)"),
                    "\(declaration) in \(file) should remain explicitly main-actor isolated for Swift 5.10 CI"
                )
            }
        }

        let preflightPopover = try sourceText("Views/Support/PreflightPopoverView.swift")
        let preflightRows = try sourceText("Views/Support/PreflightCheckRow.swift")
        let safetyRows = try sourceText("Views/Support/SafetyCockpitRiskRow.swift")
        XCTAssertTrue(preflightPopover.contains("var onPreflightAction: @MainActor"))
        XCTAssertTrue(preflightPopover.contains("var onOpenSafetyCockpit: @MainActor"))
        XCTAssertEqual(preflightRows.components(separatedBy: "let onAction: @MainActor").count - 1, 2)
        XCTAssertEqual(safetyRows.components(separatedBy: "let onAction: @MainActor").count - 1, 2)
    }

    func testProgramMonitorObservesAVPlayerCoordinatorBoundaryDirectly() throws {
        let source = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")
        let content = try sourceText("ContentView.swift")
        let runDesk = try sourceText("Views/AppShell/RunDeskLayout.swift")
        let liveProgramStack = try sourceText("Views/LiveProgramStack.swift")

        XCTAssertTrue(source.contains("@ObservedObject var avCoordinator: AVPlayerCoordinator"))
        XCTAssertTrue(source.contains("init(isLiveMode: Bool = false, avCoordinator: AVPlayerCoordinator)"))
        XCTAssertFalse(source.contains("viewModel.avCoordinator.isPlaying"))
        XCTAssertFalse(source.contains("viewModel.avCoordinator.hasLoadedMedia"))
        XCTAssertTrue(content.contains("avCoordinator: viewModel.avCoordinator"))
        XCTAssertTrue(runDesk.contains("ProgramMonitorView(avCoordinator: avCoordinator)"))
        XCTAssertTrue(liveProgramStack.contains("ProgramMonitorView(isLiveMode: true, avCoordinator: viewModel.avCoordinator)"))
        XCTAssertFalse(source.contains("@State private var viewModel = SwitcherViewModel()"))
        XCTAssertFalse(source.contains("#Preview {\n    let viewModel = SwitcherViewModel()"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceTreeText() throws -> String {
        let sourceRoot = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        var combined = ""
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            combined += try String(contentsOf: url, encoding: .utf8)
            combined += "\n"
        }
        return combined
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(relativePath)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let marker = directory.appendingPathComponent("script/check_release_hygiene.sh")
            let sources = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher")
            if FileManager.default.fileExists(atPath: marker.path),
               FileManager.default.fileExists(atPath: sources.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate LiveSwitcher repository root.")
    }
}

private extension String {
    func regexMatches(of pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { result in
            guard let matchRange = Range(result.range, in: self) else { return nil }
            return String(self[matchRange])
        }
    }
}
