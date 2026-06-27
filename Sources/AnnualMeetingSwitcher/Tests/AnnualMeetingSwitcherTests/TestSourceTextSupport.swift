import Foundation
import XCTest

func sourceText(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let root = try repositoryRoot(filePath: filePath)
    return try String(contentsOf: sourceURL(relativePath, repositoryRoot: root), encoding: .utf8)
}

func repositoryRoot(filePath: String = #filePath) throws -> URL {
    var directory = URL(fileURLWithPath: filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
            return directory
        }
    }
    throw XCTSkip("Could not locate repository root from test source path.")
}

func sourceURL(_ relativePath: String, repositoryRoot root: URL) -> URL {
    let directCandidate = root.appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: directCandidate.path) {
        return directCandidate
    }

    let sourceRootCandidate = root
        .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        .appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: sourceRootCandidate.path) {
        return sourceRootCandidate
    }

    let legacySourcePrefix = "Sources/AnnualMeetingSwitcher/"
    if relativePath.hasPrefix(legacySourcePrefix) {
        let suffix = String(relativePath.dropFirst(legacySourcePrefix.count))
        let legacyCandidate = root
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(suffix)
        if FileManager.default.fileExists(atPath: legacyCandidate.path) {
            return legacyCandidate
        }
    }

    return directCandidate
}

func bgmPlaylistSurfaceText(filePath: String = #filePath) throws -> String {
    let files = [
        "Views/BGMPlaylistPanel.swift",
        "Views/BGM/BGMPlaylistHeader.swift",
        "Views/BGM/BGMTransportControls.swift",
        "Views/BGM/BGMProgressRow.swift",
        "Views/BGM/BGMCategoryPicker.swift",
        "Views/BGM/BGMTrackList.swift",
        "Views/BGM/BGMTrackRow.swift",
        "Views/BGM/BGMImportControls.swift",
        "Views/BGM/BGMPanelStatusRow.swift"
    ]

    return try files
        .map { try sourceText($0, filePath: filePath) }
        .joined(separator: "\n")
}
