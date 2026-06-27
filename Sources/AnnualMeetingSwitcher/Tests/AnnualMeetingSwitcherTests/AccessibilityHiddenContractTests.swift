import XCTest

final class AccessibilityHiddenContractTests: XCTestCase {
    func testMainConsoleContainerHasStableAccessibilityLabel() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains(".accessibilityElement(children: .contain)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"LiveSwitcher main console\")"))
    }

    func testDecorativeHeaderAndStatusIconsAreHidden() throws {
        assertSymbolHidden("rectangle.3.group.bubble.left.fill", in: try sourceText("Views/OverlayControlPanel.swift"))
        assertDynamicSymbolHidden("viewModel.isBroadcasting ? \"stop.fill\" : \"antenna.radiowaves.left.and.right\"", in: try sourceText("Views/LiveOpsPanel.swift"))
        assertSymbolHidden("photo.on.rectangle.angled", in: try sourceText("Views/WallpaperGalleryRow.swift"))
        assertSymbolHidden("plus", in: try sourceText("Views/WallpaperGalleryRow.swift"))
        assertSymbolHidden("photo", in: try sourceText("Views/WallpaperGalleryRow.swift"))
        assertSymbolHidden("checkmark.circle.fill", in: try sourceText("Views/WallpaperGalleryRow.swift"))
    }

    func testQueueAndBGMRowDecorativeStateIconsAreHidden() throws {
        let runQueue = try sourceText("Views/ProgramQueue/SignalSourceRowHeader.swift")
        let thumbnailView = try sourceText("Views/ThumbnailView.swift")

        XCTAssertTrue(runQueue.contains("ProgramThumbnailView("))
        XCTAssertTrue(thumbnailView.contains(".accessibilityHidden(true)"))
        assertDynamicSymbolHidden("isPlaying ? \"waveform\" : \"checkmark\"", in: try sourceText("Views/BGMPlaylistPanel.swift"))
    }

    func testIconOnlyControlsExposeSemanticLabels() throws {
        let liveOps = try sourceText("Views/LiveOpsPanel.swift")
        let leftPanel = try sourceText("Views/LeftPanel.swift")

        XCTAssertTrue(liveOps.contains(".accessibilityLabel(model.operatorLine)"))
        XCTAssertTrue(liveOps.contains(".accessibilityLabel(\"进入现场模式\")"))
        XCTAssertTrue(leftPanel.contains(".accessibilityLabel(\"刷新 Keynote 信号源\")"))
    }

    private func assertSymbolHidden(_ symbolName: String, in source: String, file: StaticString = #filePath, line: UInt = #line) {
        assertDynamicSymbolHidden("\"\(symbolName)\"", in: source, file: file, line: line)
    }

    private func assertDynamicSymbolHidden(_ symbolExpression: String, in source: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let range = source.range(of: "Image(systemName: \(symbolExpression)") else {
            XCTFail("Missing Image(systemName: \(symbolExpression))", file: file, line: line)
            return
        }

        let tail = source[range.lowerBound..<source.endIndex]
        let snippet = String(tail.prefix(520))
        XCTAssertTrue(snippet.contains(".accessibilityHidden(true)"), "Expected \(symbolExpression) image to be hidden as decoration.", file: file, line: line)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let directCandidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: directCandidate.path) {
                return directCandidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
