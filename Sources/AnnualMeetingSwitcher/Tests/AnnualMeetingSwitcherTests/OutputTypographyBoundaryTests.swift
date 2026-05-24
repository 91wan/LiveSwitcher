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
