import XCTest

final class StudioThemeTokenContractTests: XCTestCase {
    func testStudioThemeUsesNestedSemanticTokenNamespaces() throws {
        let content = try String(contentsOf: sourceURL("Views/StudioTheme.swift"), encoding: .utf8)

        XCTAssertTrue(content.contains("enum Tone"))
        XCTAssertTrue(content.contains("enum Action"))
        XCTAssertTrue(content.contains("enum Surface"))
        XCTAssertTrue(content.contains("enum Spacing"))
        XCTAssertTrue(content.contains("enum Radius"))
        XCTAssertTrue(content.contains("enum TypeScale"))
        XCTAssertTrue(content.contains("enum Opacity"))
        XCTAssertTrue(content.contains("static func color(for kind: StatusKind)"))
    }

    func testStudioThemeNoLongerDefinesDecorativeColorTokens() throws {
        let content = try String(contentsOf: sourceURL("Views/StudioTheme.swift"), encoding: .utf8)

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
