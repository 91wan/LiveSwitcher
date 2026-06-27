import XCTest

final class OutputTypographyBoundaryTests: XCTestCase {
    func testRawFontLiteralsAreLimitedToProjectedOverlayCompositionViews() throws {
        let allowedFiles: Set<String> = [
            "CountdownOverlay.swift",
            "LowerThirdOverlay.swift"
        ]

        for url in try sourceFiles(under: "Views") {
            let source = try String(contentsOf: url, encoding: .utf8)
            guard source.contains(".font(.system(size:") else { continue }

            XCTAssertTrue(
                allowedFiles.contains(url.lastPathComponent),
                "\(url.lastPathComponent) should use StudioTheme.TypeScale unless it is a projected overlay composition surface."
            )
        }
    }

    func testPanicLayerStaysPureBlackWithoutCommentedDebugTypography() throws {
        let source = try String(contentsOf: sourceURL("Views/PanicLayer.swift"), encoding: .utf8)

        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertFalse(source.contains("foregroundColor("))
        XCTAssertTrue(source.contains("Color.black"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"紧急切黑已启用\")"))
    }

    func testActiveProgramOverlayMountsPanicBlackoutWithoutFadeTransition() throws {
        let source = try String(contentsOf: sourceURL("Views/ActiveProgramOverlayLayer.swift"), encoding: .utf8)
        let panicBlock = try XCTUnwrap(source.balancedBlock(after: "if displayState.isPanicMode"))

        XCTAssertTrue(panicBlock.contains("PanicLayer()"))
        XCTAssertFalse(panicBlock.contains(".transition(.opacity)"))
        XCTAssertTrue(panicBlock.contains("transaction.animation = nil"))
    }

    func testOutputViewDoesNotAnimatePanicModeAtParentLayer() throws {
        let source = try String(contentsOf: sourceURL("Output/OutputWindowController.swift"), encoding: .utf8)
        let outputView = try XCTUnwrap(source.balancedBlock(after: "struct OutputView: View"))

        XCTAssertFalse(outputView.contains("value: displayState.isPanicMode"))
        XCTAssertTrue(outputView.contains("value: displayState.isFadeToBlackActive"))
    }

    func testProjectionOutputButtonsUseSingleLineMixedScaleOperatorLabel() throws {
        let liveOps = try String(contentsOf: sourceURL("Views/LiveOpsPanel.swift"), encoding: .utf8)
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let label = try String(contentsOf: sourceURL("Views/ProjectionOutputOperatorLabel.swift"), encoding: .utf8)

        XCTAssertTrue(liveOps.contains("ProjectionOutputOperatorLabel(model: model)"))
        XCTAssertTrue(liveMode.contains("ProjectionOutputOperatorLabel(model: model)"))
        XCTAssertFalse(liveOps.contains("Text(model.operatorLine)"))
        XCTAssertFalse(liveMode.contains("Text(model.operatorLine)"))
        XCTAssertTrue(label.contains("Text(model.title)"))
        XCTAssertTrue(label.contains(".font(StudioTheme.TypeScale.body.weight(.black))"))
        XCTAssertTrue(label.contains("Text(model.screenLabel)"))
        XCTAssertTrue(label.contains(".font(StudioTheme.TypeScale.caption.weight(.semibold))"))
    }

    func testLowerThirdUsesFloatingCountdownCardTreatment() throws {
        let source = try String(contentsOf: sourceURL("Views/LowerThirdOverlay.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains(".transition(.opacity.combined(with: .scale(scale: 0.95)))"))
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: 0)"))
        XCTAssertTrue(source.contains(".fill(Color.black.opacity(0.65))"))
        XCTAssertTrue(source.contains(".stroke(Color.white.opacity(0.15), lineWidth: 1)"))
        XCTAssertTrue(source.contains(".shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)"))
    }

    private func sourceFiles(under relativeDirectory: String) throws -> [URL] {
        let root = try sourceRoot().appendingPathComponent(relativeDirectory)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Could not enumerate \(relativeDirectory).")
        }
        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let candidate = try sourceRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate \(relativePath)")
        }
        return candidate
    }

    private func sourceText(_ relativePath: String) throws -> String {
        if isLiveModeViewSourcePath(relativePath) {
            return try liveModeSourceTextAggregate(repositoryRoot: repositoryRoot())
        }
        return try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let marker = directory.appendingPathComponent("script/check_release_hygiene.sh")
            if FileManager.default.fileExists(atPath: marker.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test path.")
    }
}
