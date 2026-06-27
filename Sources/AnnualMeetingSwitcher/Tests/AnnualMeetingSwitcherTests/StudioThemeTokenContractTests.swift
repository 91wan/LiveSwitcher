import XCTest

final class StudioThemeTokenContractTests: XCTestCase {
    func testStudioThemeUsesNestedSemanticTokenNamespaces() throws {
        let content = try themeContractSurfaceText()

        XCTAssertTrue(content.contains("enum Tone"))
        XCTAssertTrue(content.contains("enum Action"))
        XCTAssertTrue(content.contains("enum Surface"))
        XCTAssertTrue(content.contains("enum Spacing"))
        XCTAssertTrue(content.contains("enum Radius"))
        XCTAssertTrue(content.contains("enum TypeScale"))
        XCTAssertTrue(content.contains("enum Opacity"))
        XCTAssertTrue(content.contains("static let numeric = Font.system(size: 18, weight: .black, design: .rounded)"))
        XCTAssertTrue(content.contains("static func color(for kind: StatusKind)"))
        XCTAssertFalse(content.contains("static func numeric()"))
    }

    func testStudioThemeNoLongerDefinesDecorativeColorTokens() throws {
        let content = try themeContractSurfaceText()

        XCTAssertFalse(content.contains("static let accent"))
        XCTAssertFalse(content.contains("static let accentSecondary"))
        XCTAssertFalse(content.contains("static let green"))
        XCTAssertFalse(content.contains("static let orange"))
        XCTAssertFalse(content.contains("static let pink"))
        XCTAssertFalse(content.contains("static let actionDanger"))
        XCTAssertFalse(content.contains("static let surfacePrimary"))
        XCTAssertFalse(content.contains("static let surfaceSecondary"))
        XCTAssertFalse(content.contains("static let surfaceElevated"))
        XCTAssertFalse(content.contains("static let cardFill"))
    }

    func testViewsDoNotUseRemovedDecorativeTokens() throws {
        for url in try sourceFiles(under: "Views") {
            let content = try String(contentsOf: url, encoding: .utf8)
            let relative = url.lastPathComponent

            XCTAssertFalse(content.contains("StudioTheme.accent"), relative)
            XCTAssertFalse(content.contains("StudioTheme.accentSecondary"), relative)
            XCTAssertFalse(content.contains("StudioTheme.green"), relative)
            XCTAssertFalse(content.contains("StudioTheme.orange"), relative)
            XCTAssertFalse(content.contains("StudioTheme.pink"), relative)
            XCTAssertFalse(content.contains("StudioTheme.actionDanger"), relative)
            XCTAssertFalse(content.contains("StudioTheme.surfacePrimary"), relative)
            XCTAssertFalse(content.contains("StudioTheme.surfaceSecondary"), relative)
            XCTAssertFalse(content.contains("StudioTheme.surfaceElevated"), relative)
            XCTAssertFalse(content.contains("StudioTheme.cardFill"), relative)
        }
    }

    func testViewsUseTypeScaleNumericTokenDirectly() throws {
        for url in try sourceFiles(under: "Views") {
            let content = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(content.contains("StudioTheme.numeric()"), url.lastPathComponent)
        }

        let theme = try themeContractSurfaceText()
        XCTAssertTrue(theme.contains(".font(StudioTheme.TypeScale.numeric)"))
    }

    func testStudioThemeGenericComponentsUseTypeScaleInsteadOfRawFontViewModifiers() throws {
        let componentSurface = try themeComponentSurfaceText()
        let typography = try String(contentsOf: sourceURL("Views/Theme/StudioTheme+Typography.swift"), encoding: .utf8)

        XCTAssertFalse(
            componentSurface.contains(".font(.system(size:"),
            "StudioTheme reusable components should use StudioTheme.TypeScale instead of raw view font literals."
        )
        XCTAssertTrue(typography.contains("Font.system(size: 28"), "TypeScale token declarations should remain explicit.")
    }

    private func themeContractSurfaceText() throws -> String {
        try [
            "Views/Theme/StudioTheme+Colors.swift",
            "Views/Theme/StudioTheme+Typography.swift",
            "Views/Theme/StudioTheme+Layout.swift",
            "Views/Theme/StudioTheme+Status.swift",
            "Views/Theme/StudioTheme+Components.swift"
        ]
        .map { try String(contentsOf: sourceURL($0), encoding: .utf8) }
        .joined(separator: "\n")
    }

    private func themeComponentSurfaceText() throws -> String {
        try [
            "Views/Theme/StudioTheme+Status.swift",
            "Views/Theme/StudioTheme+Components.swift"
        ]
        .map { try String(contentsOf: sourceURL($0), encoding: .utf8) }
        .joined(separator: "\n")
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

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test source path.")
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let candidate = try sourceRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate \(relativePath) from test source path.")
        }
        return candidate
    }
}
